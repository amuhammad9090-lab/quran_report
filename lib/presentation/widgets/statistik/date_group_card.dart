import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../common/soft_icon_box.dart';

/// Kartu kelompok per tanggal (Detail Santri, Kehadiran, Rekap Bulanan):
/// header tanggal + jumlah item, lalu [rows] dipisah garis tipis
/// dalam SATU card per tanggal, senada gaya Home.
class DateGroupCard extends StatelessWidget {
  final DateTime date;
  final List<Widget> rows;

  const DateGroupCard({super.key, required this.date, required this.rows});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateLabel = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SoftIconBox(
                  icon: LucideIcons.calendarDays,
                  color: cs.primary,
                  size: 14,
                  padding: 7,
                  radius: 10,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dateLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${rows.length}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary),
                  ),
                ),
              ],
            ),
            for (final row in rows) ...[
              Divider(height: 22, color: Theme.of(context).dividerTheme.color),
              row,
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
