import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/week_utils.dart';
import '../../../data/models/santri_monthly_recap.dart';
import '../../../data/services/export_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../export/export_sheet.dart';

/// Hasil "Generate" dari Rekap Bulanan — menghimpun laporan tiap santri
/// dari Pekan 1 s/d Pekan terakhir bulan itu jadi SATU baris per santri,
/// dikelompokkan per Kelas+Halaqoh (tiap grup = 1 tabel kecil sendiri)
class GenerateRekapBulananScreen extends StatelessWidget {
  final DateTime month;
  const GenerateRekapBulananScreen({super.key, required this.month});

  List<ExportKelasHalaqohSection<SantriMonthlyRecap>> _groupByKelasHalaqoh(
      List<SantriMonthlyRecap> recaps,
      AuthProvider auth,
      ) {
    final map = <String, List<SantriMonthlyRecap>>{};
    for (final r in recaps) {
      final key = '${r.kelas}|${r.halaqoh}';
      map.putIfAbsent(key, () => []).add(r);
    }
    final groups = map.entries.map((e) {
      final parts = e.key.split('|');
      final list = List<SantriMonthlyRecap>.from(e.value)
        ..sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
      return ExportKelasHalaqohSection<SantriMonthlyRecap>(
        kelas: parts[0],
        halaqoh: parts[1],
        guruPembimbing: auth.guruPembimbingNameFor(parts[0], parts[1]),
        items: list,
      );
    }).toList()
      ..sort((a, b) {
        final byKelas = a.kelas.compareTo(b.kelas);
        if (byKelas != 0) return byKelas;
        return a.halaqoh.compareTo(b.halaqoh);
      });
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final authProvider = context.watch<AuthProvider>();
    final recaps = provider.monthlySantriRecaps(month);
    final totalWeeks = WeekUtils.weeksInMonth(month);
    final bulanLabel = DateFormat('MMMM yyyy', 'id_ID').format(month);
    final groups = _groupByKelasHalaqoh(recaps, authProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            PushedPageHeader(
              title: 'Generate Rekap Bulanan',
              subtitle: bulanLabel,
              trailing: recaps.isEmpty
                  ? null
                  : IconButton(
                onPressed: () => showExportSheet(
                  context,
                  groupedMonthlySections: groups,
                  totalWeeks: totalWeeks,
                  judul: 'Rekap Bulanan - $bulanLabel',
                  periode: bulanLabel,
                ),
                icon: const Icon(Icons.ios_share_rounded),
                tooltip: 'Export Rekap Bulanan',
              ),
            ),
            if (recaps.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Belum ada capaian untuk digabung',
                  subtitle:
                  'Isi dulu laporan santri di salah satu Pekan bulan ini, baru rekap bulanan bisa di-generate.',
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '${recaps.length} santri • ${groups.length} kelompok Kelas/Halaqoh • gabungan Pekan 1-$totalWeeks',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                sliver: SliverList.list(
                  children: [
                    for (final g in groups) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Kelas ${g.kelas} — Halaqoh ${g.halaqoh}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                              ),
                            ),
                            // Export per-tabel (1 Kelas+Halaqoh doang) —
                            // beda dari tombol di header halaman (yang
                            // export SEMUA kelompok jadi 1 dokumen).
                            IconButton(
                              onPressed: () => showExportSheet(
                                context,
                                groupedMonthlySections: [g],
                                totalWeeks: totalWeeks,
                                judul: 'Rekap Bulanan - Kelas ${g.kelas} '
                                    'Halaqoh ${g.halaqoh} - $bulanLabel',
                                periode: bulanLabel,
                              ),
                              icon: const Icon(Icons.ios_share_rounded, size: 19),
                              tooltip: 'Export Kelas ${g.kelas} — Halaqoh ${g.halaqoh}',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      _MonthlyRecapTable(recaps: g.items, totalWeeks: totalWeeks),
                      const SizedBox(height: 20),
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
}

/// Tabel scroll horizontal: 1 baris = 1 santri (dalam SATU Kelas+Halaqoh —
/// lihat pengelompokan di [GenerateRekapBulananScreen]), kolom Pekan 1..N
/// menampilkan ringkasan capaiannya tiap pekan. Santri yang belum lengkap
/// laporannya di semua Pekan ditandai indikator kuning di sisi kiri baris.
class _MonthlyRecapTable extends StatelessWidget {
  final List<SantriMonthlyRecap> recaps;
  final int totalWeeks;
  const _MonthlyRecapTable({required this.recaps, required this.totalWeeks});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(cs.primaryContainer.withValues(alpha: 0.5)),
          columnSpacing: 20,
          columns: [
            const DataColumn(label: Text('Nama', style: TextStyle(fontWeight: FontWeight.w800))),
            for (var w = 1; w <= totalWeeks; w++)
              DataColumn(label: Text('Pekan $w', style: const TextStyle(fontWeight: FontWeight.w800))),
            const DataColumn(label: Text('Total Baris', style: TextStyle(fontWeight: FontWeight.w800))),
            const DataColumn(label: Text('Keterangan', style: TextStyle(fontWeight: FontWeight.w800))),
          ],
          rows: [
            for (final r in recaps)
              DataRow(
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!r.isCompleteThrough(totalWeeks))
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(Icons.circle, size: 8, color: AppColors.orangeOn(context)),
                          ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text(r.nama,
                              style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  for (var w = 1; w <= totalWeeks; w++)
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(r.capaianForWeek(w), overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  DataCell(Text('${r.totalBaris}')),
                  DataCell(
                    Text(
                      r.keteranganSummaryText,
                      style: TextStyle(
                        color: r.keteranganCounts.isEmpty ? cs.onSurfaceVariant : AppColors.orangeOn(context),
                        fontWeight: r.keteranganCounts.isEmpty ? FontWeight.normal : FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}