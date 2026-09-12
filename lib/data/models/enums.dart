import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Status capaian santri: Tahsin (belajar baca), Tahfizh (hafalan),
/// gabungan Tahsin+Tahfizh, atau Muroja'ah/Tasmi' (mengulang hafalan lama).
enum HafalanStatus {
  tahsin,
  tahfizh,
  tahsinTahfizh,
  murojaahTasmi;

  String get label => switch (this) {
        HafalanStatus.tahsin => 'Tahsin',
        HafalanStatus.tahfizh => 'Tahfizh',
        HafalanStatus.tahsinTahfizh => 'Tahsin+Tahfizh',
        HafalanStatus.murojaahTasmi => "Muroja'ah/Tasmi'",
      };

  IconData get icon => switch (this) {
        HafalanStatus.tahsin => SolarIconsBold.book,
        HafalanStatus.tahfizh => SolarIconsBold.book,
        HafalanStatus.tahsinTahfizh => SolarIconsBold.library,
        HafalanStatus.murojaahTasmi => SolarIconsBold.repeat,
      };

  // <-- BARU: dipakai SantriMonthlyRecap.keteranganSummaryText buat nandain
  // "Nx Tahsin" / "Nx Murojaah" di kolom Keterangan Rekap Bulanan (status
  // yang baris-nya 0 karena memang bukan hafalan baru).
  String get shortLabel => switch (this) {
        HafalanStatus.tahsin => 'Tahsin',
        HafalanStatus.tahfizh => 'Tahfizh',
        HafalanStatus.tahsinTahfizh => 'Tahsin+Tahfizh',
        HafalanStatus.murojaahTasmi => 'Murojaah',
      };

  // <-- BARU: true untuk status yang MEMANG TIDAK menghasilkan baris
  // hafalan baru (Tahsin murni & Muroja'ah/Tasmi'.
  bool get isZeroBarisByDesign =>
      this == HafalanStatus.tahsin || this == HafalanStatus.murojaahTasmi;
}

/// Sub-mode pengisian untuk status Tahsin (dan bagian Tahsin di dalam
/// Tahsin+Tahfizh): WAFA (jenjang buku + halaman, seperti semula) atau
/// Tilawah (surah + rentang ayat, tanpa hitung baris/generate).
enum TahsinMode {
  wafa,
  tilawah;

  String get label => switch (this) {
        TahsinMode.wafa => 'WAFA',
        TahsinMode.tilawah => 'Tilawah',
      };
}

/// Keterangan kehadiran / status setoran hari itu.
enum Keterangan {
  hadir,
  izinSakit,
  izin,
  izinLomba,
  izinPelatihan,
  alpa,
  tidakSetoran,
  tidakTahsin,
  tidakMurojaah;

  String get label => switch (this) {
        Keterangan.hadir => 'Hadir',
        Keterangan.izinSakit => 'Izin Sakit',
        Keterangan.izin => 'Izin',
        Keterangan.izinLomba => 'Izin Lomba',
        Keterangan.izinPelatihan => 'Izin Pelatihan',
        Keterangan.alpa => 'Tanpa Keterangan (Alpa)',
        Keterangan.tidakSetoran => 'Tidak Setoran',
        Keterangan.tidakTahsin => 'Tidak Tahsin',
        Keterangan.tidakMurojaah => 'Tidak Murojaah',
      };

  String get shortLabel => switch (this) {
        Keterangan.hadir => 'Hadir',
        Keterangan.izinSakit => 'Sakit',
        Keterangan.izin => 'Izin',
        Keterangan.izinLomba => 'Lomba',
        Keterangan.izinPelatihan => 'Pelatihan',
        Keterangan.alpa => 'Alpa',
        Keterangan.tidakSetoran => 'Tdk Setoran',
        Keterangan.tidakTahsin => 'Tdk Tahsin',
        Keterangan.tidakMurojaah => 'Tdk Murojaah',
      };

  IconData get icon => switch (this) {
        Keterangan.hadir => SolarIconsBold.checkCircle,
        Keterangan.izinSakit => SolarIconsBold.hospital,
        Keterangan.izin => SolarIconsBold.documentText,
        Keterangan.izinLomba => SolarIconsBold.cupStar,
        Keterangan.izinPelatihan => SolarIconsBold.squareAcademicCap,
        Keterangan.alpa => SolarIconsBold.closeCircle,
        Keterangan.tidakSetoran => Icons.edit_off_rounded,
        Keterangan.tidakTahsin => SolarIconsBold.book,
        Keterangan.tidakMurojaah => SolarIconsBold.restart,
      };

  /// Tiga keterangan "sanksi" (santri HADIR tapi nggak setor/tahsin/
  /// murojaah — males/ketiduran/dll, bukan izin/sakit/alpa).
  bool get isSanksiTanpaSetoran =>
      this == Keterangan.tidakSetoran ||
      this == Keterangan.tidakTahsin ||
      this == Keterangan.tidakMurojaah;

  static Keterangan fromLabel(String label) =>
      Keterangan.values.firstWhere((e) => e.label == label, orElse: () => Keterangan.hadir);
}

/// Jenjang WAFA untuk santri tahsin.
enum WafaLevel {
  wafa1,
  wafa2,
  wafa3,
  wafa4,
  wafa5;

  String get label => switch (this) {
        WafaLevel.wafa1 => 'WAFA 1',
        WafaLevel.wafa2 => 'WAFA 2',
        WafaLevel.wafa3 => 'WAFA 3',
        WafaLevel.wafa4 => 'WAFA 4',
        WafaLevel.wafa5 => 'WAFA 5',
      };
}

enum ExportFormat { pdf, word, excel }
