import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/week_utils.dart';
import '../../../data/models/santri_record.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/pushed_page_header.dart';
import '../../widgets/common/section_label.dart';
import '../../widgets/statistik/summary_stat_card.dart';
import 'generate_rekap_bulanan_screen.dart';
import 'rekap_bulanan_widgets.dart';

/// Rekap semua record tahfizh & tahsin dalam SATU bulan, dengan navigasi
/// bulan bebas (prev/next SELALU aktif).
class RekapBulananScreen extends StatefulWidget {
  final DateTime initialMonth;

  /// BARU: kalau diisi, layar ini otomatis EXPAND + auto-scroll ke kartu
  /// "Pekan N" yang memuat tanggal ini begitu dibuka.
  final DateTime? initialHighlightDay;

  const RekapBulananScreen({
    super.key,
    required this.initialMonth,
    this.initialHighlightDay,
  });

  @override
  State<RekapBulananScreen> createState() => _RekapBulananScreenState();
}

class _RekapBulananScreenState extends State<RekapBulananScreen> {
  late DateTime _month;
  int? _expandedWeek;

  final Map<int, GlobalKey> _weekKeys = {};

  @override
  void initState() {
    super.initState();
    final highlight = widget.initialHighlightDay;
    if (highlight != null) {
      final owner = WeekUtils.ownerMonth(highlight);
      _month = DateTime(owner.year, owner.month);
      _expandedWeek = WeekUtils.weekOfMonth(highlight);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 260), () {
          if (mounted) _gotoWeek(_expandedWeek!);
        });
      });
    } else {
      _month = DateTime(widget.initialMonth.year, widget.initialMonth.month);
    }
  }

  void _gotoMonth(int monthDelta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + monthDelta);
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
    Future.delayed(const Duration(milliseconds: 220), () => _gotoWeek(weekIndex));
  }

  @override
  Widget build(BuildContext context) {
    final (records, weeks) = context.select<RecordsProvider,
        (List<SantriRecord>, List<MonthWeekSummary>)>(
      (p) => (p.recordsInMonth(_month), p.monthWeekSummaries(_month)),
    );
    final provider = context.read<RecordsProvider>();

    final totalTahfizh = provider.totalTahfizhInMonth(_month);
    final totalTahsin = provider.totalTahsinInMonth(_month);
    final totalBaris = provider.totalBarisInMonth(_month);

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
                child: MonthSwitcher(
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
                  icon: LucideIcons.calendarDays,
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
                          icon: LucideIcons.bookOpen,
                          color: AppColors.tahfizhOn(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SummaryStatCard(
                          label: 'Tahsin',
                          value: '$totalTahsin',
                          icon: LucideIcons.bookOpen,
                          color: AppColors.tahsinOn(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SummaryStatCard(
                          label: 'Total Baris',
                          value: '$totalBaris',
                          icon: LucideIcons.list,
                          color: AppColors.purpleOn(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                      icon: const Icon(LucideIcons.wandSparkles, size: 18),
                      label: const Text('Generate Rekap Bulanan'),
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
                  child: MonthWeekList(
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

