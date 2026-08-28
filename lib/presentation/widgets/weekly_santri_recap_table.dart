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
///
/// Sengaja PAKAI [Table] bukan [DataTable]: [DataTable] maksa SEMUA
/// baris punya tinggi yang sama (dataRowMaxHeight berlaku global), jadi
/// kalau ada 1 santri dengan 3 jenis capaian sekaligus, baris santri lain
/// yang cuma 1 capaian ikut jadi tinggi juga (atau sebaliknya, kepotong).
/// [Table] menghitung tinggi tiap TableRow SENDIRI-SENDIRI berdasarkan
/// konten cell-nya — jadi baris yang capaiannya cuma 1 baris teks tetap
/// pendek/pas ("fit"), dan baris yang capaiannya 2-3 jenis otomatis
/// melebar/lebih tinggi mengikuti isinya, tanpa perlu scroll internal.
class WeeklySantriRecapTable extends StatelessWidget {
  final List<SantriRecord> records;

  /// Kalau diisi, kolom "Hari/Tanggal" di SEMUA baris pakai label ini
  /// (bukan tanggal laporan terakhir masing-masing santri) — dipakai
  /// Generate Laporan Pekanan supaya tampilan di layar sama persis
  /// dengan hasil export-nya.
  final String? fixedTanggalLabel;

  const WeeklySantriRecapTable({super.key, required this.records, this.fixedTanggalLabel});

  // Lebar tiap kolom (No, Hari/Tanggal, Nama Murid, Capaian, Baris,
  // Keterangan, Catatan) — tinggal diubah angkanya kalau mau lebih
  // lebar/sempit. Total = lebar tabel (di dalam horizontal scroll).
  static const _colWidths = <double>[32, 100, 100, 190, 44, 110, 110];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = ExportService.instance
        .weeklyRowsGroupedBySantriFor(records, fixedTanggalLabel: fixedTanggalLabel);
    final totalWidth = _colWidths.reduce((a, b) => a + b);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          child: Table(
            columnWidths: {
              for (var c = 0; c < _colWidths.length; c++) c: FixedColumnWidth(_colWidths[c]),
            },
            border: TableBorder(
              horizontalInside: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.5)),
                children: const [
                  _HeaderCell('No'),
                  _HeaderCell('Hari/Tanggal'),
                  _HeaderCell('Nama Murid'),
                  _HeaderCell('Capaian'),
                  _HeaderCell('Baris'),
                  _HeaderCell('Keterangan'),
                  _HeaderCell('Catatan'),
                ],
              ),
              for (var i = 0; i < rows.length; i++)
                TableRow(
                  children: [
                    _Cell('${i + 1}'),
                    _Cell(rows[i].tanggalLabel),
                    _Cell(rows[i].namaAnak, bold: true),
                    _Cell(rows[i].capaian),
                    _Cell('${rows[i].totalBaris}', bold: true),
                    _Cell(rows[i].keterangan),
                    _Cell(rows[i].catatan),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Padding & fontSize sel header/isi — gampang diutak-atik kalau masih
// mau lebih rapat/renggang.
const _cellPadding = EdgeInsets.symmetric(horizontal: 6, vertical: 8);
const _fontSize = 12.0;

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _cellPadding,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fontSize)),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final bool bold;
  const _Cell(this.text, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _cellPadding,
      child: Text(
        text,
        style: TextStyle(
          fontSize: _fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
        ),
      ),
    );
  }
}
