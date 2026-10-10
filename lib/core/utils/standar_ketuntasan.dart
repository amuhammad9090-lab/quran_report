import '../../data/models/enums.dart';
import '../../data/models/santri_record.dart';
import '../../data/services/ketuntasan_settings_service.dart';
import 'nilai_average.dart';

/// Standar ketuntasan siswa per pekan/bulan (dihitung otomatis, bukan dari tombol Tuntas harian).
/// Jalur dipilih dari status laporan siswa di pekan itu, urutannya:
/// - Tahfizh (termasuk Tahsin+Tahfizh): total baris sepekan >= target baris kelas/halaqoh.
/// - Tahsin: rata-rata nilai sepekan >= [kkmTahsin].
/// - Muroja'ah/Tasmi' (pekan tanpa Tahfizh/Tahsin): Tuntas, kecuali "Tidak Murojaah" 2x atau lebih.
/// Di semua jalur, "Tidak Murojaah" 2x atau lebih sepekan = Tidak Tuntas.
/// Hari Sakit/Izin/Lomba/Pelatihan/Alpa tidak dihitung; di jalur Tahfizh, target dikurangi sebanding
/// hari itu dan hari Muroja'ah (baris memang 0).
class StandarKetuntasan {
  StandarKetuntasan._();

  /// Batas "Tidak Murojaah" dalam sepekan; sebanyak ini atau lebih = Tidak Tuntas.
  static const int batasTidakMurojaah = 2;

  /// Target baris Tahfizh per pekan, dari standar yang diisi admin (lihat [KetuntasanConfig]).
  /// Kelas 7: hanya halaqoh Tahfizh. Kelas 8: satu target untuk semua halaqoh. Kelas 9: per halaqoh A-D.
  static int? targetBarisPekan(String kelas, String halaqoh) {
    final level = RegExp(r'^\s*(IX|VIII|VII|9|8|7)', caseSensitive: false)
        .firstMatch(kelas)
        ?.group(1)
        ?.toUpperCase();
    final h = halaqoh.trim().toUpperCase();
    final cfg = KetuntasanSettingsService.instance.config;
    switch (level) {
      case 'VII':
      case '7':
        // Kelas 7: hanya halaqoh Tahfizh yang punya target baris.
        return h.contains('TAHFIZH') ? cfg.barisFor('k7') : null;
      case 'VIII':
      case '8':
        // Kelas 8: satu target untuk semua halaqoh Tahfizh (Tahfizh 1/2/3), juga halaqoh lama A/B/C.
        return cfg.barisFor('k8_Tahfizh');
      case 'IX':
      case '9':
        return const {'A', 'B', 'C', 'D'}.contains(h) ? cfg.barisFor('k9_$h') : null;
      default:
        return null;
    }
  }

  /// KKM nilai Tahsin (satu angka untuk semua halaqoh Tahsin).
  static double kkmTahsin(String halaqoh) =>
      KetuntasanSettingsService.instance.config.kkmTahsin;

  /// Hanya "Tidak Setoran/Tahsin/Murojaah" yang ikut dihitung; Sakit, Izin, Lomba, Pelatihan, Alpa tidak.
  static bool _dikecualikan(SantriRecord r) =>
      r.keterangan != Keterangan.hadir && !r.keterangan.isSanksiTanpaSetoran;

  static bool _hariMurojaah(SantriRecord r) =>
      r.status == HafalanStatus.murojaahTasmi || r.keterangan == Keterangan.tidakMurojaah;

