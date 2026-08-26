import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/records_provider.dart';
import '../../../core/utils/week_utils.dart';
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
                  _AyatWeeklyChartCard(
                    weeklyData: provider.weeklyAyatSummary(weekCount: 6),
                  ),
                  const SizedBox(height: 24),
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
                              DistribusiRow(
                                label: 'Tahfizh',
                                count: totalTahfizhBulanIni,
                                ratio: tahfizhRatio,
                                color: AppColors.tahfizhOn(context),
                              ),
                              const SizedBox(height: 18),
                              DistribusiRow(
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

/// Kartu "Ayat Tersetor / Minggu" — bar chart 6 pekan terakhir + 2 pil
/// ringkasan (total & rata-rata), ditaruh paling atas tab Statistik biar
/// progres mingguan langsung kelihatan sebelum angka-angka lain.
class _AyatWeeklyChartCard extends StatelessWidget {
  final List<WeeklyAyatPoint> weeklyData;

  const _AyatWeeklyChartCard({required this.weeklyData});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totals = weeklyData.map((p) => p.total).toList();
    final maxValue = totals.isEmpty ? 0 : totals.reduce((a, b) => a > b ? a : b);
    final totalAyat = totals.fold<int>(0, (sum, v) => sum + v);
    final rataRata = totals.isEmpty ? 0.0 : totalAyat / totals.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Grafik Perkembangan'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ayat Tersetor / Minggu',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: cs.onSurface),
                ),
                const SizedBox(height: 18),
                if (maxValue == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Belum ada setoran ayat 6 pekan terakhir',
                        style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 140,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (int i = 0; i < weeklyData.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(
                            child: _WeekBar(
                              value: weeklyData[i].total,
                              maxValue: maxValue,
                              // Pekan terakhir (pekan berjalan) dikasih warna
                              // beda (hijau tosca, warna brand utama) biar
                              // langsung keliatan mana "minggu ini" — sisanya
                              // pakai warna amber Tahsin, senada palet app.
                              color: i == weeklyData.length - 1
                                  ? cs.primary
                                  : AppColors.tahsinOn(context),
                              // Label pakai rentang tanggal pekan (Senin-Minggu)
                              // via WeekUtils — sistem penanggalan pekanan yang
                              // sama dipakai di seluruh app (mis. "3–9 Agu"),
                              // BUKAN label generik "W1"/"W2" yang nggak nyambung
                              // sama kalender beneran.
                              label: WeekUtils.rangeLabel(
                                MonthWeekRange(
                                  start: weeklyData[i].weekStart,
                                  end: weeklyData[i].weekStart.add(const Duration(days: 6)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStatPill(
                        value: '$totalAyat',
                        label: 'Total Ayat 6 Pekan',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniStatPill(
                        value: rataRata.toStringAsFixed(1),
                        label: 'Rata² Setoran/Minggu',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 1 batang bar chart + label pekan di bawahnya. Tinggi batang proporsional
/// terhadap [maxValue] (nilai tertinggi di antara semua pekan), minimum 6px
/// biar pekan dengan nilai 0 tetap kelihatan ada batangnya (bukan hilang
/// total, biar sumbu tetap gampang dibaca).
class _WeekBar extends StatelessWidget {
  final int value;
  final int maxValue;
  final Color color;
  final String label;

  const _WeekBar({
    required this.value,
    required this.maxValue,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ratio = maxValue == 0 ? 0.0 : value / maxValue;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: ratio.clamp(0.04, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, height: 1.15),
        ),
      ],
    );
  }
}

/// Pil ringkasan kecil (angka besar + label) di bawah chart — dipisah dari
/// [_TappableStat] karena ini bukan tombol (tidak ada halaman detail buat
/// "total ayat 6 pekan", murni informasi).
class _MiniStatPill extends StatelessWidget {
  final String value;
  final String label;

  const _MiniStatPill({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
          ),
        ],
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
