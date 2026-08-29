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
            // Tombol export di header (sudut kanan atas) SUDAH DIHAPUS —
            // export tetap bisa lewat tombol per-tabel (1 Kelas+Halaqoh)
            // di samping tiap judul grup di bawah, lihat IconButton di
            // dalam SliverList.list.
            PushedPageHeader(
              title: 'Generate Rekap Bulanan',
              subtitle: bulanLabel,
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
///
/// Sengaja PAKAI [Table] bukan [DataTable] (sama seperti
/// [WeeklySantriRecapTable] di rekap pekanan): [DataTable] maksa SEMUA
/// baris & kolom punya tinggi yang sama, jadi kalau capaian 1 pekan
/// panjang jadinya kepotong "..." atau bikin SEMUA baris ikut tinggi.
/// [Table] menghitung tinggi tiap baris SENDIRI-SENDIRI ngikutin isinya —
/// santri yang capaiannya pendek tetap pas, yang panjang otomatis
/// melebar ke bawah tanpa mempengaruhi baris lain atau kepotong.
class _MonthlyRecapTable extends StatelessWidget {
  final List<SantriMonthlyRecap> recaps;
  final int totalWeeks;
  const _MonthlyRecapTable({required this.recaps, required this.totalWeeks});

  // Lebar kolom Nama / tiap Pekan / Total Baris / Keterangan — tinggal
  // diubah angkanya kalau mau lebih lebar/sempit.
  static const _namaWidth = 130.0;
  static const _pekanWidth = 150.0;
  static const _barisWidth = 60.0;
  static const _keteranganWidth = 110.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalWidth = _namaWidth + (_pekanWidth * totalWeeks) + _barisWidth + _keteranganWidth;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          child: Table(
            columnWidths: {
              0: const FixedColumnWidth(_namaWidth),
              for (var w = 1; w <= totalWeeks; w++) w: const FixedColumnWidth(_pekanWidth),
              totalWeeks + 1: const FixedColumnWidth(_barisWidth),
              totalWeeks + 2: const FixedColumnWidth(_keteranganWidth),
            },
            border: TableBorder(
              horizontalInside: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.5)),
                children: [
                  const _MonthlyHeaderCell('Nama'),
                  for (var w = 1; w <= totalWeeks; w++) _MonthlyHeaderCell('Pekan $w'),
                  const _MonthlyHeaderCell('Total Baris'),
                  const _MonthlyHeaderCell('Keterangan'),
                ],
              ),
              for (final r in recaps)
                TableRow(
                  children: [
                    Padding(
                      padding: _monthlyCellPadding,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!r.isCompleteThrough(totalWeeks))
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(Icons.circle, size: 8, color: AppColors.orangeOn(context)),
                            ),
                          Flexible(
                            child: Text(
                              r.nama,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: _monthlyFontSize),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (var w = 1; w <= totalWeeks; w++) _MonthlyCell(r.capaianForWeek(w)),
                    _MonthlyCell('${r.totalBaris}', bold: true),
                    Padding(
                      padding: _monthlyCellPadding,
                      child: Text(
                        r.keteranganSummaryText,
                        style: TextStyle(
                          fontSize: _monthlyFontSize,
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
      ),
    );
  }
}

// Padding & fontSize sel header/isi — sama pola seperti WeeklySantriRecapTable.
const _monthlyCellPadding = EdgeInsets.symmetric(horizontal: 6, vertical: 8);
const _monthlyFontSize = 12.0;

class _MonthlyHeaderCell extends StatelessWidget {
  final String text;
  const _MonthlyHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _monthlyCellPadding,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _monthlyFontSize)),
    );
  }
}

class _MonthlyCell extends StatelessWidget {
  final String text;
  final bool bold;
  const _MonthlyCell(this.text, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _monthlyCellPadding,
      child: Text(
        text,
        style: TextStyle(fontSize: _monthlyFontSize, fontWeight: bold ? FontWeight.w700 : FontWeight.normal),
      ),
    );
  }
}