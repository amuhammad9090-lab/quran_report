import 'package:flutter/material.dart';

import '../../data/models/santri_record.dart';
import '../../data/services/export_service.dart';

/// Tabel [DataTable] dengan kolom & isi PERSIS sama seperti tabel yang
/// dihasilkan [ExportService] (No, Hari/Tanggal, Nama Murid, Capaian
/// Tahsin/Tahfizh, Ayat/Hal, Baris, Keterangan, Catatan) — cuma beda
/// bentuk (widget di layar, bukan file PDF/Word/Excel) dan TANPA tombol
/// export apapun. Dipakai di Rekap Harian (per hari, per Kelas+Halaqoh)
/// & preview Generate Laporan Pekanan.
///
/// Isi tiap sel diambil dari method publik [ExportService] yang sama
/// dipakai proses export sungguhan, biar tidak ada logic yang
/// diduplikasi/berisiko beda hasil.
class ExportStyleRecordsTable extends StatelessWidget {
  final List<SantriRecord> records;

  /// Kalau diisi, kolom "Hari/Tanggal" di SEMUA baris pakai label ini
  /// (bukan tanggal masing-masing record) — dipakai preview Generate
  /// Laporan Pekanan supaya tampilan di layar sama persis dengan hasil
  /// export-nya (lihat ExportService._rowsWithTanggal).
  final String? fixedTanggalLabel;

  const ExportStyleRecordsTable({super.key, required this.records, this.fixedTanggalLabel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final export = ExportService.instance;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(cs.primaryContainer.withValues(alpha: 0.5)),
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('No', style: TextStyle(fontWeight: FontWeight.w800))),
            DataColumn(label: Text('Hari/Tanggal', style: TextStyle(fontWeight: FontWeight.w800))),
            DataColumn(label: Text('Nama Murid', style: TextStyle(fontWeight: FontWeight.w800))),
            DataColumn(label: Text('Capaian Tahsin/Tahfizh', style: TextStyle(fontWeight: FontWeight.w800))),
            DataColumn(label: Text('Ayat/Hal', style: TextStyle(fontWeight: FontWeight.w800))),
            DataColumn(label: Text('Baris', style: TextStyle(fontWeight: FontWeight.w800))),
            DataColumn(label: Text('Keterangan', style: TextStyle(fontWeight: FontWeight.w800))),
            DataColumn(label: Text('Catatan', style: TextStyle(fontWeight: FontWeight.w800))),
          ],
          rows: [
            for (var i = 0; i < records.length; i++)
              DataRow(
                cells: [
                  DataCell(Text('${i + 1}')),
                  DataCell(Text(fixedTanggalLabel ?? export.hariTanggalTextFor(records[i].tanggal))),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        records[i].namaAnak,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(export.capaianLabelFor(records[i]), overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  DataCell(Text(export.ayatHalRangeFor(records[i]))),
                  DataCell(Text(export.barisTextFor(records[i]))),
                  DataCell(Text(records[i].keterangan.label)),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(export.catatanTextFor(records[i]), overflow: TextOverflow.ellipsis),
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