  static _Pekan _evalPekan(List<SantriRecord> recs) {
    if (recs.isEmpty) return const _Pekan.kosong();

    final perHari = <String, List<SantriRecord>>{};
    for (final r in recs) {
      final t = r.tanggal;
      perHari.putIfAbsent('${t.year}-${t.month}-${t.day}', () => []).add(r);
    }
    // Hari dikecualikan kalau SEMUA laporan hari itu Sakit/Izin/Lomba/Pelatihan/Alpa.
    final hariDinilai = perHari.values.where((d) => !d.every(_dikecualikan)).toList();
    if (hariDinilai.isEmpty) return const _Pekan.kosong();
    final dinilai = [for (final d in hariDinilai) ...d];

    final gagalMurojaah =
        dinilai.where((r) => r.keterangan == Keterangan.tidakMurojaah).length >= batasTidakMurojaah;

    final tahfizhRecs = dinilai.where(
      (r) =>
          !_hariMurojaah(r) &&
          (r.status == HafalanStatus.tahfizh || r.status == HafalanStatus.tahsinTahfizh),
    );
    final tahsinRecs = dinilai.where((r) => !_hariMurojaah(r) && r.status == HafalanStatus.tahsin);

    if (tahfizhRecs.isNotEmpty) {
      final first = tahfizhRecs.first;
      final target = targetBarisPekan(first.kelas, first.halaqoh);
      if (target == null) return const _Pekan.kosong();
      // Hari Muroja'ah tidak ikut dihitung (barisnya memang 0).
      final hariTahfizh = hariDinilai.where((d) => !d.every(_hariMurojaah)).length;
      final rasio = hariTahfizh / perHari.length;
      final baris = dinilai.fold<int>(0, (s, r) => s + (r.totalBaris ?? 0));
      return _Pekan(jenis: _Jenis.tahfizh, baris: baris, target: target * rasio, gagalMurojaah: gagalMurojaah);
    }

    if (tahsinRecs.isNotEmpty) {
      // Hari "Tidak Tahsin" dihitung bernilai 0, laporan lain tanpa nilai diabaikan.
      final nilai = <double>[];
      for (final r in tahsinRecs) {
        final v = NilaiAverage.parse(r.nilai);
        if (v != null) {
          nilai.add(v);
        } else if (r.keterangan == Keterangan.tidakTahsin) {
          nilai.add(0);
        }
      }
      final avg = NilaiAverage.mean(nilai);
      if (avg != null) {
        return _Pekan(
          jenis: _Jenis.tahsin,
          nilai: avg,
          kkm: kkmTahsin(tahsinRecs.first.halaqoh),
          gagalMurojaah: gagalMurojaah,
        );
      }
      return gagalMurojaah ? const _Pekan(jenis: _Jenis.murojaah, gagalMurojaah: true) : const _Pekan.kosong();
    }

    if (dinilai.any(_hariMurojaah)) {
      return _Pekan(jenis: _Jenis.murojaah, gagalMurojaah: gagalMurojaah);
    }
    return const _Pekan.kosong();
  }

  static String _label(bool? tuntas) => switch (tuntas) {
        true => 'Tuntas',
        false => 'Tidak Tuntas',
        null => '-',
      };

  /// Status satu siswa untuk satu pekan: 'Tuntas' / 'Tidak Tuntas' / '-'.
  static String pekanText(List<SantriRecord> recs) => _label(_evalPekan(recs).tuntas);

  /// Status satu siswa untuk satu bulan, dari laporan per pekan.
  /// Tahfizh: total baris >= total target semua pekan Tahfizh; Tahsin: rata-rata nilai pekanan >= KKM;
  /// Muroja'ah: tidak ada pekan yang gagal. Kalau bulan itu ada beberapa jalur, semuanya harus terpenuhi.
  static String bulanText(Map<int, List<SantriRecord>> byWeek) {
    var baris = 0;
    var target = 0.0;
    final nilaiPekan = <double>[];
    var kkm = 80.0;
    var ada = false;
    var gagalMurojaah = false;
    for (final recs in byWeek.values) {
      final p = _evalPekan(recs);
      if (p.kosong) continue;
      ada = true;
      if (p.gagalMurojaah) gagalMurojaah = true;
      switch (p.jenis) {
        case _Jenis.tahfizh:
          baris += p.baris;
          target += p.target;
        case _Jenis.tahsin:
          nilaiPekan.add(p.nilai);
          kkm = p.kkm;
        case _Jenis.murojaah:
          break;
      }
    }
    if (!ada) return '-';
    final checks = <bool>[
      !gagalMurojaah,
      if (target > 0) baris + 1e-9 >= target,
      if (nilaiPekan.isNotEmpty) NilaiAverage.mean(nilaiPekan)! >= kkm,
    ];
    return _label(checks.every((c) => c));
  }
}

enum _Jenis { tahfizh, tahsin, murojaah }

class _Pekan {
  final bool kosong;
  final _Jenis jenis;
  final int baris;
  final double target;
  final double nilai;
  final double kkm;
  final bool gagalMurojaah;

  const _Pekan({
    required this.jenis,
    this.baris = 0,
    this.target = 0.0,
    this.nilai = 0.0,
    this.kkm = 80.0,
    this.gagalMurojaah = false,
  }) : kosong = false;
  const _Pekan.kosong()
      : kosong = true,
        jenis = _Jenis.murojaah,
        baris = 0,
        target = 0.0,
        nilai = 0.0,
        kkm = 80.0,
        gagalMurojaah = false;

  bool? get tuntas {
    if (kosong) return null;
    if (gagalMurojaah) return false;
    return switch (jenis) {
      _Jenis.tahfizh => baris + 1e-9 >= target,
      _Jenis.tahsin => nilai >= kkm,
      _Jenis.murojaah => true,
    };
  }
}
