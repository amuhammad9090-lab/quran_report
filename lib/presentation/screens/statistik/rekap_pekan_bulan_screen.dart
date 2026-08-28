import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/week_utils.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/santri_record.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';
import 'generate_rekap_pekanan_screen.dart';
import 'rekap_harian_detail_screen.dart';

/// Rekap satu Pekan DALAM BULAN (1-6) — dibuka dari Statistik → Rekap
/// Bulanan → salah satu kartu "Pekan N" (baik dari [_MonthSwitcher] atau
/// [_MonthWeekList] di [RekapBulananScreen]). Pekan di sini SELALU dalam
/// satu bulan yang sama, tidak pernah lintas bulan (lihat WeekUtils). Ini
/// SATU-SATUNYA fitur rekap per-pekan di aplikasi — Rekap Pekanan (ISO
/// Senin-Minggu) yang dulu terpisah sudah dihapus total.
///
/// Section "Rekap per Kelas & Halaqoh" yang dulu ada di sini SUDAH
/// DIPINDAH ke laporan per-hari (tap salah satu baris "Rekap Harian" di
/// bawah -> [RekapHarianDetailScreen]) — halaman ini sekarang cuma
/// nampilin ringkasan pekan + daftar hari (tap buat lihat detail hari
/// itu) + tombol Generate Laporan Pekanan (gabungan semua hari, lihat
/// [GenerateRekapPekananScreen]).
class RekapPekanBulanScreen extends StatelessWidget {
  final DateTime month;
  final int weekIndex;
  const RekapPekanBulanScreen({super.key, required this.month, required this.weekIndex});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final range = WeekUtils.monthWeekRange(month, weekIndex);
    final records = provider.recordsInMonthWeek(month, weekIndex);

    final totalTahfizh = records.where((r) =>
        r.status == HafalanStatus.tahfizh || r.status == HafalanStatus.tahsinTahfizh).length;
    final bulanLabel = DateFormat('MMMM yyyy', 'id_ID').format(month);
    final rangeLabel = WeekUtils.rangeLabel(range);

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
                  child: _DailyRekapList(range: range, records: records),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => Navigator.of(context).push(
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
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('Generate Laporan Pekanan'),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rincian jumlah laporan per hari dalam pekan ini — ditampilkan buat
/// SEMUA pekan (Pekan 1, 2, 3, dst di bulan yang sama), bukan cuma pekan
/// yang lagi berjalan. Tiap baris hari bisa DI-TAP buat lihat laporan hari
/// itu (per Kelas & Halaqoh, lihat [RekapHarianDetailScreen]) — makanya
/// baris dibuat lebih besar/jelas dari sebelumnya (dulu cuma teks
/// ringkas, sekarang kartu penuh yang jelas kelihatan bisa di-tap).
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
        for (final day in dayOrder) ...[
          _DayCard(
            date: day,
            records: records.where((r) => DateUtils.isSameDay(r.tanggal, day)).toList(),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  final DateTime date;
  final List<SantriRecord> records;
  const _DayCard({required this.date, required this.records});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final count = records.length;
    final totalBaris = records.fold<int>(0, (sum, r) => sum + (r.totalBaris ?? 0));

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RekapHarianDetailScreen(date: date)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isToday ? cs.primary : cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  DateFormat('d', 'id_ID').format(date),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: isToday ? cs.onPrimary : cs.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE', 'id_ID').format(date),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: isToday ? cs.primary : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('d MMMM yyyy', 'id_ID').format(date),
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      count == 0 ? 'Belum ada laporan' : '$count laporan • $totalBaris baris',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: count == 0 ? cs.onSurfaceVariant : cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
