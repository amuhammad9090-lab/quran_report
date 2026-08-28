import 'package:flutter/material.dart';

import '../../data/models/santri_record.dart';
import '../../data/services/export_service.dart';

/// Tabel preview "Generate Laporan Pekanan" versi gabungan PER SANTRI —
/// beda dari [ExportStyleRecordsTable] (1 baris = 1 laporan, dipakai
/// Rekap Harian), di sini 1 baris = 1 SANTRI: semua laporannya dalam
/// pekan itu dihimpun jadi 1 baris — kolom Capaian dipecah per jenis
/// (Tahsin/Tahfizh/Tahsin+Tahfizh/Muroja'ah, masing2 cuma tampil kalau
/// memang ada laporan jenis itu tertulis di laporan hariannya), dan
/// kolom Baris di-SUM dari SEMUA laporan santri itu sepekan.
///
/// Isinya diambil dari [ExportService.weeklyRowsGroupedBySantriFor] —
/// sumber logic yang SAMA dipakai proses export sungguhan
/// (exportGroupedPdf/Excel/Word), biar tampilan preview & hasil export
/// identik (pola yang sama seperti [ExportStyleRecordsTable]).
class WeeklySantriRecapTable extends StatelessWidget {
  final List<SantriRecord> records;

  /// Kalau diisi, kolom "Hari/Tanggal" di SEMUA baris pakai label ini
  /// (bukan tanggal laporan terakhir masing-masing santri) — dipakai
  /// Generate Laporan Pekanan supaya tampilan di layar sama persis
  /// dengan hasil export-nya.
  final String? fixedTanggalLabel;

  const WeeklySantriRecapTable({super.key, required this.records, this.fixedTanggalLabel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = ExportService.instance
        .weeklyRowsGroupedBySantriFor(records, fixedTanggalLabel: fixedTanggalLabel);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(cs.primaryContainer.withValues(alpha: 0.5)),
          columnSpacing: 20,
          dataRowMinHeight: 48,
          // Sebelumnya 320 — bikin baris jadi raksasa kalau kolom Capaian
          // punya banyak baris teks (Tahsin/Tahfizh digabung dengan '\n').
          // Sekarang di-cap kecil; kolom yang teksnya panjang (Capaian,
          // Keterangan, Catatan) dibungkus scroll vertical sendiri di
          // bawah, jadi tinggi baris gak lagi ngikutin panjang teks.
          dataRowMaxHeight: 96,
          columns: const [
            DataColumn(label: Text('No', style: TextStyle(fontWeight: FontWeight.w800))),
            DataColumn(label: Text('Hari/Tanggal', style: TextStyle(fontWeight: FontWeight.w800))),
            DataColumn(label: Text('Nama Murid', style: TextStyle(fontWeight: FontWeight.w800))),
            DataColumn(label: Text('Capaian', style: TextStyle(fontWeight: FontWeight.w800))),
            DataColumn(label: Text('Baris', style: TextStyle(fontWeight: FontWeight.w800))),
            DataColumn(label: Text('Keterangan', style: TextStyle(fontWeight: FontWeight.w800))),
            DataColumn(label: Text('Catatan', style: TextStyle(fontWeight: FontWeight.w800))),
          ],
          rows: [
            for (var i = 0; i < rows.length; i++)
              DataRow(
                cells: [
                  DataCell(Text('${i + 1}')),
                  DataCell(Text(rows[i].tanggalLabel)),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        rows[i].namaAnak,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260, maxHeight: 80),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(rows[i].capaian),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${rows[i].totalBaris}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160, maxHeight: 80),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(rows[i].keterangan),
                      ),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160, maxHeight: 80),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(rows[i].catatan),
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