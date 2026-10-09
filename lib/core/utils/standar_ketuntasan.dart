import '../../data/models/enums.dart';
import '../../data/models/santri_record.dart';
import 'nilai_average.dart';

/// Standar ketuntasan siswa per pekan/bulan (dihitung otomatis, bukan dari tombol Tuntas harian).
///
/// - Tahfizh (termasuk Tahsin+Tahfizh): total baris sepekan >= target baris kelas/halaqoh.
///   Hari Sakit/Izin/Lomba/Pelatihan/Alpa tidak dihitung dan target dikurangi sebanding hari itu.
///   Halaqoh bernama "Tahfizh"/"Tahsin" menentukan jalurnya; halaqoh A/B/C/D mengikuti status laporan.
/// - Tahsin: rata-rata nilai sepekan >= [kkmTahsin].
/// - Pekan tanpa Tahfizh/Tahsin (mis. hanya Muroja'ah) atau tanpa nilai tidak dinilai ('-').
class StandarKetuntasan {
  StandarKetuntasan._();

  /// KKM nilai Tahsin.
  static const double kkmTahsin = 80;

  /// Target baris Tahfizh per pekan. Kelas 7 = 10, kelas 8 = 12, kelas 9 per halaqoh.
  static int? targetBarisPekan(String kelas, String halaqoh) {
    final level = RegExp(r'^\s*(IX|VIII|VII|9|8|7)', caseSensitive: false)
        .firstMatch(kelas)
        ?.group(1)
        ?.toUpperCase();
    switch (level) {
      case 'VII':
      case '7':
        return 10;
      case 'VIII':
      case '8':
        return 12;
      case 'IX':
      case '9':
        return switch (halaqoh.trim().toUpperCase()) {
          'A' => 15,
          'B' => 12,
          'C' => 10,
          'D' => 9,
          _ => null,
        };
      default:
        return null;
    }
  }

  /// Jalur penilaian dari NAMA halaqoh ("Tahfizh", "Tahsin 1", "Tahsin 2"); null untuk halaqoh A/B/C/D
  /// (ikuti status laporan).
  static bool? _tahfizhDariHalaqoh(String halaqoh) {
    final h = halaqoh.toLowerCase();
    if (h.contains('tahsin')) return false;
    if (h.contains('tahfizh')) return true;
    return null;
  }

  /// Hanya "Tidak Setoran/Tahsin/Murojaah" yang ikut dihitung; Sakit, Izin, Lomba, Pelatihan, Alpa tidak.
  static bool _dikecualikan(SantriRecord r) =>
      r.keterangan != Keterangan.hadir && !r.keterangan.isSanksiTanpaSetoran;

  static _Pekan _evalPekan(List<SantriRecord> recs) {
    if (recs.isEmpty) return const _Pekan.kosong();

    // Hari dikecualikan kalau SEMUA laporan hari itu berketerangan Sakit/Izin/Lomba/Pelatihan/Alpa.
    final perHari = <String, List<SantriRecord>>{};
    for (final r in recs) {
      final t = r.tanggal;
      perHari.putIfAbsent('${t.year}-${t.month}-${t.day}', () => []).add(r);
    }
    final hariDinilai = perHari.values.where((d) => !d.every(_dikecualikan)).toList();
    if (hariDinilai.isEmpty) return const _Pekan.kosong();
    final dinilai = [for (final d in hariDinilai) ...d];
    final rasio = hariDinilai.length / perHari.length;

    final first = recs.first;
    var tahfizh = _tahfizhDariHalaqoh(first.halaqoh);
    tahfizh ??= dinilai.any(
      (r) => r.status == HafalanStatus.tahfizh || r.status == HafalanStatus.tahsinTahfizh,
    )
        ? true
        : (dinilai.any((r) => r.status == HafalanStatus.tahsin) ? false : null);
    if (tahfizh == null) return const _Pekan.kosong();

    if (tahfizh) {
      final target = targetBarisPekan(first.kelas, first.halaqoh);
      if (target == null) return const _Pekan.kosong();
      final baris = dinilai.fold<int>(0, (s, r) => s + (r.totalBaris ?? 0));
      return _Pekan(tahfizh: true, baris: baris, target: target * rasio);
    }

    // Tahsin: hari "Tidak Tahsin" dihitung bernilai 0, laporan lain tanpa nilai diabaikan.
    final nilai = <double>[];
    for (final r in dinilai) {
      final v = NilaiAverage.parse(r.nilai);
      if (v != null) {
        nilai.add(v);
      } else if (r.keterangan == Keterangan.tidakTahsin) {
        nilai.add(0);
      }
    }
    final avg = NilaiAverage.mean(nilai);
    return avg == null ? const _Pekan.kosong() : _Pekan(tahfizh: false, nilai: avg);
  }

  static String _label(bool? tuntas) => switch (tuntas) {
        true => 'Tuntas',
        false => 'Tidak Tuntas',
        null => '-',
      };

  /// Status satu siswa untuk satu pekan: 'Tuntas' / 'Tidak Tuntas' / '-'.
  static String pekanText(List<SantriRecord> recs) => _label(_evalPekan(recs).tuntas);

  /// Status satu siswa untuk satu bulan, dari laporan per pekan.
  /// Tahfizh: total baris >= total target semua pekan Tahfizh; Tahsin: rata-rata nilai pekanan >= KKM.
  /// Kalau bulan itu ada keduanya, dua-duanya harus terpenuhi.
  static String bulanText(Map<int, List<SantriRecord>> byWeek) {
    var baris = 0;
    var target = 0.0;
    final nilaiPekan = <double>[];
    for (final recs in byWeek.values) {
      final p = _evalPekan(recs);
      if (p.kosong) continue;
      if (p.tahfizh) {
        baris += p.baris;
        target += p.target;
      } else {
        nilaiPekan.add(p.nilai);
      }
    }
    final checks = <bool>[
      if (target > 0) baris + 1e-9 >= target,
      if (nilaiPekan.isNotEmpty) NilaiAverage.mean(nilaiPekan)! >= kkmTahsin,
    ];
    if (checks.isEmpty) return '-';
    return _label(checks.every((c) => c));
  }
}

class _Pekan {
  final bool kosong;
  final bool tahfizh;
  final int baris;
  final double target;
  final double nilai;

  const _Pekan({required this.tahfizh, this.baris = 0, this.target = 0.0, this.nilai = 0.0}) : kosong = false;
  const _Pekan.kosong()
      : kosong = true,
        tahfizh = false,
        baris = 0,
        target = 0.0,
        nilai = 0.0;

  bool? get tuntas {
    if (kosong) return null;
    return tahfizh ? baris + 1e-9 >= target : nilai >= StandarKetuntasan.kkmTahsin;
  }
}
