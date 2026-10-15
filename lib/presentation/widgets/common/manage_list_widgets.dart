import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Komponen bersama untuk layar kelola (Kelola Guru & Kelola Siswa): dialog konfirmasi hapus,
/// judul bagian, chip kecil, dan kartu baris dengan menu aksi.

/// Dialog konfirmasi tindakan yang tidak bisa dibatalkan. Mengembalikan true kalau dikonfirmasi.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Hapus',
}) async {
  final cs = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(LucideIcons.trash2, color: cs.error),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Judul bagian di dalam daftar, mis. "Guru Pembimbing  8".
class ManageSectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const ManageSectionHeader({super.key, required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: cs.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$count', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Chip kecil berwarna lembut (peran, jumlah kelas, peringatan).
class ManageChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const ManageChip({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// Aksi pada menu titik tiga sebuah baris.
enum ManageAction { edit, delete }

/// Kartu baris seragam: ikon/avatar di kiri, judul + isi di tengah, menu aksi di kanan.
/// Ketuk kartu = [onTap] (biasanya edit); menu menyediakan Edit dan Hapus.
class ManageRowCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final Widget? body;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String editLabel;

  const ManageRowCard({
    super.key,
    required this.leading,
    required this.title,
    this.body,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.editLabel = 'Edit',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 2, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (body != null) ...[
                        const SizedBox(height: 4),
                        body!,
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<ManageAction>(
                  icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
                  tooltip: 'Aksi',
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (a) => a == ManageAction.edit ? onEdit() : onDelete(),
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: ManageAction.edit,
                      child: Row(children: [
                        const Icon(LucideIcons.penLine, size: 18),
                        const SizedBox(width: 12),
                        Text(editLabel),
                      ]),
                    ),
                    PopupMenuItem(
                      value: ManageAction.delete,
                      child: Row(children: [
                        Icon(LucideIcons.trash2, size: 18, color: cs.error),
                        const SizedBox(width: 12),
                        Text('Hapus', style: TextStyle(color: cs.error)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
