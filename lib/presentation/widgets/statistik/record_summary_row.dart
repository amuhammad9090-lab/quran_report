import 'package:flutter/material.dart';

import '../common/edited_badge.dart';
import '../common/soft_icon_box.dart';

/// Baris ringkas laporan tahfizh/tahsin di dalam [DateGroupCard] (Detail Santri):
/// status + capaian + keterangan, tanpa nama dan tanggal karena sudah
/// jadi konteks halaman dan header grup.
class RecordSummaryRow extends StatelessWidget {
  final IconData statusIcon;
  final Color statusColor;
  final String statusLabel;
  final String capaianText;
  final Widget keteranganChip;
  final VoidCallback? onTap;
  final bool isEdited;
  final String? catatan;

  const RecordSummaryRow({
    super.key,
    required this.statusIcon,
    required this.statusColor,
    required this.statusLabel,
    required this.capaianText,
    required this.keteranganChip,
    this.onTap,
    this.isEdited = false,
    this.catatan,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            SoftIconBox(icon: statusIcon, color: statusColor, size: 15, padding: 7, radius: 10),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                      if (isEdited) ...[
                        const SizedBox(width: 6),
                        EditedBadge(cs: cs),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    capaianText,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (catatan != null && catatan!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      catatan!.trim(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            keteranganChip,
          ],
        ),
      ),
    );
  }
}
