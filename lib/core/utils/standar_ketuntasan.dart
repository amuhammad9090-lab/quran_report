import '../../data/models/enums.dart';
import '../../data/models/santri_record.dart';
import '../../data/services/ketuntasan_settings_service.dart';
import 'nilai_average.dart';

/// Status ketuntasan siswa per pekan/bulan, dihitung otomatis (bukan tombol Tuntas harian).
/// Acuan utama = standar yang diisi admin (lihat [KetuntasanConfig]):
/// - Tahfizh: total baris sepekan >= target baris kelas/halaqoh.
/// - Tahsin (termasuk Tahsin+Tahfizh): rata-rata nilai sepekan >= [kkmTahsin].
/// Aturan keterangan:
/// - Alpa/Tidak Setoran/Tidak Tahsin (melanggar): hari tetap dihitung (baris 0 / nilai Tidak Tahsin 0),
///   pekan Tidak Tuntas kecuali standar tetap tercapai.
/// - Sakit/Izin/Lomba/Pelatihan: hari tidak dihitung (target dikurangi sebanding), dan kalau standar
///   tidak tercapai pekan tetap Tuntas, kecuali ada pelanggaran di atas.
/// - Muroja'ah/Tasmi' dan Tidak Murojaah tidak punya aturan ketuntasan: "-" (guru menulis catatannya sendiri).
/// - Hadir tanpa isi sama sekali (termasuk toggle "tanpa capaian hari ini") tidak dinilai.
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

  /// Alpa, Tidak Setoran, Tidak Tahsin: harinya tetap dihitung, tapi menolak override Sakit/Izin.
  static bool _gagal(SantriRecord r) => switch (r.keterangan) {
        Keterangan.alpa || Keterangan.tidakSetoran || Keterangan.tidakTahsin => true,
        _ => false,
      };

  /// Sakit/Izin/Lomba/Pelatihan: hari tidak dihitung dan menjamin Tuntas (selama tidak ada [_gagal]).
  static bool _dikecualikan(SantriRecord r) => switch (r.keterangan) {
        Keterangan.izinSakit || Keterangan.izin || Keterangan.izinLomba || Keterangan.izinPelatihan => true,
        _ => false,
      };

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
    final adaGagal = recs.any(_gagal);
    final adaIzin = recs.any(_dikecualikan);
    // Standar tidak tercapai tapi ada Sakit/Izin/Lomba/Pelatihan tanpa Alpa/Tidak Setoran/Tidak Tahsin: Tuntas.
    final override = adaIzin && !adaGagal;
    // Tidak ada yang bisa dinilai dengan standar (belum ada baris/nilai):
    // - pekan murojaah (dikerjakan atau Tidak Murojaah): "-", tuntas atau tidaknya ditulis guru di catatan;
    // - ada hari izin tanpa Alpa/Tidak Setoran/Tidak Tahsin: Tuntas;
    // - selain itu "-" sampai laporannya diedit dan ada isinya.
    final _Pekan tanpaNilai = recs.any(_hariMurojaah)
        ? const _Pekan.kosong()
        : adaIzin && !adaGagal
            ? const _Pekan.lulus()
            : const _Pekan.kosong();

    final perHari = <String, List<SantriRecord>>{};
    for (final r in recs) {
      final t = r.tanggal;
      perHari.putIfAbsent('${t.year}-${t.month}-${t.day}', () => []).add(r);
    }
    // Hari dikecualikan kalau SEMUA laporan hari itu Sakit/Izin/Lomba/Pelatihan.
    // Hari yang semua laporannya tanpa isi (lihat [_tanpaIsi]) juga tidak dinilai.
    final hariDinilai =
        perHari.values.where((d) => !d.every((r) => _dikecualikan(r) || _tanpaIsi(r))).toList();
    if (hariDinilai.isEmpty) return tanpaNilai;
    final dinilai = [
      for (final d in hariDinilai) ...d.where((r) => !_tanpaIsi(r)),
    ];

    // Jalur (Tahfizh/Tahsin) ditentukan dari laporan Hadir yang ada isinya, karena laporan non-Hadir
    // (Alpa, Tidak Setoran, dst) disimpan dengan status bawaan Tahfizh walau siswanya Tahsin.
    final jalur = dinilai.where((r) => !_hariMurojaah(r)).toList();
    final bukti = jalur.where((r) => r.keterangan == Keterangan.hadir).toList();
    final penentu = bukti.isNotEmpty ? bukti : jalur;
    final tahfizhRecs = penentu.where((r) => r.status == HafalanStatus.tahfizh);
    // Tahsin+Tahfizh dinilai dengan standar Tahsin (nilai vs KKM), bukan baris.
    final tahsinRecs = penentu.where(
      (r) => r.status == HafalanStatus.tahsin || r.status == HafalanStatus.tahsinTahfizh,
    );

    if (tahfizhRecs.isNotEmpty) {
      final first = tahfizhRecs.first;
      final target = targetBarisPekan(first.kelas, first.halaqoh);
      if (target == null) return tanpaNilai;
      // Hari Muroja'ah tidak ikut dihitung (barisnya memang 0).
      // Hari "tanpa isi/capaian" tetap dihitung sebagai hari target (tidak mengurangi target);
      // hanya hari izin dan hari murojaah yang dikeluarkan.
      final hariTahfizh = perHari.values
          .where((d) => !d.every(_dikecualikan) && !d.every(_hariMurojaah))
          .length;
      final rasio = hariTahfizh / perHari.length;
      final baris = dinilai.fold<int>(0, (s, r) => s + (r.totalBaris ?? 0));
      final t = target * rasio;
      // Override Sakit/Izin: pekan dianggap memenuhi target.
      return _Pekan(jenis: _Jenis.tahfizh, baris: baris, target: t, override: override);
    }

    if (tahsinRecs.isNotEmpty) {
      // Hari "Tidak Tahsin" dihitung bernilai 0, laporan lain tanpa nilai diabaikan.
      final nilai = <double>[];
      final untukNilai = jalur.where(
        (r) =>
            r.status == HafalanStatus.tahsin ||
            r.status == HafalanStatus.tahsinTahfizh ||
            r.keterangan == Keterangan.tidakTahsin,
      );
      for (final r in untukNilai) {
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
          override: override,
        );
      }
    }

    // Muroja'ah/Tasmi' tidak punya aturan ketuntasan.
    return tanpaNilai;
  }

  static String _label(bool? tuntas) => switch (tuntas) {
        true => 'Tuntas',
        false => 'Tidak Tuntas',
        null => '-',
      };

  /// Kolom Status harian: standar baris/nilai berlaku per PEKAN, jadi per laporan hanya keterangan yang
  /// terbaca: Sakit/Izin/Lomba/Pelatihan = Tuntas, Alpa/Tidak Setoran/Tidak Tahsin = Tidak Tuntas,
  /// selain itu '-' (ditentukan di rekap pekanan).
  static String harianText(SantriRecord r) => _dikecualikan(r)
      ? _label(true)
      : _gagal(r)
          ? _label(false)
          : _label(null);

  /// Status satu siswa untuk satu pekan: 'Tuntas' / 'Tidak Tuntas' / '-'.
  static String pekanText(List<SantriRecord> recs) => _label(_evalPekan(recs).tuntas);

  /// Keputusan guru untuk satu pekan (lihat [SantriRecord.tuntasPekan]): 'Tuntas' / 'Tidak Tuntas' / '-'.
  static String manualPekan(List<SantriRecord> recs) => _label(manualPekanValue(recs));

  /// Nilai keputusan guru pekan ini; diambil dari laporan terbaru yang sudah diberi keputusan.
  static bool? manualPekanValue(List<SantriRecord> recs) {
    final sorted = recs.where((r) => r.tuntasPekan != null).toList()
      ..sort((a, b) => a.tanggal.compareTo(b.tanggal));
    return sorted.isEmpty ? null : sorted.last.tuntasPekan;
  }

  /// Batas toleransi: sampai sekian pekan Tidak Tuntas dalam sebulan masih dimaafkan.
  static const int toleransiTidakTuntasBulan = 1;

  /// Pekan yang SELURUH laporannya Izin/Sakit/Lomba/Pelatihan: tidak ikut dinilai.
  static bool _pekanDikecualikan(List<SantriRecord> recs) =>
      recs.isNotEmpty && recs.every(_dikecualikan);

  /// Status bulan dari keputusan guru: pekan dihitung Tidak Tuntas kalau guru menekan Tidak Tuntas
  /// (apa pun alasannya: nilai/target kurang, Alpa, Tidak Setoran, dst), KECUALI pekan yang seluruhnya
  /// Izin/Sakit/Lomba/Pelatihan. Pekan yang belum diputuskan tidak dihitung. Bulan Tidak Tuntas kalau
  /// jumlah pekan Tidak Tuntas MELEBIHI [toleransiTidakTuntasBulan] (1x dimaafkan, 2x Tidak Tuntas);
  /// selain itu Tuntas. '-' hanya kalau tidak ada laporan sama sekali di bulan itu.
  static String manualBulan(Map<int, List<SantriRecord>> byWeek) {
    if (byWeek.values.every((recs) => recs.isEmpty)) return '-';
    final tidakTuntas = byWeek.values
        .where((recs) => manualPekanValue(recs) == false && !_pekanDikecualikan(recs))
        .length;
    return _label(tidakTuntas <= toleransiTidakTuntasBulan);
  }
}

enum _Jenis { tahfizh, tahsin, lulus }

class _Pekan {
  final bool kosong;
  final _Jenis jenis;
  final int baris;
  final double target;
  final double nilai;
  final double kkm;

  /// True kalau pekan ini Tuntas lewat Sakit/Izin/Lomba/Pelatihan walau standar belum tercapai.
  final bool override;

  const _Pekan({
    required this.jenis,
    this.baris = 0,
    this.target = 0.0,
    this.nilai = 0.0,
    this.kkm = 80.0,
    this.override = false,
  }) : kosong = false;
  const _Pekan.lulus()
      : kosong = false,
        jenis = _Jenis.lulus,
        baris = 0,
        target = 0.0,
        nilai = 0.0,
        kkm = 80.0,
        override = false;
  const _Pekan.kosong()
      : kosong = true,
        jenis = _Jenis.lulus,
        baris = 0,
        target = 0.0,
        nilai = 0.0,
        kkm = 80.0,
        override = false;

  bool? get tuntas {
    if (kosong) return null;
    if (override) return true;
    return switch (jenis) {
      _Jenis.lulus => true,
      _Jenis.tahfizh => baris + 1e-9 >= target,
      _Jenis.tahsin => nilai >= kkm,
    };
  }
}
