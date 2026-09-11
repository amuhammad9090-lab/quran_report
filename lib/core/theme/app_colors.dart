import 'package:flutter/material.dart';

import '../../data/models/enums.dart';

/// Palet warna — nuansa hijau tosca (identik kegiatan tahfizh) dipadu
/// amber untuk aksen tahsin, dirancang agar terasa "islami" namun modern.
///
/// Setiap warna aksen (tahfizh/tahsin/keterangan) punya 2 versi: versi
/// "light" (dipakai juga oleh PDF/Excel export — kertas selalu putih,
/// gak peduli tema HP) dan versi "*Dark" yang dicerahkan biar tetap
/// terbaca di atas card gelap. Sebelum ini semua warna dipakai apa
/// adanya di kedua tema — akibatnya beberapa (tahfizh, izin lomba, izin
/// pelatihan, alpa) kontrasnya jatuh di bawah standar keterbacaan WCAG AA
/// (4.5:1) saat dark mode, karena warnanya didesain buat kontras di atas
/// background PUTIH, bukan di atas card gelap. Versi `*Dark` di bawah
/// sudah dicek manual terhadap warna card dark mode (lihat
/// `AppTheme.surfaceElevated`, ~#222B33 per pembaruan terakhir): semua
/// tetap ≥ 6.5:1 kontras walau warna card sempat dinaikin (sebelumnya
/// ~#181F26, lebih gelap) biar dark mode-nya gak kelewat pekat.
class AppColors {
  AppColors._();

  // Brand
  static const seed = Color(0xFF0E7C61);
  static const seedDark = Color(0xFF14A085);
  static const splashGradientStart = Color(0xFF52AD65);
  static const splashGradientEnd = Color(0xFF0B4A38);

  // --- Status Tahfizh / Tahsin (versi light — juga dipakai export PDF/Excel).
  static const tahfizh = Color(0xFF0E7C61);
  static const tahsin = Color(0xFFD97706);

  // --- Versi dark mode ---
  static const tahfizhDark = Color(0xFF3ED9AE);
  static const tahsinDark = Color(0xFFFBBF24);

  // --- Aksi "Deploy" (kirim rekap ke Portal Ortu).
  static const deploy = Color(0xFF0E8F6E);
  static const deployDark = Color(0xFF3EDCB0);

  /// Warna tombol/chip "Deploy" — otomatis pilih versi terang/gelap
  /// sesuai tema aktif (lihat catatan di [deploy]/[deployDark]).
  static Color deployOn(BuildContext context) => _isDark(context) ? deployDark : deploy;

  // --- Status Tahsin+Tahfizh / Muroja'ah-Tasmi' (versi light) ---
  static const tahsinTahfizh = Color(0xFF2F80B4);
  static const murojaahTasmi = Color(0xFF6C5CE7);

  // --- Versi dark ---
  static const tahsinTahfizhDark = Color(0xFF6FB6EA);
  static const murojaahTasmiDark = Color(0xFFA79BFF);

  // --- Keterangan (versi light) ---
  static const hadir = Color(0xFF2E9E5B);
  static const izinSakit = Color(0xFFE0724A);
  static const izin = Color(0xFF4A90A4);
  static const izinLomba = Color(0xFF6C5CE7);
  static const izinPelatihan = Color(0xFF2F80B4);
  static const alpa = Color(0xFFD64545);
  static const tidakSetoran = Color(0xFF8B5E3C);
  static const tidakTahsin = Color(0xFFA6763D);
  static const tidakMurojaah = Color(0xFF6B5490);

  // --- Keterangan (versi dark) ---
  static const hadirDark = Color(0xFF4FCE85);
  static const izinSakitDark = Color(0xFFFF9269);
  static const izinDark = Color(0xFF7FC3D6);
  static const izinLombaDark = Color(0xFFA79BFF);
  static const izinPelatihanDark = Color(0xFF6FB6EA);
  static const alpaDark = Color(0xFFFF7A7A);
  static const tidakSetoranDark = Color(0xFFD7A176);
  static const tidakTahsinDark = Color(0xFFE0BA7D);
  static const tidakMurojaahDark = Color(0xFFC0AEEA);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Warna status Tahfizh.
  static Color tahfizhOn(BuildContext context) =>
      _isDark(context) ? tahfizhDark : tahfizh;

  /// Warna status Tahsin.
  static Color tahsinOn(BuildContext context) =>
      _isDark(context) ? tahsinDark : tahsin;

  /// Warna status Tahsin+Tahfizh.
  static Color tahsinTahfizhOn(BuildContext context) =>
      _isDark(context) ? tahsinTahfizhDark : tahsinTahfizh;

  /// Warna status Muroja'ah/Tasmi'.
  static Color murojaahTasmiOn(BuildContext context) =>
      _isDark(context) ? murojaahTasmiDark : murojaahTasmi;

  /// Warna generik untuk [HafalanStatus] apa pun.
  static Color statusOn(BuildContext context, HafalanStatus status) => switch (status) {
        HafalanStatus.tahfizh => tahfizhOn(context),
        HafalanStatus.tahsin => tahsinOn(context),
        HafalanStatus.tahsinTahfizh => tahsinTahfizhOn(context),
        HafalanStatus.murojaahTasmi => murojaahTasmiOn(context),
      };

  /// Versi dark-aware dari [keteranganColor].
  static Color keteranganColorOn(BuildContext context, String key) {
    final dark = _isDark(context);
    return switch (key) {
      'hadir' => dark ? hadirDark : hadir,
      'izinSakit' => dark ? izinSakitDark : izinSakit,
      'izin' => dark ? izinDark : izin,
      'izinLomba' => dark ? izinLombaDark : izinLomba,
      'izinPelatihan' => dark ? izinPelatihanDark : izinPelatihan,
      'alpa' => dark ? alpaDark : alpa,
      'tidakSetoran' => dark ? tidakSetoranDark : tidakSetoran,
      'tidakTahsin' => dark ? tidakTahsinDark : tidakTahsin,
      'tidakMurojaah' => dark ? tidakMurojaahDark : tidakMurojaah,
      _ => dark ? hadirDark : hadir,
    };
  }

  /// Versi non-context, warna "kertas putih" tetap.
  static Color keteranganColor(String key) => switch (key) {
        'hadir' => hadir,
        'izinSakit' => izinSakit,
        'izin' => izin,
        'izinLomba' => izinLomba,
        'izinPelatihan' => izinPelatihan,
        'alpa' => alpa,
        'tidakSetoran' => tidakSetoran,
        'tidakTahsin' => tidakTahsin,
        'tidakMurojaah' => tidakMurojaah,
        _ => hadir,
      };

  // --- Alias generik ---
  // Warna-warna di atas juga dipakai ulang di luar konteks "keterangan"
  // (mis. ikon format ekspor, kartu statistik).
  static Color greenOn(BuildContext context) => _isDark(context) ? hadirDark : hadir;
  static Color orangeOn(BuildContext context) => _isDark(context) ? izinSakitDark : izinSakit;
  static Color purpleOn(BuildContext context) => _isDark(context) ? izinLombaDark : izinLomba;
  static Color blueOn(BuildContext context) => _isDark(context) ? izinPelatihanDark : izinPelatihan;
  static Color redOn(BuildContext context) => _isDark(context) ? alpaDark : alpa;
}
