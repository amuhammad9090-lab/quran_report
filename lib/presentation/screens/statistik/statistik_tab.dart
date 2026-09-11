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
    final thisMonth = WeekUtils.ownerMonth(now);
    final totalTahfizhBulanIni = provider.totalTahfizhInMonth(thisMonth);
    final totalTahsinBulanIni = provider.totalTahsinInMonth(thisMonth);
    final totalCapaian = totalTahfizhBulanIni + totalTahsinBulanIni;
    final tahfizhRatio = totalCapaian == 0 ? 0.0 : totalTahfizhBulanIni / totalCapaian;
    final tahsinRatio = totalCapaian == 0 ? 0.0 : totalTahsinBulanIni / totalCapaian;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: provider.load,
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
              toolbarHeight: 84,
              titleSpacing: 20,
              title: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statistik',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Ringkasan progres tahfizh & tahsin santri',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              sliver: SliverList.list(
                children: [
                  _AyatWeeklyChartCard(
                    weeklyData: provider.weeklyAyatSummary(weekCount: 6),
                    totalSantri: provider.totalSantri,
                    totalHadir: provider.totalHadir,
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

/// Kartu "Ayat Tersetor / Minggu" — bar chart 6 pekan terakhir + 2 baris pil
/// ringkasan (Total Santri/Hadir yang tappable, lalu Total Ayat/Rata-rata),
/// ditaruh paling atas tab Statistik biar progres mingguan langsung
/// kelihatan sebelum angka-angka lain.
//
// <-- BERUBAH: Total Santri & Total Hadir dulu kartu `_TappableStat`
// terpisah di bawah kartu ini (dibikin kecil banget biar "gak berebut
// perhatian"), tapi hasilnya malah kebacanya kekecilan/kurang jelas.
// Sekarang digabung ke sini, gaya pil abu-abu yang sama kayak Total Ayat/
// Rata-rata Setoran (lebih besar & konsisten), tetap tappable ke halaman
// detail masing-masing (lihat _MiniStatPill.onTap).
class _AyatWeeklyChartCard extends StatelessWidget {
  final List<WeeklyAyatPoint> weeklyData;
  final int totalSantri;
  final int totalHadir;

  const _AyatWeeklyChartCard({
    required this.weeklyData,
    required this.totalSantri,
    required this.totalHadir,
  });

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
                              color: i == weeklyData.length - 1
                                  ? cs.primary
                                  : AppColors.tahsinOn(context),
                              // Label pakai rentang tanggal pekan (Senin-Minggu)
                              // via WeekUtils
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
                        value: '$totalSantri',
                        label: 'Total Santri',
                        icon: Icons.groups_2_rounded,
                        iconColor: cs.primary,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SantriListScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniStatPill(
                        value: '$totalHadir',
                        label: 'Total Hadir',
                        icon: Icons.check_circle_rounded,
                        iconColor: AppColors.greenOn(context),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const KehadiranScreen()),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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

/// 1 batang bar chart + label pekan di bawahnya.
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

/// Pil ringkasan kecil (angka besar + label) di bawah chart.
//
// <-- BERUBAH: sekarang dukung [onTap] + [icon]/[iconColor] opsional —
// dipakai buat Total Santri/Total Hadir (tappable, ada ikon+chevron),
// sementara Total Ayat/Rata-rata tetap pakai versi polos (onTap null).
class _MiniStatPill extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? iconColor;

  const _MiniStatPill({
    required this.value,
    required this.label,
    this.onTap,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: iconColor ?? cs.primary),
            const SizedBox(height: 6),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 16, color: cs.onSurfaceVariant),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: content,
      ),
    );
  }
}

