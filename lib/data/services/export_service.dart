import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/docx_builder.dart';
import '../models/enums.dart';
import '../models/santri_record.dart';

class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  static const _headers = [
    'Tanggal',
    'Kelas',
    'Halaqoh',
    'Nama Anak',
    'Status',
    'Capaian',
    'Baris',
    'Keterangan',
  ];

  List<List<String>> _rows(List<SantriRecord> records) {
    final df = DateFormat('d/MM/yyyy');
    return records
        .map((r) => [
              df.format(r.tanggal),
              r.kelas,
              r.halaqoh,
              r.namaAnak,
              r.status.label,
              r.capaianText,
              r.status == HafalanStatus.tahfizh ? '${r.totalBaris ?? 0}' : '-',
              r.keterangan.label,
            ])
        .toList();
  }

  Future<File> _saveBytes(String filename, List<int> bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  // -------------------- PDF --------------------
  Future<File> exportPdf(List<SantriRecord> records, {required String judul}) async {
    final doc = pw.Document();
    final rows = _rows(records);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              judul,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Dicetak: ${DateFormat('d MMMM yyyy, HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 12),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: _headers,
            data: rows,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 9,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0E7C61)),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellHeight: 24,
            cellAlignment: pw.Alignment.centerLeft,
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Total data: ${records.length}',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    return _saveBytes('${_slug(judul)}.pdf', bytes);
  }

  // -------------------- EXCEL --------------------
  Future<File> exportExcel(List<SantriRecord> records, {required String judul}) async {
    final book = xls.Excel.createExcel();
    const sheetName = 'Laporan';
    book.rename('Sheet1', sheetName);
    final sheet = book[sheetName];

    final headerStyle = xls.CellStyle(
      bold: true,
      fontColorHex: xls.ExcelColor.white,
      backgroundColorHex: xls.ExcelColor.fromHexString('#0E7C61'),
    );

    for (var c = 0; c < _headers.length; c++) {
      final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
      cell.value = xls.TextCellValue(_headers[c]);
      cell.cellStyle = headerStyle;
    }

    final rows = _rows(records);
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        final cell = sheet.cell(
          xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1),
        );
        cell.value = xls.TextCellValue(rows[r][c]);
      }
    }

    for (var c = 0; c < _headers.length; c++) {
      sheet.setColumnWidth(c, 18);
    }

    final bytes = book.encode()!;
    return _saveBytes('${_slug(judul)}.xlsx', Uint8List.fromList(bytes));
  }

  // -------------------- WORD (.docx) --------------------
  Future<File> exportWord(List<SantriRecord> records, {required String judul}) async {
    final builder = DocxBuilder();
    builder.addTitle(judul);
    builder.addSubtitle('Dicetak: ${DateFormat('d MMMM yyyy, HH:mm').format(DateTime.now())}');
    builder.addSpacer();
    builder.addTable(_headers, _rows(records));
    builder.addSpacer();
    builder.addParagraph('Total data: ${records.length}', bold: true);

    final bytes = builder.build();
    return _saveBytes('${_slug(judul)}.docx', bytes);
  }

  // -------------------- Share / Print helpers --------------------
  Future<void> shareFile(File file, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: subject,
      ),
    );
  }

  Future<void> printPdfDirectly(List<SantriRecord> records, {required String judul}) async {
    final file = await exportPdf(records, judul: judul);
    await Printing.layoutPdf(onLayout: (_) => file.readAsBytes());
  }

  String _slug(String s) {
    final base = s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return '${base}_$ts';
  }
}
