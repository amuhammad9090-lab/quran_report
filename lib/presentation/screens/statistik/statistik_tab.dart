import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';

/// Tab "Statistik" — full pakai angka yang sudah dihitung RecordsProvider,
/// tidak ada target/goal baru yang di-hardcode.
class StatistikTab extends StatelessWidget {
  const StatistikTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final cs = Theme.of(context).colorScheme;

    final totalCapaian = provider.totalTahfizh + provider.totalTahsin;
    final tahfizhRatio = totalCapaian == 0 ? 0.0 : provider.totalTahfizh / totalCapaian;
    final tahsinRatio = totalCapaian == 0 ? 0.0 : provider.totalTahsin / totalCapaian;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: provider.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              'Statistik',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              'Rekap keseluruhan data laporan',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.35,
              children: [
                SummaryStatCard(
                  label: 'Total Santri',
                  value: '${provider.totalSantri}',
                  icon: Icons.groups_2_rounded,
                  color: cs.primary,
                ),
                SummaryStatCard(
                  label: 'Total Baris',
                  value: '${provider.totalBarisSetoran}',
                  icon: Icons.format_list_numbered_rounded,
                  color: const Color(0xFF6C5CE7),
                ),
                SummaryStatCard(
                  label: 'Total Hadir',
                  value: '${provider.totalHadir}',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF2E9E5B),
                ),
                SummaryStatCard(
                  label: 'Izin / Alpa',
                  value: '${provider.totalIzinAlpa}',
                  icon: Icons.event_busy_rounded,
                  color: const Color(0xFFD64545),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionLabel('Distribusi Capaian'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _DistribusiRow(
                      label: 'Tahfizh',
                      count: provider.totalTahfizh,
                      ratio: tahfizhRatio,
                      color: const Color(0xFF0E7C61),
                    ),
                    const SizedBox(height: 18),
                    _DistribusiRow(
                      label: 'Tahsin',
                      count: provider.totalTahsin,
                      ratio: tahsinRatio,
                      color: const Color(0xFFB8860B),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistribusiRow extends StatelessWidget {
  final String label;
  final int count;
  final double ratio;
  final Color color;

  const _DistribusiRow({
    required this.label,
    required this.count,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const Spacer(),
            Text(
              '$count laporan • ${(ratio * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
