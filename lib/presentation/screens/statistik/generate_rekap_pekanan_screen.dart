import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/models/santri_record.dart';
import '../../../data/services/export_service.dart';
import '../../widgets/export_style_records_table.dart';
import '../../widgets/misc_widgets.dart';
import '../export/export_sheet.dart';

/// Hasil "Generate Laporan Pekanan" — menghimpun SEMUA laporan sepekan
/// (semua hari, semua Kelas & Halaqoh) jadi satu tabel gabungan dengan
/// kolom yang sama seperti tabel harian (lihat [ExportStyleRecordsTable]),
/// dibuka dari tombol di bawah "Rekap Harian" pada [RekapPekanBulanScreen].
///
/// Beda dari tabel harian: kolom "Hari/Tanggal" di sini (baik yang
/// ditampilkan di layar maupun hasil export-nya) SELALU menunjukkan
/// tanggal laporan TERAKHIR dibuat dalam pekan itu (bukan tanggal
/// masing-masing baris) — sesuai permintaan biar rekap pekanan
/// menunjukkan "per kapan" gabungan ini dibuat.
class GenerateRekapPekananScreen extends StatelessWidget {
  final List<SantriRecord> records;
  final int weekIndex;
  final String bulanLabel;
  final String rangeLabel;
  const GenerateRekapPekananScreen({
    super.key,
    required this.records,
    required this.weekIndex,
    required this.bulanLabel,
    required this.rangeLabel,
  });

  String? get _lastTanggalLabel {
    if (records.isEmpty) return null;
    final latest = records.reduce((a, b) => a.tanggal.isAfter(b.tanggal) ? a : b);
    return ExportService.instance.hariTanggalTextFor(latest.tanggal);
  }

  List<SantriRecord> get _sorted {
    final list = List<SantriRecord>.from(records)
      ..sort((a, b) {
        final byDate = a.tanggal.compareTo(b.tanggal);
        if (byDate != 0) return byDate;
        return a.namaAnak.toLowerCase().compareTo(b.namaAnak.toLowerCase());
      });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final fixedTanggalLabel = _lastTanggalLabel;
    final sorted = _sorted;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            PushedPageHeader(
              title: 'Generate Laporan Pekanan',
              subtitle: 'Pekan $weekIndex • $rangeLabel • $bulanLabel',
              trailing: records.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => showExportSheet(
                        context,
                        records: sorted,
                        judul: 'Laporan Pekanan - Pekan $weekIndex $bulanLabel',
                        periode: 'Pekan $weekIndex $bulanLabel'
                            '${fixedTanggalLabel != null ? ' (terakhir diisi $fixedTanggalLabel)' : ''}',
                        includeTanggal: true,
                        fixedTanggalLabel: fixedTanggalLabel,
                      ),
                      icon: const Icon(Icons.ios_share_rounded),
                      tooltip: 'Export Laporan Pekanan',
                    ),
            ),
            if (records.isEmpty)
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
                    '${sorted.length} laporan'
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
                sliver: SliverToBoxAdapter(
                  child: ExportStyleRecordsTable(records: sorted, fixedTanggalLabel: fixedTanggalLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
