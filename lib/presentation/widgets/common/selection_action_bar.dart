import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Satu tombol aksi di [SelectionActionBar]: solid jika [filled] (warna error jika
/// [destructive], selain itu primary), selain itu outline. Dibungkus Expanded
/// oleh parent agar label panjang ("Keluarkan dari Folder") tidak kepotong.
class SelectionAction {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;
  final bool filled;

  const SelectionAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.filled = false,
  });
}

class _SelectionActionButton extends StatelessWidget {
  final SelectionAction action;
  const _SelectionActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = action.destructive ? cs.error : cs.primary;
    if (action.filled) {
      return FilledButton.icon(
        onPressed: action.onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(action.icon, size: 17),
        label: Text(action.label, overflow: TextOverflow.ellipsis, maxLines: 1),
      );
    }
    return OutlinedButton.icon(
      onPressed: action.onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        disabledForegroundColor: cs.onSurfaceVariant.withValues(alpha: 0.4),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(action.icon, size: 17),
      label: Text(action.label, overflow: TextOverflow.ellipsis, maxLines: 1),
    );
  }
}

/// Bar aksi mode pilih-banyak (Laporan & Folder), 2 baris ala Google Photos:
/// atas = "pilih semua" + jumlah terpilih + tutup (X), bawah = tombol aksi
/// (Expanded rata) agar label selalu muat berapa pun jumlah aksinya.
class SelectionActionBar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final ValueChanged<bool> onSelectAllChanged;
  final VoidCallback onCancel;
  final List<SelectionAction> actions;

  const SelectionActionBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAllChanged,
    required this.onCancel,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allSelected = totalCount > 0 && selectedCount == totalCount;

    return Material(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.18),
      color: Theme.of(context).cardTheme.color ?? cs.surface,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Checkbox(
                  value: allSelected,
                  onChanged: totalCount == 0 ? null : (v) => onSelectAllChanged(v ?? false),
                ),
                Expanded(
                  child: Text(
                    selectedCount == 0 ? 'Pilih Semua' : '$selectedCount dipilih',
                    style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onCancel,
                  icon: const Icon(LucideIcons.circleX),
                  tooltip: 'Batal',
                  visualDensity: VisualDensity.compact,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6, right: 2),
                child: Row(
                  children: [
                    for (int i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: _SelectionActionButton(action: actions[i])),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
