import 'package:flutter/material.dart';

/// Palet warna — nuansa hijau tosca (identik kegiatan tahfizh) dipadu
/// amber untuk aksen tahsin, dirancang agar terasa "islami" namun modern.
class AppColors {
  AppColors._();

  // Brand
  static const seed = Color(0xFF0E7C61); // deep teal-green
  static const seedDark = Color(0xFF14A085);

  // Status Tahfizh / Tahsin
  static const tahfizh = Color(0xFF0E7C61);
  static const tahsin = Color(0xFFB8860B);

  // Keterangan
  static const hadir = Color(0xFF2E9E5B);
  static const izinSakit = Color(0xFFE0724A);
  static const izinLomba = Color(0xFF6C5CE7);
  static const izinPelatihan = Color(0xFF2F80B4);
  static const alpa = Color(0xFFD64545);

  static Color keteranganColor(String key) => switch (key) {
        'hadir' => hadir,
        'izinSakit' => izinSakit,
        'izinLomba' => izinLomba,
        'izinPelatihan' => izinPelatihan,
        'alpa' => alpa,
        _ => hadir,
      };
}
