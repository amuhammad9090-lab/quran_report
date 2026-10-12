import '../../data/models/enums.dart';
import '../../data/models/santri_record.dart';
import '../../data/services/ketuntasan_settings_service.dart';
import 'nilai_average.dart';

/// Standar ketuntasan siswa per pekan/bulan (dihitung otomatis, bukan dari tombol Tuntas harian).
/// Jalur dipilih dari status laporan siswa di pekan itu, urutannya:
/// - Tahfizh: total baris sepekan >= target baris kelas/halaqoh.
/// - Tahsin (termasuk Tahsin+Tahfizh): rata-rata nilai sepekan >= [kkmTahsin].
/// - Muroja'ah/Tasmi' TIDAK masuk standar (guru menulisnya di catatan): pekan tanpa Tahfizh/Tahsin = "-".
/// Hari Sakit/Izin/Lomba/Pelatihan/Alpa tidak dihitung; di jalur Tahfizh, target dikurangi sebanding
/// hari itu dan hari Muroja'ah (baris memang 0).
class StandarKetuntasan {
  StandarKetuntasan._();

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

  /// Laporan "hadir" tapi tanpa isi sama sekali (0 baris, tanpa nilai/halaman/ayat) dan tanpa
  /// keterangan Tidak Setoran/Tahsin/Murojaah: guru tidak mengisi atau lupa, jadi tidak diketahui
  /// (bukan Tuntas, bukan Tidak Tuntas) dan tidak ikut dinilai.
  static bool _tanpaIsi(SantriRecord r) {
    if (r.keterangan != Keterangan.hadir) return false;
    final adaBaris = (r.totalBaris ?? 0) > 0;
    final adaNilai = NilaiAverage.parse(r.nilai) != null;
    final adaHalaman = (r.halamanWafa ?? '').trim().isNotEmpty;
    return !adaBaris && !adaNilai && !adaHalaman && r.jumlahAyat == 0;
  }

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
    // Hari yang semua laporannya tanpa isi (lihat [_tanpaIsi]) juga tidak dinilai.
    final hariDinilai =
        perHari.values.where((d) => !d.every((r) => _dikecualikan(r) || _tanpaIsi(r))).toList();
    if (hariDinilai.isEmpty) return const _Pekan.kosong();
    final dinilai = [
      for (final d in hariDinilai) ...d.where((r) => !_tanpaIsi(r)),
    ];

    final tahfizhRecs = dinilai.where(
      (r) =>
          !_hariMurojaah(r) &&
          r.status == HafalanStatus.tahfizh,
    );
    // Tahsin+Tahfizh dinilai dengan standar Tahsin (nilai vs KKM), bukan baris.
    final tahsinRecs = dinilai.where(
      (r) => !_hariMurojaah(r) && (r.status == HafalanStatus.tahsin || r.status == HafalanStatus.tahsinTahfizh),
    );

    if (tahfizhRecs.isNotEmpty) {
      final first = tahfizhRecs.first;
      final target = targetBarisPekan(first.kelas, first.halaqoh);
      if (target == null) return const _Pekan.kosong();
      // Hari Muroja'ah tidak ikut dihitung (barisnya memang 0).
      final hariTahfizh = hariDinilai.where((d) => !d.every(_hariMurojaah)).length;
      final rasio = hariTahfizh / perHari.length;
      final baris = dinilai.fold<int>(0, (s, r) => s + (r.totalBaris ?? 0));
      return _Pekan(jenis: _Jenis.tahfizh, baris: baris, target: target * rasio);
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
        );
      }
    }

    // Muroja'ah/Tasmi' tidak masuk standar ketuntasan (guru menulisnya di catatan): pekan tanpa
    // Tahfizh/Tahsin yang bisa dinilai = "-".
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
    for (final recs in byWeek.values) {
      final p = _evalPekan(recs);
      if (p.kosong) continue;
      ada = true;
      switch (p.jenis) {
        case _Jenis.tahfizh:
          baris += p.baris;
          target += p.target;
        case _Jenis.tahsin:
          nilaiPekan.add(p.nilai);
          kkm = p.kkm;
      }
    }
    if (!ada) return '-';
    final checks = <bool>[
      if (target > 0) baris + 1e-9 >= target,
      if (nilaiPekan.isNotEmpty) NilaiAverage.mean(nilaiPekan)! >= kkm,
    ];
    return _label(checks.every((c) => c));
  }
}

enum _Jenis { tahfizh, tahsin }

class _Pekan {
  final bool kosong;
  final _Jenis jenis;
  final int baris;
  final double target;
  final double nilai;
  final double kkm;

  const _Pekan({
    required this.jenis,
    this.baris = 0,
    this.target = 0.0,
    this.nilai = 0.0,
    this.kkm = 80.0,
  }) : kosong = false;
  const _Pekan.kosong()
      : kosong = true,
        jenis = _Jenis.tahfizh,
        baris = 0,
        target = 0.0,
        nilai = 0.0,
        kkm = 80.0;

  bool? get tuntas {
    if (kosong) return null;
    return switch (jenis) {
      _Jenis.tahfizh => baris + 1e-9 >= target,
      _Jenis.tahsin => nilai >= kkm,
    };
  }
}
