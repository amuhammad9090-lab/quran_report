import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
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

  // Kop laporan resmi — tetap sama di semua format & konteks ekspor
  // (laporan biasa, per-folder, maupun rekap bulanan).
  static const _judulLaporan = 'Laporan Pekanan Al Quran';
  static const _namaSekolah = 'SMPIT Al Madinah Tanjungpinang';

  static const _headers = [
    'No',
    'Nama Murid',
    'Capaian Tahsin/Tahfizh',
    'Ayat/Hal',
    'Baris',
    'Keterangan',
  ];

  // Dipakai saat [includeTanggal] true (export rekap per Kelas+Halaqoh
  // yang bisa mencakup lebih dari 1 hari) — lihat KelasHalaqohGroupCard.
  static const _headersWithTanggal = [
    'No',
    'Hari',
    'Tanggal',
    'Nama Murid',
    'Capaian Tahsin/Tahfizh',
    'Ayat/Hal',
    'Baris',
    'Keterangan',
  ];

  /// Teks ringkas bagian Tahsin saja (WAFA atau Tilawah) — dipakai untuk
  /// kolom "Capaian" (nama surah/jenjang) & "Ayat/Hal" (rentang angka),
  /// masing-masing lewat method terpisah di bawah supaya kolomnya tetap
  /// konsisten dengan versi sebelum ada status Tahsin+Tahfizh/Muroja'ah.
  String _tahsinPartLabel(SantriRecord r) {
    final mode = r.tahsinMode ?? TahsinMode.wafa;
    if (mode == TahsinMode.tilawah) {
      return 'Tilawah${r.tilawahSurahName != null ? ' - ${r.tilawahSurahName}' : ''}';
    }
    return r.wafaLevel?.label ?? '-';
  }

  String _tahsinPartRange(SantriRecord r) {
    final mode = r.tahsinMode ?? TahsinMode.wafa;
    if (mode == TahsinMode.tilawah) {
      if (r.tilawahAyatMulai == null || r.tilawahAyatSelesai == null) return '-';
      return '${r.tilawahAyatMulai}-${r.tilawahAyatSelesai}';
    }
    final hal = r.halamanWafa?.trim();
    return (hal == null || hal.isEmpty) ? '-' : hal;
  }

  String _capaianLabel(SantriRecord r) {
    switch (r.status) {
      case HafalanStatus.tahfizh:
        return r.surahName != null ? '${r.status.label} - ${r.surahName}' : r.status.label;
      case HafalanStatus.tahsin:
        return '${r.status.label} - ${_tahsinPartLabel(r)}';
      case HafalanStatus.tahsinTahfizh:
        final tahfizhPart = r.surahName ?? '-';
        return '${r.status.label} - ${_tahsinPartLabel(r)} & $tahfizhPart';
      case HafalanStatus.murojaahTasmi:
        return r.tilawahSurahName != null
            ? '${r.status.label} - ${r.tilawahSurahName}'
            : r.status.label;
    }
  }

  // Cuma rentang angkanya (ayat X-Y, atau halaman WAFA-nya) — nama surah
  // sudah ikut di kolom "Capaian Tahsin/Tahfizh".
  String _ayatHalRange(SantriRecord r) {
    switch (r.status) {
      case HafalanStatus.tahfizh:
        if (r.ayatMulai == null || r.ayatSelesai == null) return '-';
        return '${r.ayatMulai}-${r.ayatSelesai}';
      case HafalanStatus.tahsin:
        return _tahsinPartRange(r);
      case HafalanStatus.tahsinTahfizh:
        final tahfizhRange = (r.ayatMulai != null && r.ayatSelesai != null)
            ? '${r.ayatMulai}-${r.ayatSelesai}'
            : '-';
        return '${_tahsinPartRange(r)} + $tahfizhRange';
      case HafalanStatus.murojaahTasmi:
        if (r.tilawahAyatMulai == null || r.tilawahAyatSelesai == null) return '-';
        return '${r.tilawahAyatMulai}-${r.tilawahAyatSelesai}';
    }
  }

  // Baris cuma dihitung buat status yang punya bagian hafalan baru
  // (Tahfizh, atau bagian Tahfizh di Tahsin+Tahfizh) — hasil generate.
  // Tilawah/Muroja'ah/Tasmi' tidak melalui proses hitung baris sama
  // sekali, jadi selalu '-'.
  String _barisText(SantriRecord r) =>
      (r.status == HafalanStatus.tahfizh || r.status == HafalanStatus.tahsinTahfizh)
          ? '${r.totalBaris ?? 0}'
          : '-';

  String _uniqueJoin(Iterable<String> values) {
    final set = values.map((v) => v.trim()).where((v) => v.isNotEmpty).toSet().toList()..sort();
    return set.join(', ');
  }

  List<List<String>> _rows(List<SantriRecord> records) {
    final rows = <List<String>>[];
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      rows.add([
        '${i + 1}',
        r.namaAnak,
        _capaianLabel(r),
        _ayatHalRange(r),
        _barisText(r),
        r.keterangan.label,
      ]);
    }
    return rows;
  }

  /// Versi [_rows] dengan kolom Hari & Tanggal — dipakai saat
  /// [includeTanggal] true (rekap yang mencakup >1 hari, mis. export per
  /// Kelas+Halaqoh pekanan/bulanan).
  List<List<String>> _rowsWithTanggal(List<SantriRecord> records) {
    final rows = <List<String>>[];
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      rows.add([
        '${i + 1}',
        DateFormat('EEEE', 'id_ID').format(r.tanggal),
        DateFormat('d MMM yyyy', 'id_ID').format(r.tanggal),
        r.namaAnak,
        _capaianLabel(r),
        _ayatHalRange(r),
        _barisText(r),
        r.keterangan.label,
      ]);
    }
    return rows;
  }

  Future<File> _saveBytes(String filename, List<int> bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  // -------------------- PDF (A4 potrait) --------------------
  Future<File> exportPdf(
    List<SantriRecord> records, {
    required String judul,
    String? kelas,
    String? halaqoh,
    String? periode,
    String? guruPembimbing,
    bool includeTanggal = false,
  }) async {
    final doc = pw.Document();
    final headers = includeTanggal ? _headersWithTanggal : _headers;
    final rows = includeTanggal ? _rowsWithTanggal(records) : _rows(records);
    final kelasValue = kelas ?? _uniqueJoin(records.map((r) => r.kelas));
    final halaqohValue = halaqoh ?? _uniqueJoin(records.map((r) => r.halaqoh));
    final columnWidths = includeTanggal
        ? const {
            0: pw.FixedColumnWidth(20),
            1: pw.FlexColumnWidth(1.3),
            2: pw.FlexColumnWidth(1.3),
            3: pw.FlexColumnWidth(1.9),
            4: pw.FlexColumnWidth(2.3),
            5: pw.FlexColumnWidth(1.3),
            6: pw.FlexColumnWidth(0.8),
            7: pw.FlexColumnWidth(1.4),
          }
        : const {
            0: pw.FixedColumnWidth(26),
            1: pw.FlexColumnWidth(2.3),
            2: pw.FlexColumnWidth(2.3),
            3: pw.FlexColumnWidth(1.3),
            4: pw.FlexColumnWidth(0.9),
            5: pw.FlexColumnWidth(1.7),
          };
    final cellAlignments = includeTanggal
        ? const {0: pw.Alignment.center, 6: pw.Alignment.center}
        : const {0: pw.Alignment.center, 4: pw.Alignment.center};

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4, // potrait (default) — bukan .landscape
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              _judulLaporan,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              _namaSekolah,
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
            ),
            if (periode != null && periode.trim().isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                periode,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                textAlign: pw.TextAlign.center,
              ),
            ],
            pw.SizedBox(height: 14),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text('Kelas   : ${kelasValue.isEmpty ? '-' : kelasValue}',
                  style: const pw.TextStyle(fontSize: 10)),
            ),
            pw.SizedBox(height: 2),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text('Halaqoh : ${halaqohValue.isEmpty ? '-' : halaqohValue}',
                  style: const pw.TextStyle(fontSize: 10)),
            ),
            if (guruPembimbing != null && guruPembimbing.trim().isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Guru Pembimbing : $guruPembimbing',
                    style: const pw.TextStyle(fontSize: 10)),
              ),
            ],
            pw.SizedBox(height: 12),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: headers,
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
            columnWidths: columnWidths,
            cellAlignments: cellAlignments,
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
  Future<File> exportExcel(
    List<SantriRecord> records, {
    required String judul,
    String? kelas,
    String? halaqoh,
    String? periode,
    String? guruPembimbing,
    bool includeTanggal = false,
  }) async {
    final book = xls.Excel.createExcel();
    const sheetName = 'Laporan';
    book.rename('Sheet1', sheetName);
    final sheet = book[sheetName];

    final headers = includeTanggal ? _headersWithTanggal : _headers;
    final kelasValue = kelas ?? _uniqueJoin(records.map((r) => r.kelas));
    final halaqohValue = halaqoh ?? _uniqueJoin(records.map((r) => r.halaqoh));

    final titleStyle = xls.CellStyle(bold: true, fontSize: 14);
    final subtitleStyle = xls.CellStyle(fontSize: 11, italic: true);
    final labelStyle = xls.CellStyle(fontSize: 10);

    var row = 0;
    void writeMerged(String text, xls.CellStyle style) {
      final start = xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row);
      final end = xls.CellIndex.indexByColumnRow(columnIndex: headers.length - 1, rowIndex: row);
      sheet.merge(start, end);
      final cell = sheet.cell(start);
      cell.value = xls.TextCellValue(text);
      cell.cellStyle = style;
      row++;
    }

    writeMerged(_judulLaporan, titleStyle);
    writeMerged(_namaSekolah, subtitleStyle);
    if (periode != null && periode.trim().isNotEmpty) writeMerged(periode, labelStyle);
    row++; // spasi
    writeMerged('Kelas   : ${kelasValue.isEmpty ? '-' : kelasValue}', labelStyle);
    writeMerged('Halaqoh : ${halaqohValue.isEmpty ? '-' : halaqohValue}', labelStyle);
    if (guruPembimbing != null && guruPembimbing.trim().isNotEmpty) {
      writeMerged('Guru Pembimbing : $guruPembimbing', labelStyle);
    }
    row++; // spasi

    final headerStyle = xls.CellStyle(
      bold: true,
      fontColorHex: xls.ExcelColor.white,
      backgroundColorHex: xls.ExcelColor.fromHexString('#0E7C61'),
    );
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
      cell.value = xls.TextCellValue(headers[c]);
      cell.cellStyle = headerStyle;
    }
    row++;

    final rows = includeTanggal ? _rowsWithTanggal(records) : _rows(records);
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row + r));
        cell.value = xls.TextCellValue(rows[r][c]);
      }
    }

    if (includeTanggal) {
      sheet.setColumnWidth(0, 5);
      sheet.setColumnWidth(1, 12);
      sheet.setColumnWidth(2, 12);
      sheet.setColumnWidth(3, 20);
      sheet.setColumnWidth(4, 24);
      sheet.setColumnWidth(5, 12);
      sheet.setColumnWidth(6, 8);
      sheet.setColumnWidth(7, 18);
    } else {
      sheet.setColumnWidth(0, 5);
      sheet.setColumnWidth(1, 22);
      sheet.setColumnWidth(2, 24);
      sheet.setColumnWidth(3, 12);
      sheet.setColumnWidth(4, 8);
      sheet.setColumnWidth(5, 18);
    }

    final bytes = book.encode()!;
    return _saveBytes('${_slug(judul)}.xlsx', Uint8List.fromList(bytes));
  }

  // -------------------- WORD (.docx, A4 potrait — bawaan builder) --------------------
  Future<File> exportWord(
    List<SantriRecord> records, {
    required String judul,
    String? kelas,
    String? halaqoh,
    String? periode,
    String? guruPembimbing,
    bool includeTanggal = false,
  }) async {
    final builder = DocxBuilder();
    final headers = includeTanggal ? _headersWithTanggal : _headers;
    final kelasValue = kelas ?? _uniqueJoin(records.map((r) => r.kelas));
    final halaqohValue = halaqoh ?? _uniqueJoin(records.map((r) => r.halaqoh));

    builder.addTitle(_judulLaporan);
    builder.addSubtitle(_namaSekolah);
    if (periode != null && periode.trim().isNotEmpty) builder.addSubtitle(periode);
    builder.addSpacer();
    builder.addParagraph('Kelas   : ${kelasValue.isEmpty ? '-' : kelasValue}');
    builder.addParagraph('Halaqoh : ${halaqohValue.isEmpty ? '-' : halaqohValue}');
    if (guruPembimbing != null && guruPembimbing.trim().isNotEmpty) {
      builder.addParagraph('Guru Pembimbing : $guruPembimbing');
    }
    builder.addSpacer();
    builder.addTable(headers, includeTanggal ? _rowsWithTanggal(records) : _rows(records));
    builder.addSpacer();
    builder.addParagraph('Total data: ${records.length}', bold: true);

    final bytes = builder.build();
    return _saveBytes('${_slug(judul)}.docx', bytes);
  }

  // -------------------- Buka / Bagikan / Simpan --------------------

  /// Buka file langsung pakai aplikasi bawaan perangkat (PDF viewer, Word,
  /// Excel, dst) — dipanggil otomatis begitu file selesai dibuat.
  Future<void> openFile(File file) async {
    await OpenFilex.open(file.path);
  }

  Future<void> shareFile(File file, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: subject,
      ),
    );
  }

  /// Simpan salinan file ke penyimpanan perangkat (folder Download / lokasi
  /// yang dipilih user), terpisah dari copy internal aplikasi.
  Future<void> saveToDevice(File file, {required String filename, required String ext}) async {
    final bytes = await file.readAsBytes();
    await FileSaver.instance.saveFile(
      name: filename,
      bytes: bytes,
      ext: ext,
      mimeType: _mimeFor(ext),
    );
  }

  MimeType _mimeFor(String ext) => switch (ext) {
        'pdf' => MimeType.pdf,
        'docx' => MimeType.microsoftWord,
        'xlsx' => MimeType.microsoftExcel,
        _ => MimeType.other,
      };

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
