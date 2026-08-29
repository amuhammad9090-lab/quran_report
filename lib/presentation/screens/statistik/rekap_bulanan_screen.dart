import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/week_utils.dart';
import '../../../data/models/santri_record.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';
import 'generate_rekap_bulanan_screen.dart';
import 'generate_rekap_pekanan_screen.dart';
import 'rekap_harian_detail_screen.dart';

/// Rekap semua record tahfizh & tahsin dalam SATU bulan, dengan navigasi
/// bulan bebas (prev/next SELALU aktif, tidak dibatasi ke bulan yang
/// sudah punya data — guru pembimbing perlu bisa maju ke bulan depan yang
/// masih kosong buat mulai nyatet laporan di sana). Dibuka dari card
/// "Distribusi Capaian" di tab Statistik, default ke bulan berjalan.
///
/// Halaman "Pekan N" terpisah (RekapPekanBulanScreen) SUDAH DIHAPUS —
/// daftar hari & tombol "Generate Laporan Pekanan" sekarang langsung
/// ada di DALAM tiap kartu "Pekan N" di bawah (tap kartu buat expand,
/// lihat [_PekanCard]).
class RekapBulananScreen extends StatefulWidget {
  final DateTime initialMonth;
  const RekapBulananScreen({super.key, required this.initialMonth});

  @override
  State<RekapBulananScreen> createState() => _RekapBulananScreenState();
}

class _RekapBulananScreenState extends State<RekapBulananScreen> {
  late DateTime _month;

  // Pekan mana yang lagi expand (accordion — cuma 1 yang boleh kebuka
  // sekaligus). Dulu tiap _PekanCard nyimpen expand-state sendiri2, jadi
  // bisa kebuka bareng semua; sekarang dinaikin ke sini biar buka pekan
  // baru otomatis nutup yang sebelumnya.
  int? _expandedWeek;

