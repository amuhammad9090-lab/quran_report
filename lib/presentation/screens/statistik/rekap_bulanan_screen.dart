import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/week_utils.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../export/export_sheet.dart';
import 'generate_rekap_bulanan_screen.dart';
import 'rekap_pekan_bulan_screen.dart';

/// Rekap semua record tahfizh & tahsin dalam SATU bulan, dengan navigasi
/// bulan bebas (prev/next SELALU aktif, tidak dibatasi ke bulan yang
/// sudah punya data — guru pembimbing perlu bisa maju ke bulan depan yang
/// masih kosong buat mulai nyatet laporan di sana). Dibuka dari card
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

  void _gotoMonth(int monthDelta) {
    setState(() => _month = DateTime(_month.year, _month.month + monthDelta));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();

    final records = provider.recordsInMonth(_month);

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
              // Export langsung seluruh data bulan yang lagi dilihat, tanpa
              // harus masuk ke tiap Pekan satu-satu dulu.
              trailing: records.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => showExportSheet(
                        context,
                        records: records,
                        judul: 'Rekap Bulanan - ${DateFormat('MMMM yyyy', 'id_ID').format(_month)}',
                        periode: DateFormat('MMMM yyyy', 'id_ID').format(_month),
                        includeTanggal: true,
                      ),
                      icon: const Icon(Icons.ios_share_rounded),
                      tooltip: 'Export Rekap Bulanan',
                    ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              sliver: SliverToBoxAdapter(
                child: _MonthSwitcher(
                  month: _month,
                  onPrev: () => _gotoMonth(-1),
                  onNext: () => _gotoMonth(1),
                  onTapWeek: (weekIndex) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RekapPekanBulanScreen(month: _month, weekIndex: weekIndex),
                    ),
                  ),
                ),
              ),
            ),
            if (records.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GenerateRekapBulananScreen(month: _month),
                        ),
                      ),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('Generate Rekap Bulanan (Pekan 1-Terakhir)'),
                    ),
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
                          DistribusiRow(
                            label: 'Tahfizh',
                            count: totalTahfizh,
                            ratio: tahfizhRatio,
                            color: AppColors.tahfizhOn(context),
                          ),
                          const SizedBox(height: 18),
                          DistribusiRow(
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
                  child: SectionLabel('Rekap Pekan'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverToBoxAdapter(
                  child: _MonthWeekList(
                    month: _month,
                    weeks: provider.monthWeekSummaries(_month),
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

class _MonthSwitcher extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<int> onTapWeek;

  const _MonthSwitcher({
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
                  icon: const Icon(Icons.chevron_left_rounded),
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
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: cs.primary,
                  tooltip: 'Bulan selanjutnya',
                ),
              ],
            ),
            const SizedBox(height: 2),
            // Ringkasan pekan dalam bulan ini (1..5) — pekan yang sesuai
            // tanggal HARI INI ditandai terisi/aktif (cuma kalau [month]
            // yang lagi dilihat memang bulan berjalan). Ketuk salah satu
            // buat langsung loncat ke Rekap Pekan itu (lihat _MonthWeekList
            // di bawah buat versi lengkap dengan jumlah santri/laporan).
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: List.generate(totalWeeks, (i) {
                final weekIndex = i + 1;
                final isNow = currentWeek == weekIndex;
                return InkWell(
                  onTap: () => onTapWeek(weekIndex),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isNow ? cs.primary : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Pekan $weekIndex',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isNow ? cs.onPrimary : cs.onSurfaceVariant,
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

class _MonthWeekList extends StatelessWidget {
  final DateTime month;
  final List<MonthWeekSummary> weeks;
  const _MonthWeekList({required this.month, required this.weeks});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final w in weeks) ...[
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RekapPekanBulanScreen(month: month, weekIndex: w.weekIndex),
                ),
              ),
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
                                : '${w.santriCount} santri • ${w.laporanCount} laporan • ${w.totalBaris} baris',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
