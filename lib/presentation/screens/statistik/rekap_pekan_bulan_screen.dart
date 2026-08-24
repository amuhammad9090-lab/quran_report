import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/week_utils.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/santri_record.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/kelas_halaqoh_group_card.dart';
import '../../widgets/misc_widgets.dart';
import '../export/export_sheet.dart';

/// Rekap satu Pekan DALAM BULAN (1-6) — dibuka dari Statistik → Rekap
/// Bulanan → salah satu kartu "Pekan N" (baik dari [_MonthSwitcher] atau
/// [_MonthWeekList] di [RekapBulananScreen]). Pekan di sini SELALU dalam
/// satu bulan yang sama, tidak pernah lintas bulan (lihat WeekUtils). Ini
/// SATU-SATUNYA fitur rekap per-pekan di aplikasi — Rekap Pekanan (ISO
/// Senin-Minggu) yang dulu terpisah sudah dihapus total.
class RekapPekanBulanScreen extends StatelessWidget {
  final DateTime month;
  final int weekIndex;
  const RekapPekanBulanScreen({super.key, required this.month, required this.weekIndex});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final range = WeekUtils.monthWeekRange(month, weekIndex);
    final records = provider.recordsInMonthWeek(month, weekIndex);
    final kelasHalaqohGroups = provider.groupByKelasHalaqoh(records);

    final totalTahfizh = records.where((r) =>
        r.status == HafalanStatus.tahfizh || r.status == HafalanStatus.tahsinTahfizh).length;
    final bulanLabel = DateFormat('MMMM yyyy', 'id_ID').format(month);
    final rangeLabel = _rangeLabel(range);

    final tahfizhCount = totalTahfizh;
    final tahsinCount = records.length - tahfizhCount;
    final totalBaris = records.fold<int>(0, (sum, r) => sum + (r.totalBaris ?? 0));

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            PushedPageHeader(
              title: 'Pekan $weekIndex',
              subtitle: '$rangeLabel • $bulanLabel',
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
                          value: '$tahfizhCount',
                          icon: Icons.auto_stories_rounded,
                          color: AppColors.tahfizhOn(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SummaryStatCard(
                          label: 'Tahsin',
                          value: '$tahsinCount',
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
                      child: _DailyRekapList(range: range, records: records),
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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

  String _rangeLabel(MonthWeekRange range) => WeekUtils.rangeLabel(range);

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
    final bulanLabel = DateFormat('MMMM yyyy', 'id_ID').format(month);
    showExportSheet(
      context,
      records: g.records,
      judul: 'Kelas ${g.kelas} Halaqoh ${g.halaqoh} - Pekan $weekIndex $bulanLabel',
      periode: 'Pekan $weekIndex $bulanLabel',
      guruPembimbing: guru,
      includeTanggal: true,
    );
  }
}

/// Rincian jumlah laporan per hari dalam pekan ini — ditampilkan buat
/// SEMUA pekan (Pekan 1, 2, 3, dst di bulan yang sama), bukan cuma pekan
/// yang lagi berjalan, di atas section "Rekap per Kelas & Halaqoh".
class _DailyRekapList extends StatelessWidget {
  final MonthWeekRange range;
  final List<SantriRecord> records;
  const _DailyRekapList({required this.range, required this.records});

  @override
  Widget build(BuildContext context) {
    final dayOrder = List.generate(
      range.end.difference(range.start).inDays + 1,
      (i) => range.start.add(Duration(days: i)),
    );

    return Column(
      children: [
        for (int i = 0; i < dayOrder.length; i++) ...[
          if (i > 0) Divider(height: 1, color: Theme.of(context).dividerTheme.color),
          _DayCountRow(
            date: dayOrder[i],
            count: records.where((r) => DateUtils.isSameDay(r.tanggal, dayOrder[i])).length,
          ),
        ],
      ],
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
