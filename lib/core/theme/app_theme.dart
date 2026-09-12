import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // Nama family sesuai yang didaftarkan di pubspec.yaml (fonts:).
  static const _fontFamily = 'PlusJakartaSans';

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );

    final baseTextTheme =
        (isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme)
            .apply(fontFamily: _fontFamily);

    // <-- BERUBAH: sebelumnya `#10151A`/`#181F26` — nyaris hitam pekat dan
    // jaraknya ke card cuma tipis, jadi kelihatan "gelap banget" & card
    // gak keangkat dari background-nya. Dinaikin sedikit ke keluarga
    // navy-charcoal yang lebih nyaman di mata, dengan jarak scaffold↔card
    // yang lebih jelas (biar tetap ada rasa "elevasi").
    //
    // Kontras warna aksen (lihat AppColors, komentar "≥6.5:1 di atas card
    // gelap") TETAP AMAN setelah ini — background baru masih jauh lebih
    // gelap dari teks/aksen terang manapun (dicek ulang: turun dari
    // ~9.5:1 ke ~8:1 buat kasus terketat, masih jauh di atas standar WCAG
    // AA 4.5:1).
    final surfaceElevated = isDark ? const Color(0xFF222B33) : Colors.white;
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.55)
        : const Color(0xFF0E7C61).withValues(alpha: 0.10);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF171D23) : const Color(0xFFF6F8F7),
      canvasColor: surfaceElevated,
      textTheme: baseTextTheme,
      fontFamily: _fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // Karena backgroundColor transparan, Flutter nggak bisa nebak
        // otomatis kontras ikon status bar.
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        // Disamakan dengan ukuran judul di Statistik/Laporan (headlineSmall
        // w800), sebelumnya titleLarge w700 kelihatan kekecilan.
        titleTextStyle: baseTextTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 2.5,
        color: surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shadowColor: shadowColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor:
            isDark ? const Color(0xFF2A343D) : const Color(0xFFEFF3F1),
        selectedColor: colorScheme.primaryContainer,
        labelStyle: baseTextTheme.labelMedium,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF252F38) : const Color(0xFFF0F3F2),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error, width: 1.2),
        ),
        labelStyle: baseTextTheme.bodyMedium?.copyWith(
          color: isDark ? Colors.white60 : Colors.black54,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: isDark ? 0 : 2,
          shadowColor: shadowColor,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: isDark ? 0 : 2,
          shadowColor: shadowColor,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        // <-- BERUBAH: sebelumnya `#141B21` -- malah lebih gelap dari
        // card-nya sendiri (`surfaceElevated`), jadi bottom sheet
        // (tempat form laporan diisi) kerasa paling gelap di seluruh
        // app. Disamain ke keluarga warna yang sama kayak card.
        backgroundColor: isDark ? const Color(0xFF1E262D) : Colors.white,
        elevation: isDark ? 0 : 6,
        shadowColor: shadowColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: false,
      ),
      dividerTheme: DividerThemeData(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
        space: 1,
      ),

      // Dipakai oleh showDatePicker() di record_form_sheet.dart
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surfaceElevated,
        elevation: isDark ? 0 : 6,
        shadowColor: shadowColor,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: colorScheme.primary,
        headerForegroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
          ),
        ),
        todayBorder: BorderSide(color: colorScheme.primary, width: 1.4),
        dayShape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        yearShape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        rangePickerBackgroundColor: surfaceElevated,
      ),

      // Dipakai oleh DropdownButtonFormField di record_form_sheet.dart.
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 1 : 6,
        shadowColor: shadowColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
          ),
        ),
      ),

      // Dipakai oleh CircularProgressIndicator di export_sheet.dart &
      // record_form_sheet.dart
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        // <-- BUG FIX: sebelumnya alpha 0.14 dipakai SAMA di kedua tema.
        // Di dark mode, `colorScheme.primary` hasil `ColorScheme.fromSeed`
        // adalah warna TERANG (biar kontras di atas permukaan gelap) —
        // alpha 0.14 dari warna terang di atas `scaffoldBackgroundColor`
        // yang sudah gelap (`#171D23`) jatuh jadi nyaris tidak kelihatan,
        // jadi pill indikator tab aktif (Home/Laporan/Statistik/
        // Pengaturan) di bottom nav "ilang" pas dark mode walau tab-nya
        // sebenarnya aktif. Dinaikin khusus utk dark mode biar tetap
        // kebaca, light mode dibiarkan seperti semula.
        indicatorColor: colorScheme.primary.withValues(alpha: isDark ? 0.24 : 0.14),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : (isDark ? Colors.white54 : Colors.black45),
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: _fontFamily,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : (isDark ? Colors.white54 : Colors.black45),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primary.withValues(alpha: 0.12),
        circularTrackColor: colorScheme.primary.withValues(alpha: 0.12),
      ),

      // Snackbar minimalis
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF232C34) : const Color(0xFF1F2A24),
        contentTextStyle: TextStyle(
          fontFamily: _fontFamily,
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: colorScheme.primary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }
}
