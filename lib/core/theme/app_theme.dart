import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );

    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    // Warna dasar surface untuk card, dropdown menu, bottom sheet —
    // disamakan biar dropdown/date-picker nggak "beda dunia" sama input lain.
    final surfaceElevated = isDark ? const Color(0xFF181F26) : Colors.white;
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.55)
        : const Color(0xFF0E7C61).withValues(alpha: 0.10);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF10151A) : const Color(0xFFF6F8F7),
      canvasColor: surfaceElevated,
      textTheme: baseTextTheme,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
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
            isDark ? const Color(0xFF1E2732) : const Color(0xFFEFF3F1),
        selectedColor: colorScheme.primaryContainer,
        labelStyle: baseTextTheme.labelMedium,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1B232B) : const Color(0xFFF0F3F2),
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
        backgroundColor: isDark ? const Color(0xFF141B21) : Colors.white,
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
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      // Dipakai oleh showDatePicker() di record_form_sheet.dart — biar
      // kalender ikut nuansa teal/amber, bukan ungu default Material.
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
      // (Menu-nya sendiri ambil warna dari `canvasColor` di atas; borderRadius
      // menu perlu di-pass langsung lewat parameter `borderRadius:` pada
      // widget DropdownButtonFormField karena Flutter belum expose lewat Theme.)
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
      // record_form_sheet.dart (loading state saat generate/simpan laporan).
      // Bottom nav pill-style: indikator hijau di belakang ikon aktif,
      // label selalu tampil, mengikuti desain referensi.
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.14),
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
    );
  }
}
