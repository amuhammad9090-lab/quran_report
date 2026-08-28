import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/week_utils.dart';
import '../../../data/models/santri_record.dart';
import '../../../data/services/export_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../../widgets/weekly_santri_recap_table.dart';
import '../export/export_sheet.dart';

/// Hasil "Generate Laporan Pekanan" — menghimpun SEMUA laporan sepekan
/// (semua hari, semua Kelas & Halaqoh), dikelompokkan per Kelas+Halaqoh
/// (tiap grup = 1 tabel kecil), dibuka dari tombol di bawah "Rekap
/// Harian" pada [RekapPekanBulanScreen].
///
/// Beda dari tabel harian (lihat ExportStyleRecordsTable &
/// RekapHarianDetailScreen, yang 1 baris = 1 laporan): tabel di sini
/// (baik yang ditampilkan di layar lewat [WeeklySantriRecapTable] maupun
/// hasil export-nya) 1 baris = 1 SANTRI — semua laporannya sepekan
/// digabung: kolom Capaian dipecah per jenis (Tahsin/Tahfizh/
/// Tahsin+Tahfizh/Muroja'ah, masing2 cuma tampil kalau memang ada
/// tertulis di laporan hariannya) dan kolom Baris di-SUM dari SEMUA
/// laporan santri itu sepekan (lihat
/// ExportService.weeklyRowsGroupedBySantriFor). Kolom "Hari/Tanggal"
/// SELALU menunjukkan tanggal laporan TERAKHIR dibuat dalam pekan itu
/// (bukan tanggal masing-masing laporan) — sesuai permintaan biar rekap
/// pekanan menunjukkan "per kapan" gabungan ini dibuat.
///
/// Hasil export-nya 1 dokumen berisi semua grup (1 tabel per Kelas+
/// Halaqoh, bukan 1 tabel besar gabungan) + baris Guru Pembimbing per
/// grup kalau ada (lihat ExportService.exportGroupedPdf/Word/Excel).
class GenerateRekapPekananScreen extends StatelessWidget {
  final List<SantriRecord> records;
  final int weekIndex;
  final String bulanLabel;
  final String rangeLabel;
  final MonthWeekRange range;
  const GenerateRekapPekananScreen({
    super.key,
    required this.records,
    required this.weekIndex,
    required this.bulanLabel,
    required this.rangeLabel,
    required this.range,
  });

  String? _lastTanggalLabel(List<SantriRecord> all) {
    if (all.isEmpty) return null;
    final latest = all.reduce((a, b) => a.tanggal.isAfter(b.tanggal) ? a : b);
    return ExportService.instance.hariTanggalTextFor(latest.tanggal);
  }

  @override
  Widget build(BuildContext context) {
    final recordsProvider = context.watch<RecordsProvider>();
    final authProvider = context.watch<AuthProvider>();

    final sorted = List<SantriRecord>.from(records)
      ..sort((a, b) {
        final byDate = a.tanggal.compareTo(b.tanggal);
        if (byDate != 0) return byDate;
        return a.namaAnak.toLowerCase().compareTo(b.namaAnak.toLowerCase());
      });
    final fixedTanggalLabel = _lastTanggalLabel(sorted);
    final groups = recordsProvider.groupByKelasHalaqoh(sorted);
    // Kop periode di export (PDF/Word/Excel), mis. "Pekan ke-4, 24-30
    // Agustus 2026" — lihat WeekUtils.periodeLabel kenapa formatnya
    // beda dari subtitle di layar ini (yang boleh pakai en dash karena
    // dirender font sistem, bukan font PDF).
    final periodeText = WeekUtils.periodeLabel(weekIndex, range);

    final exportSections = [
      for (final g in groups)
        ExportKelasHalaqohSection<SantriRecord>(
          kelas: g.kelas,
          halaqoh: g.halaqoh,
          guruPembimbing: authProvider.guruPembimbingNameFor(g.kelas, g.halaqoh),
          items: g.records,
        ),
    ];

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Tombol export "semua grup jadi 1 dokumen" di pojok kanan atas
            // SUDAH DIHAPUS (sesuai permintaan) — export sekarang cuma
            // lewat tombol per-grup Kelas+Halaqoh di bawah (lihat
            // IconButton per baris grup). [exportSections] tetap dipakai
            // buat tombol per-grup itu.
            PushedPageHeader(
              title: 'Generate Laporan Pekanan',
              subtitle: 'Pekan $weekIndex • $rangeLabel • $bulanLabel',
            ),
            if (sorted.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Belum ada laporan untuk digabung',
                  subtitle: 'Isi dulu laporan santri di salah satu hari pekan ini.',
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '${sorted.length} laporan • ${groups.length} kelompok Kelas/Halaqoh'
                        '${fixedTanggalLabel != null ? ' • terakhir diisi $fixedTanggalLabel' : ''}',
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
                    for (var i = 0; i < groups.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Kelas ${groups[i].kelas} — Halaqoh ${groups[i].halaqoh}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                              ),
                            ),
                            // Export per-tabel (1 Kelas+Halaqoh doang) —
                            // satu-satunya cara export di halaman ini
                            // sekarang (tombol export-semua-grup di header
                            // sudah dihapus), jadi ini cuma bikin dokumen
                            // buat kelompok ini saja.
                            IconButton(
                              onPressed: () => showExportSheet(
                                context,
                                groupedSections: [exportSections[i]],
                                judul: 'Laporan Pekanan - Kelas ${groups[i].kelas} '
                                    'Halaqoh ${groups[i].halaqoh} - Pekan $weekIndex $bulanLabel',
                                periode: '$periodeText'
                                    '${fixedTanggalLabel != null ? ' (terakhir diisi $fixedTanggalLabel)' : ''}',
                                includeTanggal: true,
                                fixedTanggalLabel: fixedTanggalLabel,
                              ),
                              icon: const Icon(Icons.ios_share_rounded, size: 19),
                              tooltip: 'Export Kelas ${groups[i].kelas} — Halaqoh ${groups[i].halaqoh}',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      WeeklySantriRecapTable(
                        records: groups[i].records,
                        fixedTanggalLabel: fixedTanggalLabel,
                      ),
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