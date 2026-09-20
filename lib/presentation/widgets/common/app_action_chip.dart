import 'package:flutter/material.dart';

/// Chip kecil bertinta lembut (pill ikon + label) untuk aksi "Export"/"Deploy"
/// di Rekap Pekanan & Rekap Bulanan; sengaja pill berlabel, bukan IconButton
/// polos, agar fungsi tiap aksi jelas.
class AppActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;
  final Widget? leadingOverride;

  const AppActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.leadingOverride,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: disabled ? 0.07 : 0.13),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                leadingOverride ??
                    Icon(icon, size: 15, color: disabled ? color.withValues(alpha: 0.45) : color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: disabled ? color.withValues(alpha: 0.45) : color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
