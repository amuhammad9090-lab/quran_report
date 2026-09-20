import 'package:flutter/material.dart';

import 'field_icon.dart';

/// Dekorasi input seragam untuk semua kolom form (TextFormField &
/// DropdownButtonFormField): ikon dalam kotak warna sebagai prefix, isian
/// rounded-16 tanpa border, dengan aksen warna saat fokus/error.
InputDecoration fieldDecoration(
    BuildContext context, {
      required IconData icon,
      required String label,
      String? hint,
      String? errorText,
      Color? accent,
    }) {
  final cs = Theme.of(context).colorScheme;
  final color = accent ?? cs.primary;
  final fill = Theme.of(context).inputDecorationTheme.fillColor;
  return InputDecoration(
    hintText: hint != null ? '$label ($hint)' : label,
    errorText: errorText,
    filled: true,
    fillColor: fill,
    prefixIcon: Padding(
      padding: const EdgeInsets.all(8),
      child: FieldIcon(icon: icon, color: color, size: 34),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 34),
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: cs.error, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: cs.error, width: 1.6),
    ),
  );
}

/// Versi [InputDecorationTheme] dari [fieldDecoration] — dipakai widget yang
/// minta tema, bukan instance dekorasi langsung (mis. [DropdownMenu]).
InputDecorationTheme fieldDecorationTheme(
    BuildContext context, {
      required Color accent,
    }) {
  final cs = Theme.of(context).colorScheme;
  final fill = Theme.of(context).inputDecorationTheme.fillColor;
  return InputDecorationTheme(
    filled: true,
    fillColor: fill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: accent, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: cs.error, width: 1.2),
    ),
  );
}
