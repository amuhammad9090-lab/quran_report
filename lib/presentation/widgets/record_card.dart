import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../data/models/santri_record.dart';
import 'status_badge.dart';

class RecordCard extends StatelessWidget {
  final SantriRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const RecordCard({
    super.key,
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateStr = DateFormat('d MMM yyyy', 'id_ID').format(record.tanggal);

    return Slidable(
      key: ValueKey(record.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.24,
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: cs.errorContainer,
            foregroundColor: cs.onErrorContainer,
            icon: Icons.delete_outline_rounded,
            label: 'Hapus',
            borderRadius: BorderRadius.circular(20),
          ),
        ],
      ),
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        record.namaAnak.isNotEmpty ? record.namaAnak[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.namaAnak,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kelas ${record.kelas} • Halaqoh ${record.halaqoh}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: cs.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: record.status),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bookmark_border_rounded, size: 16, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          record.capaianText,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (record.totalBaris != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${record.totalBaris} baris',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 13, color: cs.onSurfaceVariant),
                    const SizedBox(width: 5),
                    Text(
                      dateStr,
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    const Spacer(),
                    KeteranganChip(keterangan: record.keterangan, compact: true),
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
