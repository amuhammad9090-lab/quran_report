import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../../widgets/status_badge.dart';
import '../record_form/record_form_sheet.dart';

/// Rekap kehadiran — siapa saja hadir/izin sakit/izin lomba/izin
/// pelatihan/alpa, dikelompokkan per tanggal. Bisa difilter per jenis
/// keterangan lewat chip di atas.
class KehadiranScreen extends StatefulWidget {
  const KehadiranScreen({super.key});

  @override
  State<KehadiranScreen> createState() => _KehadiranScreenState();
}

class _KehadiranScreenState extends State<KehadiranScreen> {
  Keterangan? _filter;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final cs = Theme.of(context).colorScheme;

    final all = provider.allSortedByDateDesc;
    final filtered = _filter == null ? all : all.where((r) => r.keterangan == _filter).toList();
    final grouped = provider.groupByDate(filtered);
    final dates = grouped.keys.toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const PushedPageHeader(
              title: 'Kehadiran',
              subtitle: 'Rekap kehadiran santri per tanggal',
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              sliver: SliverToBoxAdapter(
                child: SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'Semua',
                        selected: _filter == null,
                        color: cs.primary,
                        onTap: () => setState(() => _filter = null),
                      ),
                      const SizedBox(width: 8),
                      for (final k in Keterangan.values) ...[
                        _FilterChip(
                          label: k.shortLabel,
                          icon: k.icon,
                          selected: _filter == k,
                          color: AppColors.keteranganColor(k.name),
                          onTap: () => setState(() => _filter = _filter == k ? null : k),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (dates.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.event_busy_rounded,
                  title: 'Belum ada data',
                  subtitle: _filter != null
                      ? 'Belum ada catatan untuk keterangan ini.'
                      : 'Kehadiran akan muncul di sini setelah ada laporan.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                sliver: SliverList.separated(
                  itemCount: dates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final date = dates[i];
                    final items = grouped[date]!;
                    return DateGroupCard(
                      date: date,
                      rows: items
                          .map((r) => SantriAttendanceRow(
                                nama: r.namaAnak,
                                kelas: r.kelas,
                                halaqoh: r.halaqoh,
                                keteranganChip:
                                    KeteranganChip(keterangan: r.keterangan, compact: true),
                                onTap: () => showRecordFormSheet(context, existing: r),
                              ))
                          .toList(),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.14) : Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Theme.of(context).dividerTheme.color ?? Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: selected ? color : Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
