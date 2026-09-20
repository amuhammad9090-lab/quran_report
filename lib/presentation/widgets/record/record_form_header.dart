import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Kepala form laporan: grabber sheet, judul (Edit/Baru) + identitas santri terpilih, tombol hapus
/// (hanya saat edit) dan tutup, lalu garis pemisah.
class RecordFormHeader extends StatelessWidget {
  final bool isEdit;
  final String? nama;
  final String? kelas;
  final String? halaqoh;
  final VoidCallback onDelete;

  const RecordFormHeader({
    super.key,
    required this.isEdit,
    required this.nama,
    required this.kelas,
    required this.halaqoh,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEdit ? 'Edit Laporan' : 'Laporan Baru',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    if (nama != null && nama!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        nama!,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                          color: cs.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((kelas ?? '').isNotEmpty || (halaqoh ?? '').isNotEmpty)
                        Text(
                          '${kelas ?? '-'} • Halaqoh ${halaqoh ?? '-'}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ],
                ),
              ),
              if (isEdit)
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(LucideIcons.trash2, color: cs.error),
                  tooltip: 'Hapus laporan ini',
                ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(LucideIcons.circleX),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
