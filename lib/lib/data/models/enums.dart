import 'package:flutter/material.dart';

/// Status capaian santri: Tahsin (belajar baca) atau Tahfizh (hafalan).
enum HafalanStatus {
  tahsin,
  tahfizh;

  String get label => switch (this) {
        HafalanStatus.tahsin => 'Tahsin',
        HafalanStatus.tahfizh => 'Tahfizh',
      };

  IconData get icon => switch (this) {
        HafalanStatus.tahsin => Icons.menu_book_rounded,
        HafalanStatus.tahfizh => Icons.auto_stories_rounded,
      };
}

/// Keterangan kehadiran / status setoran hari itu.
enum Keterangan {
  hadir,
  izinSakit,
  izinLomba,
  izinPelatihan,
  alpa;

  String get label => switch (this) {
        Keterangan.hadir => 'Hadir',
        Keterangan.izinSakit => 'Izin Sakit',
        Keterangan.izinLomba => 'Izin Lomba',
        Keterangan.izinPelatihan => 'Izin Pelatihan',
        Keterangan.alpa => 'Tanpa Keterangan (Alpa)',
      };

  String get shortLabel => switch (this) {
        Keterangan.hadir => 'Hadir',
        Keterangan.izinSakit => 'Sakit',
        Keterangan.izinLomba => 'Lomba',
        Keterangan.izinPelatihan => 'Pelatihan',
        Keterangan.alpa => 'Alpa',
      };

  IconData get icon => switch (this) {
        Keterangan.hadir => Icons.check_circle_rounded,
        Keterangan.izinSakit => Icons.local_hospital_rounded,
        Keterangan.izinLomba => Icons.emoji_events_rounded,
        Keterangan.izinPelatihan => Icons.school_rounded,
        Keterangan.alpa => Icons.cancel_rounded,
      };

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
