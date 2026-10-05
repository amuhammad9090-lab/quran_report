import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/santri_record.dart';
import '../../../data/services/export_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/records_provider.dart';
import '../../sheets/export/export_sheet.dart';
import '../../widgets/common/app_action_chip.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/pushed_page_header.dart';
import '../../widgets/common/status_icons.dart';
import '../../widgets/statistik/date_group_card.dart';
import '../../widgets/statistik/santri_attendance_row.dart';
import '../../widgets/status_badge.dart';

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

  /// Export rekap kehadiran sesuai filter chip yang sedang aktif. Datanya dikelompokkan per
  /// Kelas+Halaqoh (urut tanggal naik) dan memakai pipeline export yang sama dengan Laporan
  /// Pekanan, jadi PDF/Word/Excel + Bagikan/Simpan langsung tersedia.
  void _export(List<SantriRecord> records) {
    final recordsProvider = context.read<RecordsProvider>();
    final auth = context.read<AuthProvider>();

    final sorted = List<SantriRecord>.from(records)
      ..sort((a, b) {
        final byDate = a.tanggal.compareTo(b.tanggal);
        if (byDate != 0) return byDate;
        return a.namaAnak.toLowerCase().compareTo(b.namaAnak.toLowerCase());
      });
    final groups = recordsProvider.groupByKelasHalaqoh(sorted);
    final sections = [
      for (final g in groups)
        ExportKelasHalaqohSection<SantriRecord>(
          kelas: g.kelas,
          halaqoh: g.halaqoh,
          guruPembimbing: auth.guruPembimbingNameFor(g.kelas, g.halaqoh),
          items: g.records,
        ),
    ];

    final fmt = DateFormat('d MMM yyyy', 'id_ID');
    final first = sorted.first.tanggal;
    final last = sorted.last.tanggal;
    final periode = DateUtils.isSameDay(first, last)
        ? fmt.format(first)
        : '${fmt.format(first)} - ${fmt.format(last)}';

    showExportSheet(
      context,
      groupedSections: sections,
      judul: _filter == null
          ? 'Rekap Kehadiran Santri'
          : 'Rekap Kehadiran Santri - ${_filter!.label}',
      periode: periode,
      includeTanggal: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = context.select<RecordsProvider, List<SantriRecord>>(
      (p) => p.allSortedByDateDesc,
    );
    final provider = context.read<RecordsProvider>();
    final cs = Theme.of(context).colorScheme;

    final filtered = _filter == null ? all : all.where((r) => r.keterangan == _filter).toList();
    final grouped = provider.groupByDate(filtered);
    final dates = grouped.keys.toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            PushedPageHeader(
              title: 'Kehadiran',
              subtitle: 'Rekap kehadiran santri per tanggal',
              trailing: AppActionChip(
                icon: LucideIcons.upload,
                label: 'Export',
                color: AppColors.deployOn(context),
                tooltip: _filter == null
                    ? 'Export seluruh rekap kehadiran'
                    : 'Export rekap kehadiran: ${_filter!.label}',
                // Nonaktif kalau tidak ada data (sesuai filter aktif).
                onTap: filtered.isEmpty ? null : () => _export(filtered),
              ),
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
                          color: AppColors.keteranganColorOn(context, k.name),
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
                  icon: LucideIcons.calendarDays,
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
                                // <-- BERUBAH: dulu tap baris ini buka form
                                // edit -- sekarang read-only (lihat catatan
                                // yang sama di santri_detail_screen.dart).
                                // Edit laporan cuma lewat tab Laporan/Folder.
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
