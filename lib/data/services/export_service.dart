import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/utils/docx_builder.dart';
import '../models/enums.dart';
import '../models/santri_monthly_recap.dart';
import '../models/santri_record.dart';
import 'platform_file/exported_file.dart';
import 'platform_file/file_actions.dart';

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
    'Catatan',
  ];

  // Dipakai saat [includeTanggal] true (export rekap per Kelas+Halaqoh
  // yang bisa mencakup lebih dari 1 hari) — lihat KelasHalaqohGroupCard.
  // Hari & Tanggal SENGAJA digabung jadi 1 kolom ("Senin, 17 Agu 2026")
  // biar tabelnya nggak kelewat lebar — 2 kolom terpisah buat info yang
  // sebenarnya cuma 1 potong data itu boros tempat.
  static const _headersWithTanggal = [
    'No',
    'Hari/Tanggal',
    'Nama Murid',
    'Capaian Tahsin/Tahfizh',
    'Ayat/Hal',
    'Baris',
    'Keterangan',
    'Catatan',
  ];

  /// Teks ringkas bagian Tahsin saja (WAFA atau Tilawah)
  String _tahfizhSurahNames(SantriRecord r) {
    final segs = r.tahfizhSegmentsEffective;
    return segs.isEmpty ? '-' : segs.map((s) => s.surahName).join(', ');
  }

  String _tahfizhAyatRanges(SantriRecord r) {
    final segs = r.tahfizhSegmentsEffective;
    return segs.isEmpty ? '-' : segs.map((s) => '${s.ayatMulai}-${s.ayatSelesai}').join(' + ');
  }

  String _tahsinPartLabel(SantriRecord r) {
    final mode = r.tahsinMode ?? TahsinMode.wafa;
    if (mode == TahsinMode.tilawah) {
      final segs = r.tilawahSegmentsEffective;
      return segs.isEmpty
          ? 'Tilawah'
          : 'Tilawah - ${segs.map((s) => s.surahName).join(', ')}';
    }
    return r.wafaLevel?.label ?? '-';
  }

  String _tahsinPartRange(SantriRecord r) {
    final mode = r.tahsinMode ?? TahsinMode.wafa;
    if (mode == TahsinMode.tilawah) {
      final segs = r.tilawahSegmentsEffective;
      return segs.isEmpty
          ? '-'
          : segs.map((s) => '${s.ayatMulai}-${s.ayatSelesai}').join(' + ');
    }
    final hal = r.halamanWafa?.trim();
    return (hal == null || hal.isEmpty) ? '-' : hal;
  }

  String _capaianLabel(SantriRecord r) {
    switch (r.status) {
      case HafalanStatus.tahfizh:
        return '${r.status.label} - ${_tahfizhSurahNames(r)}';
      case HafalanStatus.tahsin:
        return '${r.status.label} - ${_tahsinPartLabel(r)}';
      case HafalanStatus.tahsinTahfizh:
        return '${r.status.label} - ${_tahsinPartLabel(r)} & ${_tahfizhSurahNames(r)}';
      case HafalanStatus.murojaahTasmi:
        final segs = r.tilawahSegmentsEffective;
        return segs.isEmpty
            ? r.status.label
            : '${r.status.label} - ${segs.map((s) => s.surahName).join(', ')}';
    }
  }

  // Cuma rentang angkanya (ayat X-Y, atau halaman WAFA-nya) — nama surah
  // sudah ikut di kolom "Capaian Tahsin/Tahfizh".
  String _ayatHalRange(SantriRecord r) {
    switch (r.status) {
      case HafalanStatus.tahfizh:
        return _tahfizhAyatRanges(r);
      case HafalanStatus.tahsin:
        return _tahsinPartRange(r);
      case HafalanStatus.tahsinTahfizh:
        return '${_tahsinPartRange(r)} + ${_tahfizhAyatRanges(r)}';
      case HafalanStatus.murojaahTasmi:
        final segs = r.tilawahSegmentsEffective;
        return segs.isEmpty
            ? '-'
            : segs.map((s) => '${s.ayatMulai}-${s.ayatSelesai}').join(' + ');
    }
  }

  // Baris cuma dihitung buat status yang punya bagian hafalan baru
  // (Tahfizh, atau bagian Tahfizh di Tahsin+Tahfizh) — hasil generate.
  String _barisText(SantriRecord r) =>
      (r.status == HafalanStatus.tahfizh || r.status == HafalanStatus.tahsinTahfizh)
          ? '${r.totalBaris ?? 0}'
          : '-';

  // Hari+tanggal digabung 1 kolom, mis. "Senin, 17 Agu 2026".
  String _hariTanggalText(DateTime d) =>
      '${DateFormat('EEEE', 'id_ID').format(d)}, ${DateFormat('d MMM yyyy', 'id_ID').format(d)}';

  // Catatan bebas dari form Buat Laporan — sama persis field yang diisi
  // guru pembimbing di sana (SantriRecord.catatan), bukan kolom baru
  // yang beda sumber.
  String _catatanText(SantriRecord r) {
    final c = r.catatan?.trim();
    return (c == null || c.isEmpty) ? '-' : c;
  }

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
        _catatanText(r),
      ]);
    }
    return rows;
  }

  /// Versi [_rows] dengan kolom Hari/Tanggal gabungan
  List<List<String>> _rowsWithTanggal(List<SantriRecord> records) {
    final rows = <List<String>>[];
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      rows.add([
        '${i + 1}',
        _hariTanggalText(r.tanggal),
        r.namaAnak,
        _capaianLabel(r),
        _ayatHalRange(r),
        _barisText(r),
        r.keterangan.label,
        _catatanText(r),
      ]);
    }
    return rows;
  }

  /// Ringkasan "Nx <jenis>" per santri untuk semua Keterangan SELAIN Hadir
  /// (Izin Sakit, Izin Lomba, Izin Pelatihan, Alpa)
  List<MapEntry<String, String>> _keteranganSummaryPerSantri(List<SantriRecord> records) {
    final byName = <String, Map<Keterangan, int>>{};
    for (final r in records) {
      if (r.keterangan == Keterangan.hadir) continue;
      final name = r.namaAnak.trim();
      if (name.isEmpty) continue;
      final counts = byName.putIfAbsent(name, () => {});
      counts[r.keterangan] = (counts[r.keterangan] ?? 0) + 1;
    }
    final names = byName.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      for (final name in names)
        MapEntry(
          name,
          (byName[name]!.entries.toList()..sort((a, b) => a.key.index.compareTo(b.key.index)))
              .map((e) => '${e.value}x ${e.key.shortLabel}')
              .join(', '),
        ),
    ];
  }

  Future<ExportedFile> _saveBytes(String filename, List<int> bytes) =>
      persistExportedFile(filename, bytes);

  // -------------------- PDF (A4 potrait) --------------------
  Future<ExportedFile> exportPdf(
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
      0: pw.FixedColumnWidth(20),  // No
      1: pw.FlexColumnWidth(2.0),  // Hari/Tanggal (gabungan)
      2: pw.FlexColumnWidth(1.7),  // Nama
      3: pw.FlexColumnWidth(2.1),  // Capaian
      4: pw.FlexColumnWidth(1.2),  // Ayat/Hal
      5: pw.FlexColumnWidth(0.7),  // Baris
      6: pw.FlexColumnWidth(1.2),  // Keterangan
      7: pw.FlexColumnWidth(1.6),  // Catatan
    }
        : const {
      0: pw.FixedColumnWidth(26),  // No
      1: pw.FlexColumnWidth(2.0),  // Nama
      2: pw.FlexColumnWidth(2.0),  // Capaian
      3: pw.FlexColumnWidth(1.1),  // Ayat/Hal
      4: pw.FlexColumnWidth(0.8),  // Baris
      5: pw.FlexColumnWidth(1.4),  // Keterangan
      6: pw.FlexColumnWidth(1.8),  // Catatan
    };
    final cellAlignments = includeTanggal
        ? const {0: pw.Alignment.center, 5: pw.Alignment.center}
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
          if (_keteranganSummaryPerSantri(records).isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Rekap Keterangan (Izin/Sakit/Alpa)',
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 3),
            for (final e in _keteranganSummaryPerSantri(records))
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 2),
                child: pw.Text('- ${e.key}: ${e.value}', style: const pw.TextStyle(fontSize: 8.5)),
              ),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    return _saveBytes('${_slug(judul)}.pdf', bytes);
  }

  // -------------------- EXCEL --------------------
  Future<ExportedFile> exportExcel(
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
      sheet.setColumnWidth(0, 5);   // No
      sheet.setColumnWidth(1, 20);  // Hari/Tanggal (gabungan)
      sheet.setColumnWidth(2, 20);  // Nama
      sheet.setColumnWidth(3, 24);  // Capaian
      sheet.setColumnWidth(4, 12);  // Ayat/Hal
      sheet.setColumnWidth(5, 8);   // Baris
      sheet.setColumnWidth(6, 18);  // Keterangan
      sheet.setColumnWidth(7, 22);  // Catatan
    } else {
      sheet.setColumnWidth(0, 5);   // No
      sheet.setColumnWidth(1, 22);  // Nama
      sheet.setColumnWidth(2, 24);  // Capaian
      sheet.setColumnWidth(3, 12);  // Ayat/Hal
      sheet.setColumnWidth(4, 8);   // Baris
      sheet.setColumnWidth(5, 18);  // Keterangan
      sheet.setColumnWidth(6, 22);  // Catatan
    }

    row += rows.length;

    final keteranganSummary = _keteranganSummaryPerSantri(records);
    if (keteranganSummary.isNotEmpty) {
      row++; // spasi
      writeMerged('Rekap Keterangan (Izin/Sakit/Alpa)', xls.CellStyle(bold: true, fontSize: 11));
      for (final e in keteranganSummary) {
        writeMerged('- ${e.key}: ${e.value}', labelStyle);
      }
    }

    final bytes = book.encode()!;
    return _saveBytes('${_slug(judul)}.xlsx', Uint8List.fromList(bytes));
  }

  // -------------------- WORD (.docx, A4 potrait — bawaan builder) --------------------
  Future<ExportedFile> exportWord(
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

    final keteranganSummary = _keteranganSummaryPerSantri(records);
    if (keteranganSummary.isNotEmpty) {
      builder.addSpacer();
      builder.addParagraph('Rekap Keterangan (Izin/Sakit/Alpa)', bold: true);
      for (final e in keteranganSummary) {
        builder.addParagraph('- ${e.key}: ${e.value}');
      }
    }

    final bytes = builder.build();
    return _saveBytes('${_slug(judul)}.docx', bytes);
  }

  // -------------------- REKAP BULANAN PER SANTRI (fitur Generate) --------------------
  // Beda dari exportPdf/exportExcel/exportWord di atas (yang 1 baris = 1
  // laporan) — di sini 1 baris = 1 SANTRI, dengan kolom Pekan 1..N
  // menampilkan ringkasan capaiannya tiap pekan (lihat
  // SantriMonthlyRecap.capaianForWeek). Dipakai tombol Generate + tombol
  // export pojok kanan atas di layar Rekap Bulanan.
  List<String> _monthlyHeaders(int totalWeeks) => [
    'No',
    'Nama Murid',
    'Kelas/Halaqoh',
    for (var w = 1; w <= totalWeeks; w++) 'Pekan $w',
    'Total Baris',
    'Keterangan',
  ];

  List<List<String>> _monthlyRows(List<SantriMonthlyRecap> recaps, int totalWeeks) {
    final rows = <List<String>>[];
    for (var i = 0; i < recaps.length; i++) {
      final r = recaps[i];
      rows.add([
        '${i + 1}',
        r.nama,
        '${r.kelas}/${r.halaqoh}',
        for (var w = 1; w <= totalWeeks; w++) r.capaianForWeek(w),
        '${r.totalBaris}',
        r.keteranganSummaryText,
      ]);
    }
    return rows;
  }

  Future<ExportedFile> exportMonthlyRecapPdf(
      List<SantriMonthlyRecap> recaps, {
        required String judul,
        required int totalWeeks,
        String? periode,
      }) async {
    final doc = pw.Document();
    final headers = _monthlyHeaders(totalWeeks);
    final rows = _monthlyRows(recaps, totalWeeks);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(_judulLaporan,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 2),
            pw.Text(_namaSekolah,
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center),
            if (periode != null && periode.trim().isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(periode,
                  style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center),
            ],
            pw.SizedBox(height: 10),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0E7C61)),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            cellHeight: 22,
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: const {0: pw.Alignment.center},
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Total santri: ${recaps.length}',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );

    final bytes = await doc.save();
    return _saveBytes('${_slug(judul)}.pdf', bytes);
  }

  Future<ExportedFile> exportMonthlyRecapExcel(
      List<SantriMonthlyRecap> recaps, {
        required String judul,
        required int totalWeeks,
        String? periode,
      }) async {
    final book = xls.Excel.createExcel();
    const sheetName = 'Rekap Bulanan';
    book.rename('Sheet1', sheetName);
    final sheet = book[sheetName];

    final headers = _monthlyHeaders(totalWeeks);
    final titleStyle = xls.CellStyle(bold: true, fontSize: 14);
    final subtitleStyle = xls.CellStyle(fontSize: 11, italic: true);

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
    if (periode != null && periode.trim().isNotEmpty) writeMerged(periode, subtitleStyle);
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

    final rows = _monthlyRows(recaps, totalWeeks);
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row + r));
        cell.value = xls.TextCellValue(rows[r][c]);
      }
    }

    sheet.setColumnWidth(0, 5);
    sheet.setColumnWidth(1, 22);
    sheet.setColumnWidth(2, 16);
    for (var w = 0; w < totalWeeks; w++) {
      sheet.setColumnWidth(3 + w, 26);
    }
    sheet.setColumnWidth(3 + totalWeeks, 12);
    sheet.setColumnWidth(4 + totalWeeks, 20);

    final bytes = book.encode()!;
    return _saveBytes('${_slug(judul)}.xlsx', Uint8List.fromList(bytes));
  }

  Future<ExportedFile> exportMonthlyRecapWord(
      List<SantriMonthlyRecap> recaps, {
        required String judul,
        required int totalWeeks,
        String? periode,
      }) async {
    final builder = DocxBuilder();
    builder.addTitle(_judulLaporan);
    builder.addSubtitle(_namaSekolah);
    if (periode != null && periode.trim().isNotEmpty) builder.addSubtitle(periode);
    builder.addSpacer();
    builder.addTable(_monthlyHeaders(totalWeeks), _monthlyRows(recaps, totalWeeks));
    builder.addSpacer();
    builder.addParagraph('Total santri: ${recaps.length}', bold: true);

    final bytes = builder.build();
    return _saveBytes('${_slug(judul)}.docx', bytes);
  }

  // -------------------- Buka / Bagikan / Simpan --------------------

  /// Buka file langsung pakai aplikasi bawaan perangkat (PDF viewer, Word,
  /// Excel, dst) — dipanggil otomatis begitu file selesai dibuat. Di Web,
  /// ini otomatis jadi trigger download (lihat file_actions_web.dart).
  Future<void> openFile(ExportedFile file) => openExportedFile(file);

  Future<void> shareFile(ExportedFile file, {String? subject}) =>
      shareExportedFile(file, subject: subject);

  /// Simpan salinan file ke penyimpanan perangkat (folder Download publik
  /// di Android / lokasi yang dipilih user di iOS / trigger download
  /// browser di Web).
  Future<void> saveToDevice(ExportedFile file, {required String filename, required String ext}) =>
      saveExportedFileToDevice(file, filename: filename, ext: ext);

  Future<void> printPdfDirectly(List<SantriRecord> records, {required String judul}) async {
    final file = await exportPdf(records, judul: judul);
    await Printing.layoutPdf(onLayout: (_) async => file.bytes);
  }

  String _slug(String s) {
    final base = s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return '${base}_$ts';
  }
}