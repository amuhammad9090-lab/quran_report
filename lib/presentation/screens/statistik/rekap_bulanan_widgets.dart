import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/day_summary.dart';
import '../../../core/utils/week_utils.dart';
import '../../../data/models/santri_record.dart';
import '../../../providers/records_provider.dart';
import 'generate_rekap_pekanan_screen.dart';
import 'rekap_harian_detail_screen.dart';

class MonthSwitcher extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<int> onTapWeek;

  const MonthSwitcher({super.key, 
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onTapWeek,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final nowOwnerMonth = WeekUtils.ownerMonth(now);
    final isCurrentMonth =
        month.year == nowOwnerMonth.year && month.month == nowOwnerMonth.month;
    final currentWeek = isCurrentMonth ? WeekUtils.weekOfMonth(now) : null;
    final totalWeeks = WeekUtils.weeksInMonth(month);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 14),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onPrev,
                  icon: const Icon(LucideIcons.chevronLeft),
                  color: cs.primary,
                  tooltip: 'Bulan sebelumnya',
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
                  onPressed: onNext,
                  icon: const Icon(LucideIcons.chevronRight),
                  color: cs.primary,
                  tooltip: 'Bulan selanjutnya',
                ),
              ],
            ),
            const SizedBox(height: 2),
            // Ringkasan pekan dalam bulan ini (1..5) — pekan yang sesuai
            // tanggal HARI INI ditandai terisi/aktif (cuma kalau [month]
            // yang lagi dilihat memang bulan berjalan).
            Row(
              children: List.generate(totalWeeks, (i) {
                final weekIndex = i + 1;
                final isNow = currentWeek == weekIndex;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == totalWeeks - 1 ? 0 : 8),
                    child: InkWell(
                      onTap: () => onTapWeek(weekIndex),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isNow ? cs.primary : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Pekan $weekIndex',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isNow ? cs.onPrimary : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class MonthWeekList extends StatelessWidget {
  final DateTime month;
  final List<MonthWeekSummary> weeks;
  final Map<int, GlobalKey> weekKeys;
  final int? expandedWeek;
  final ValueChanged<int> onToggleWeek;
  const MonthWeekList({super.key, 
    required this.month,
    required this.weeks,
    required this.weekKeys,
    required this.expandedWeek,
    required this.onToggleWeek,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final w in weeks) ...[
          PekanCard(
            key: weekKeys[w.weekIndex],
            month: month,
            summary: w,
            expanded: expandedWeek == w.weekIndex,
            onToggle: () => onToggleWeek(w.weekIndex),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Kartu 1 Pekan — ketuk HEADER-nya buat expand/collapse, kalau expand
/// nampilin daftar hari (Senin..Minggu, lihat [DayRow]) pekan itu +
/// tombol "Generate Laporan Pekanan" di bawahnya.
class PekanCard extends StatelessWidget {
  final DateTime month;
  final MonthWeekSummary summary;
  final bool expanded;
  final VoidCallback onToggle;
  const PekanCard({
    super.key,
    required this.month,
    required this.summary,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = summary;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${w.weekIndex}',
                      style: TextStyle(fontWeight: FontWeight.w800, color: cs.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pekan ${w.weekIndex}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          w.laporanCount == 0
                              ? 'Belum ada laporan'
                              : '${w.santriCount} siswa • ${w.laporanCount} laporan • ${w.totalBaris} baris',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(LucideIcons.chevronDown, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: PekanExpandedBody(month: month, weekIndex: w.weekIndex),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Isi kartu Pekan pas di-expand — daftar hari (Senin..Minggu) pekan itu
/// (lihat [DayRow]) + tombol "Generate Laporan Pekanan" (gabungan semua
/// hari di pekan itu, lihat [GenerateRekapPekananScreen]).
class PekanExpandedBody extends StatelessWidget {
  final DateTime month;
  final int weekIndex;
  const PekanExpandedBody({super.key, required this.month, required this.weekIndex});

  @override
  Widget build(BuildContext context) {
    final records = context.select<RecordsProvider, List<SantriRecord>>(
      (p) => p.recordsInMonthWeek(month, weekIndex),
    );
    final cs = Theme.of(context).colorScheme;
    final range = WeekUtils.monthWeekRange(month, weekIndex);
    final bulanLabel = DateFormat('MMMM yyyy', 'id_ID').format(month);
    final rangeLabel = WeekUtils.rangeLabel(range);
    final dayOrder = List.generate(
      range.end.difference(range.start).inDays + 1,
      (i) => range.start.add(Duration(days: i)),
    );

    return Column(
      children: [
        const Divider(height: 1),
        for (var i = 0; i < dayOrder.length; i++) ...[
          if (i > 0)
            Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant.withValues(alpha: 0.4)),
          DayRow(
            date: dayOrder[i],
            records: records.where((r) => DateUtils.isSameDay(r.tanggal, dayOrder[i])).toList(),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: records.isEmpty
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GenerateRekapPekananScreen(
                            records: records,
                            weekIndex: weekIndex,
                            bulanLabel: bulanLabel,
                            rangeLabel: rangeLabel,
                            range: range,
                          ),
                        ),
                      ),
              icon: const Icon(LucideIcons.wandSparkles, size: 18),
              label: const Text('Generate Laporan Pekanan'),
            ),
          ),
        ),
      ],
    );
  }
}

/// Satu baris hari (Senin, tanggalnya, jumlah laporan) di dalam kartu
/// Pekan yang lagi expand.
class DayRow extends StatelessWidget {
  final DateTime date;
  final List<SantriRecord> records;
  const DayRow({super.key, required this.date, required this.records});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final count = records.length;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RekapHarianDetailScreen(date: date)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 66,
              child: Text(
                DateFormat('EEEE', 'id_ID').format(date),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: isToday ? cs.primary : null,
                ),
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                DateFormat('d MMM', 'id_ID').format(date),
                style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: Text(
                daySummaryText(records),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: count == 0 ? cs.onSurfaceVariant : cs.primary,
                ),
                softWrap: true,
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
