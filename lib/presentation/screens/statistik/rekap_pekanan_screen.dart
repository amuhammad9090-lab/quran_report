import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/week_utils.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/kelas_halaqoh_group_card.dart';
import '../../widgets/misc_widgets.dart';
import '../export/export_sheet.dart';

/// Rekap PEKANAN — sejajar dengan Rekap Bulanan (tidak menggantikan),
/// dibuka dari tab Statistik. Nomor pekan pakai [WeekUtils] (ISO-8601,
/// Senin-Minggu) supaya konsisten dengan yang ditampilkan di Profile.
class RekapPekananScreen extends StatefulWidget {
  final DateTime initialDate;
  const RekapPekananScreen({super.key, required this.initialDate});

  @override
  State<RekapPekananScreen> createState() => _RekapPekananScreenState();
}

class _RekapPekananScreenState extends State<RekapPekananScreen> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = WeekUtils.startOfWeek(widget.initialDate);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final cs = Theme.of(context).colorScheme;

    final weeks = provider.availableWeeks;
    final hasPrev = weeks.any((w) => w.isBefore(_weekStart));
    final hasNext = weeks.any((w) => w.isAfter(_weekStart));

    final records = provider.recordsInWeek(_weekStart);
    final dailyBreakdown = provider.weekDailyBreakdown(_weekStart);
    final dayOrder = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    final kelasHalaqohGroups = provider.groupByKelasHalaqoh(records);

    final totalTahfizh = provider.totalTahfizhInWeek(_weekStart);
    final totalTahsin = provider.totalTahsinInWeek(_weekStart);
    final totalBaris = provider.totalBarisInWeek(_weekStart);
    final totalHadir = provider.totalHadirInWeek(_weekStart);
    final totalIzinAlpa = provider.totalIzinAlpaInWeek(_weekStart);
    final santriAktif = provider.santriAktifInWeek(_weekStart);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            PushedPageHeader(
              title: 'Rekap Pekanan',
              subtitle: WeekUtils.weekLabel(_weekStart),
              trailing: records.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Ekspor',
                      onPressed: () => showExportSheet(
                        context,
                        records: records,
                        judul: '${WeekUtils.weekLabel(_weekStart)} (${WeekUtils.rangeLabel(_weekStart)})',
                        periode: WeekUtils.rangeLabel(_weekStart),
                      ),
                      icon: const Icon(Icons.ios_share_rounded),
                    ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              sliver: SliverToBoxAdapter(
                child: _WeekSwitcher(
                  weekStart: _weekStart,
                  hasPrev: hasPrev,
                  hasNext: hasNext,
                  onPrev: () {
                    final prev = weeks.where((w) => w.isBefore(_weekStart)).toList()
                      ..sort((a, b) => b.compareTo(a));
                    if (prev.isNotEmpty) setState(() => _weekStart = prev.first);
                  },
                  onNext: () {
                    final next = weeks.where((w) => w.isAfter(_weekStart)).toList()..sort();
                    if (next.isNotEmpty) setState(() => _weekStart = next.first);
                  },
                ),
              ),
            ),
            if (records.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.calendar_view_week_rounded,
                  title: 'Belum ada laporan',
                  subtitle: 'Tidak ada laporan tercatat di pekan ini.',
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: SummaryStatCard(
                          label: 'Santri Aktif',
                          value: '$santriAktif',
                          icon: Icons.groups_2_rounded,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SummaryStatCard(
                          label: 'Hadir',
                          value: '$totalHadir',
                          icon: Icons.check_circle_rounded,
                          color: AppColors.greenOn(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SummaryStatCard(
                          label: 'Izin/Alpa',
                          value: '$totalIzinAlpa',
                          icon: Icons.event_busy_rounded,
                          color: AppColors.redOn(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: SectionLabel('Rekap Harian'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          for (int i = 0; i < dayOrder.length; i++) ...[
                            if (i > 0) Divider(height: 1, color: Theme.of(context).dividerTheme.color),
                            _DayCountRow(
                              date: dayOrder[i],
                              count: (dailyBreakdown[DateTime(
                                        dayOrder[i].year,
                                        dayOrder[i].month,
                                        dayOrder[i].day,
                                      )] ??
                                      const [])
                                  .length,
                            ),
                          ],
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
      // Fallback: cari ownerId yang paling sering muncul di kelompok ini
      // (assignment guru mungkin sudah berubah sejak laporan dibuat).
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
    showExportSheet(
      context,
      records: g.records,
      judul: 'Kelas ${g.kelas} Halaqoh ${g.halaqoh} - ${WeekUtils.weekLabel(_weekStart)}',
      periode: '${WeekUtils.weekLabel(_weekStart)} (${WeekUtils.rangeLabel(_weekStart)})',
      guruPembimbing: guru,
      includeTanggal: true,
    );
  }

}

class _WeekSwitcher extends StatelessWidget {
  final DateTime weekStart;
  final bool hasPrev;
  final bool hasNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _WeekSwitcher({
    required this.weekStart,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      WeekUtils.weekLabel(weekStart),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    Text(
                      WeekUtils.rangeLabel(weekStart),
                      style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                    ),
                  ],
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

class _DayCountRow extends StatelessWidget {
  final DateTime date;
  final int count;
  const _DayCountRow({required this.date, required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              DateFormat('EEEE', 'id_ID').format(date),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isToday ? cs.primary : null,
              ),
            ),
          ),
          Text(
            DateFormat('d MMM', 'id_ID').format(date),
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const Spacer(),
          Text(
            count == 0 ? '-' : '$count laporan',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: count == 0 ? cs.onSurfaceVariant : cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}
