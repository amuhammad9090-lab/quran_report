import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Tombol simpan lebar penuh di dasar form laporan.
class RecordSubmitButton extends StatelessWidget {
  final bool isEdit;
  final VoidCallback onPressed;

  const RecordSubmitButton({super.key, required this.isEdit, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary.withValues(alpha: 0.14),
          foregroundColor: cs.primary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800),
        ),
        onPressed: onPressed,
        icon: const Icon(LucideIcons.circleCheck, size: 20),
        label: Text(
            isEdit ? 'Simpan Perubahan' : 'Simpan Laporan'),
      ),
    );
  }
}
