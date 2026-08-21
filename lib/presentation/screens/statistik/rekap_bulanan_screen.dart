import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../../widgets/record_card.dart';
import '../record_form/record_form_sheet.dart';

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
    final cs = Theme.of(context).colorScheme;

    final months = provider.availableMonths;
    final hasPrev = months.any((m) => m.isBefore(_month));
    final hasNext = months.any((m) => m.isAfter(_month));

    final records = provider.recordsInMonth(_month);
    final grouped = provider.groupByDate(records);
    final dates = grouped.keys.toList();

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
            const PushedPageHeader(
              title: 'Rekap Bulanan',
              subtitle: 'Semua capaian tahfizh & tahsin dalam sebulan',
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
                          color: const Color(0xFF0E7C61),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SummaryStatCard(
                          label: 'Tahsin',
                          value: '$totalTahsin',
                          icon: Icons.menu_book_rounded,
                          color: const Color(0xFFB8860B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SummaryStatCard(
                          label: 'Total Baris',
                          value: '$totalBaris',
                          icon: Icons.format_list_numbered_rounded,
                          color: const Color(0xFF6C5CE7),
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
                            color: const Color(0xFF0E7C61),
                          ),
                          const SizedBox(height: 18),
                          _DistribusiRow(
                            label: 'Tahsin',
                            count: totalTahsin,
                            ratio: tahsinRatio,
                            color: const Color(0xFFB8860B),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: SectionLabel('Semua Laporan (${records.length})'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList.list(
                  children: [
                    for (final date in dates) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10, top: 6),
                        child: Text(
                          DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      for (final r in grouped[date]!) ...[
                        RecordCard(
                          record: r,
                          onEdit: () => showRecordFormSheet(context, existing: r),
                          onDelete: () => _confirmDelete(context, r.id),
                        ),
                        const SizedBox(height: 12),
                      ],
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

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus laporan?'),
        content: const Text('Data yang dihapus tidak dapat dikembalikan.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () {
              context.read<RecordsProvider>().delete(id);
              Navigator.pop(ctx);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
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
