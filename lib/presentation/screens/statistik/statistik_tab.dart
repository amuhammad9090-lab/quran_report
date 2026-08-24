import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';
import 'santri_list_screen.dart';
import 'kehadiran_screen.dart';
import 'rekap_bulanan_screen.dart';

/// Tab "Statistik" — angka ringkas + pintu masuk ke 3 halaman detail:
/// Daftar Santri, Kehadiran, dan Rekap Bulanan.
class StatistikTab extends StatelessWidget {
  const StatistikTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final cs = Theme.of(context).colorScheme;

    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final totalTahfizhBulanIni = provider.totalTahfizhInMonth(thisMonth);
    final totalTahsinBulanIni = provider.totalTahsinInMonth(thisMonth);
    final totalCapaian = totalTahfizhBulanIni + totalTahsinBulanIni;
    final tahfizhRatio = totalCapaian == 0 ? 0.0 : totalTahfizhBulanIni / totalCapaian;
    final tahsinRatio = totalCapaian == 0 ? 0.0 : totalTahsinBulanIni / totalCapaian;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: provider.load,
        // SliverAppBar pinned — header nempel di atas pas discroll, senada
        // gaya Home & Laporan.
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 3,
              shadowColor: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.10),
              toolbarHeight: 68,
              titleSpacing: 20,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _TappableStat(
                          label: 'Total Santri',
                          value: '${provider.totalSantri}',
                          icon: Icons.groups_2_rounded,
                          color: cs.primary,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SantriListScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TappableStat(
                          label: 'Total Hadir',
                          value: '${provider.totalHadir}',
                          icon: Icons.check_circle_rounded,
                          color: AppColors.greenOn(context),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const KehadiranScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SectionLabel(
                    'Distribusi Capaian • ${DateFormat('MMMM yyyy', 'id_ID').format(thisMonth)}',
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RekapBulananScreen(initialMonth: thisMonth),
                        ),
                      ),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              _DistribusiRow(
                                label: 'Tahfizh',
                                count: totalTahfizhBulanIni,
                                ratio: tahfizhRatio,
                                color: AppColors.tahfizhOn(context),
                              ),
                              const SizedBox(height: 18),
                              _DistribusiRow(
                                label: 'Tahsin',
                                count: totalTahsinBulanIni,
                                ratio: tahsinRatio,
                                color: AppColors.tahsinOn(context),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Icon(Icons.calendar_month_rounded, size: 14, color: cs.onSurfaceVariant),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Ketuk untuk lihat rekap bulanan lengkap',
                                      style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurfaceVariant),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Versi tappable dari [SummaryStatCard] — dipakai buat Total Santri &
/// Total Hadir yang masing-masing buka halaman detailnya sendiri.
class _TappableStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TappableStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).dividerTheme.color ?? Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded,
                      size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
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