  final Map<int, GlobalKey> _weekKeys = {};

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month);
  }

  void _gotoMonth(int monthDelta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + monthDelta);
      // Reset biar gak ada pekan yang "nyangkut" ke-render expanded di
      // bulan baru cuma karena weekIndex-nya kebetulan sama.
      _expandedWeek = null;
    });
  }

  void _gotoWeek(int weekIndex) {
    final ctx = _weekKeys[weekIndex]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.1,
    );
  }

  void _toggleWeek(int weekIndex) {
    final expanding = _expandedWeek != weekIndex;
    setState(() => _expandedWeek = expanding ? weekIndex : null);
    if (!expanding) return;

    // Auto-scroll pas expand, biar kartu (+ daftar hari yang baru nongol
    // di bawahnya) langsung ke-bawa ke atas viewport tanpa user harus
    // scroll manual lagi. Delay dulu ~sesuai durasi AnimatedCrossFade
    // (200ms) supaya ensureVisible ngitung berdasarkan tinggi kartu yang
    // udah (hampir) final, bukan tinggi lama pas masih collapsed.
    Future.delayed(const Duration(milliseconds: 220), () => _gotoWeek(weekIndex));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();

    final records = provider.recordsInMonth(_month);

    final totalTahfizh = provider.totalTahfizhInMonth(_month);
    final totalTahsin = provider.totalTahsinInMonth(_month);
    final totalBaris = provider.totalBarisInMonth(_month);
    final weeks = provider.monthWeekSummaries(_month);

    _weekKeys
      ..removeWhere((weekIndex, _) => weeks.every((w) => w.weekIndex != weekIndex))
      ..addEntries(
        weeks
            .where((w) => !_weekKeys.containsKey(w.weekIndex))
            .map((w) => MapEntry(w.weekIndex, GlobalKey())),
      );

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const PushedPageHeader(
              title: 'Rekap Bulanan',
              subtitle: 'Semua capaian tahfizh & tahsin dalam sebulan',
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              sliver: SliverToBoxAdapter(
                child: _MonthSwitcher(
                  month: _month,
                  onPrev: () => _gotoMonth(-1),
                  onNext: () => _gotoMonth(1),
                  onTapWeek: _gotoWeek,
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
              // Tombol Generate Rekap Bulanan — dipindah ke SINI (di bawah
              // card Tahfizh/Tahsin/Total Baris), sebelumnya ada di atas
              // (nempel langsung di bawah _MonthSwitcher).
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
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
                    weeks: weeks,
                    weekKeys: _weekKeys,
                    expandedWeek: _expandedWeek,
                    onToggleWeek: _toggleWeek,
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
            // buat auto-scroll ke kartu "Pekan N" itu di bawah (lihat
            // _MonthWeekList/_PekanCard) — ketuk lagi kartunya buat expand
            // lihat daftar harinya.
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
  final Map<int, GlobalKey> weekKeys;
  final int? expandedWeek;
  final ValueChanged<int> onToggleWeek;
  const _MonthWeekList({
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
          _PekanCard(
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
/// nampilin daftar hari (Senin..Minggu, lihat [_DayRow]) pekan itu +
/// tombol "Generate Laporan Pekanan" di bawahnya. Menggantikan halaman
/// terpisah RekapPekanBulanScreen yang sudah dihapus — isinya sama
/// (daftar hari + tombol generate), cuma sekarang inline di kartu ini,
/// bukan pindah halaman.
///
/// Expand-state SEKARANG dikontrol dari luar (accordion — lihat
/// [_RekapBulananScreenState._expandedWeek]), bukan state lokal lagi,
/// biar buka 1 pekan otomatis nutup pekan lain yang lagi kebuka.
class _PekanCard extends StatelessWidget {
  final DateTime month;
  final MonthWeekSummary summary;
  final bool expanded;
  final VoidCallback onToggle;
  const _PekanCard({
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
                              : '${w.santriCount} santri • ${w.laporanCount} laporan • ${w.totalBaris} baris',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more_rounded, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: _PekanExpandedBody(month: month, weekIndex: w.weekIndex),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Isi kartu Pekan pas di-expand — daftar hari (Senin..Minggu) pekan itu
/// (lihat [_DayRow]) + tombol "Generate Laporan Pekanan" (gabungan semua
/// hari di pekan itu, lihat [GenerateRekapPekananScreen]). Widget
/// terpisah (bukan langsung di [_PekanCardState.build]) supaya
/// context.watch<RecordsProvider>() di sini TIDAK bikin seluruh
/// [_PekanCard] (termasuk kartu2 yang lagi collapsed) ikut rebuild tiap
/// ada perubahan data — cuma bagian expanded ini aja.
class _PekanExpandedBody extends StatelessWidget {
  final DateTime month;
  final int weekIndex;
  const _PekanExpandedBody({required this.month, required this.weekIndex});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final cs = Theme.of(context).colorScheme;
    final range = WeekUtils.monthWeekRange(month, weekIndex);
    final records = provider.recordsInMonthWeek(month, weekIndex);
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
          _DayRow(
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
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Generate Laporan Pekanan'),
            ),
          ),
        ),
      ],
    );
  }
}

/// Satu baris hari (Senin, tanggalnya, jumlah laporan) di dalam kartu
/// Pekan yang lagi expand — sengaja dibuat RINGKAS (row kecil, bukan
/// kartu penuh seperti dulu di RekapPekanBulanScreen) karena sekarang
/// nempel di dalam kartu Pekan, bukan halaman sendiri. Ketuk buat lihat
/// tabel laporan hari itu (per Kelas & Halaqoh, lihat
/// [RekapHarianDetailScreen]) — perilakunya sama seperti dulu.
class _DayRow extends StatelessWidget {
  final DateTime date;
  final List<SantriRecord> records;
  const _DayRow({required this.date, required this.records});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final count = records.length;
    final totalBaris = records.fold<int>(0, (sum, r) => sum + (r.totalBaris ?? 0));

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
                count == 0 ? 'Belum ada laporan' : '$count laporan • $totalBaris baris',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: count == 0 ? cs.onSurfaceVariant : cs.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
