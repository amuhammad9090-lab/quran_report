import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/kelas_halaqoh_group_card.dart';
import '../../widgets/misc_widgets.dart';
import '../export/export_sheet.dart';

/// Rekap semua record tahfizh & tahsin dalam SATU bulan, dengan navigasi
/// bulan (prev/next dibatasi ke bulan yang punya data). Dibuka dari card
/// "Distribusi Capaian" di tab Statistik, default ke bulan berjalan.
class RekapBulananScreen extends StatefulWidget {
  final DateTime initialMonth;
  const RekapBulananScreen({super.key, required this.initialMonth});

  @override
  State<RekapBulananScreen> createState() => _RekapBulananScreenState();
}

class _RekapBulananScreenState extends State<RekapBulananScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();

    final months = provider.availableMonths;
    final hasPrev = months.any((m) => m.isBefore(_month));
    final hasNext = months.any((m) => m.isAfter(_month));

    final records = provider.recordsInMonth(_month);
    final kelasHalaqohGroups = provider.groupByKelasHalaqoh(records);

    final totalTahfizh = provider.totalTahfizhInMonth(_month);
    final totalTahsin = provider.totalTahsinInMonth(_month);
    final totalBaris = provider.totalBarisInMonth(_month);
    final totalCapaian = totalTahfizh + totalTahsin;
    final tahfizhRatio = totalCapaian == 0 ? 0.0 : totalTahfizh / totalCapaian;
    final tahsinRatio = totalCapaian == 0 ? 0.0 : totalTahsin / totalCapaian;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            PushedPageHeader(
              title: 'Rekap Bulanan',
              subtitle: 'Semua capaian tahfizh & tahsin dalam sebulan',
              trailing: records.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Ekspor',
                      onPressed: () => showExportSheet(
                        context,
                        records: records,
                        judul:
                            'Rekap Bulanan ${DateFormat('MMMM yyyy', 'id_ID').format(_month)}',
                        periode: DateFormat('MMMM yyyy', 'id_ID').format(_month),
                      ),
                      icon: const Icon(Icons.ios_share_rounded),
                    ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              sliver: SliverToBoxAdapter(
                child: _MonthSwitcher(
                  month: _month,
                  hasPrev: hasPrev,
                  hasNext: hasNext,
                  onPrev: () {
                    final prevMonths = months.where((m) => m.isBefore(_month)).toList()
                      ..sort((a, b) => b.compareTo(a));
                    if (prevMonths.isNotEmpty) setState(() => _month = prevMonths.first);
                  },
                  onNext: () {
                    final nextMonths = months.where((m) => m.isAfter(_month)).toList()
                      ..sort();
                    if (nextMonths.isNotEmpty) setState(() => _month = nextMonths.first);
                  },
                ),
              ),
            ),
            if (records.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.calendar_month_rounded,
                  title: 'Belum ada laporan',
                  subtitle: 'Tidak ada laporan tercatat di bulan ini.',
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: SummaryStatCard(
                          label: 'Tahfizh',
                          value: '$totalTahfizh',
                          icon: Icons.auto_stories_rounded,
                          color: AppColors.tahfizhOn(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SummaryStatCard(
                          label: 'Tahsin',
                          value: '$totalTahsin',
                          icon: Icons.menu_book_rounded,
                          color: AppColors.tahsinOn(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SummaryStatCard(
                          label: 'Total Baris',
                          value: '$totalBaris',
                          icon: Icons.format_list_numbered_rounded,
                          color: AppColors.purpleOn(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          _DistribusiRow(
                            label: 'Tahfizh',
                            count: totalTahfizh,
                            ratio: tahfizhRatio,
                            color: AppColors.tahfizhOn(context),
                          ),
                          const SizedBox(height: 18),
                          _DistribusiRow(
                            label: 'Tahsin',
                            count: totalTahsin,
                            ratio: tahsinRatio,
                            color: AppColors.tahsinOn(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: SectionLabel('Rekap per Kelas & Halaqoh'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                sliver: SliverList.list(
                  children: [
                    for (final g in kelasHalaqohGroups) ...[
                      KelasHalaqohGroupCard(
                        group: g,
                        onExport: () => _exportGroup(context, g),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _exportGroup(BuildContext context, KelasHalaqohGroup g) {
    final authProvider = context.read<AuthProvider>();
    String? guru = authProvider.guruPembimbingNameFor(g.kelas, g.halaqoh);
    if (guru == null) {
      final counts = <String, int>{};
      for (final r in g.records) {
        final id = r.ownerId;
        if (id == null) continue;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      if (counts.isNotEmpty) {
        final topId = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
        guru = authProvider.displayNameForId(topId);
      }
    }
    final bulanLabel = DateFormat('MMMM yyyy', 'id_ID').format(_month);
    showExportSheet(
      context,
      records: g.records,
      judul: 'Kelas ${g.kelas} Halaqoh ${g.halaqoh} - $bulanLabel',
      periode: bulanLabel,
      guruPembimbing: guru,
      includeTanggal: true,
    );
  }

}

class _MonthSwitcher extends StatelessWidget {
  final DateTime month;
  final bool hasPrev;
  final bool hasNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthSwitcher({
    required this.month,
    required this.hasPrev,
    required this.hasNext,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              onPressed: hasPrev ? onPrev : null,
              icon: const Icon(Icons.chevron_left_rounded),
              color: cs.primary,
            ),
            Expanded(
              child: Center(
                child: Text(
                  DateFormat('MMMM yyyy', 'id_ID').format(month),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
            IconButton(
              onPressed: hasNext ? onNext : null,
              icon: const Icon(Icons.chevron_right_rounded),
              color: cs.primary,
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
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const Spacer(),
            Text(
              '$count laporan • ${(ratio * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
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
