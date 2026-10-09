import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;

import '../../models/santri_monthly_recap.dart';
import '../../models/santri_record.dart';
import '../platform_file/exported_file.dart';
import '../platform_file/file_actions.dart';
import 'export_rows.dart';

/// Pembuat Excel (.xlsx) untuk laporan biasa, gabungan per Kelas+Halaqoh, dan rekap bulanan.
/// Hanya urusan layout sheet; isi baris dari [ExportRows].
class ExportExcel {
  const ExportExcel();

  static const _r = ExportRows();

  // -------------------- EXCEL --------------------
  Future<ExportedFile> exportExcel(
      List<SantriRecord> records, {
        required String judul,
        String? kelas,
        String? halaqoh,
        String? periode,
        String? guruPembimbing,
        bool includeTanggal = false,
        String? fixedTanggalLabel,
      }) async {
    final book = xls.Excel.createExcel();
    const sheetName = 'Laporan';
    book.rename('Sheet1', sheetName);
    final sheet = book[sheetName];

    final headers = includeTanggal ? ExportRows.headersWithTanggal : ExportRows.headers;
    final kelasValue = kelas ?? _r.joinUnique(records.map((r) => r.kelas));
    final halaqohValue = halaqoh ?? _r.joinUnique(records.map((r) => r.halaqoh));

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

    writeMerged(ExportRows.judulLaporan, titleStyle);
    writeMerged(ExportRows.namaSekolah, subtitleStyle);
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

    final rows = includeTanggal
        ? _r.buildRowsWithTanggal(records, fixedTanggalLabel: fixedTanggalLabel)
        : _r.buildRows(records);
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
      sheet.setColumnWidth(7, 10);  // Nilai
      sheet.setColumnWidth(8, 14);  // Status (ketuntasan)
      sheet.setColumnWidth(9, 22);  // Catatan
    } else {
      sheet.setColumnWidth(0, 5);   // No
      sheet.setColumnWidth(1, 22);  // Nama
      sheet.setColumnWidth(2, 24);  // Capaian
      sheet.setColumnWidth(3, 12);  // Ayat/Hal
      sheet.setColumnWidth(4, 8);   // Baris
      sheet.setColumnWidth(5, 18);  // Keterangan
      sheet.setColumnWidth(6, 10);  // Nilai
      sheet.setColumnWidth(7, 14);  // Status (ketuntasan)
      sheet.setColumnWidth(8, 22);  // Catatan
    }

    row += rows.length;

    final keteranganSummary = _r.keteranganSummaryPerSantri(records);
    if (keteranganSummary.isNotEmpty) {
      row++; // spasi
      writeMerged('Rekap Keterangan (Izin/Sakit/Alpa)', xls.CellStyle(bold: true, fontSize: 11));
      for (final e in keteranganSummary) {
        writeMerged('- ${e.key}: ${e.value}', labelStyle);
      }
    }

    final bytes = book.encode()!;
    return persistExportedFile('${exportFileSlug(judul)}.xlsx', Uint8List.fromList(bytes));
  }

  /// Rekap Kehadiran BULANAN: per Kelas+Halaqoh 1 blok, baris = santri, kolom = tanggal 1..N + total.
  Future<ExportedFile> exportAttendanceMonthlyExcel(
      List<ExportKelasHalaqohSection<SantriRecord>> sections, {
        required DateTime month,
        required String judul,
        String? periode,
      }) async {
    final book = xls.Excel.createExcel();
    const sheetName = 'Kehadiran';
    book.rename('Sheet1', sheetName);
    final sheet = book[sheetName];

    final headers = _r.attendanceMonthHeaders(month);
    final titleStyle = xls.CellStyle(bold: true, fontSize: 14);
    final subtitleStyle = xls.CellStyle(fontSize: 11, italic: true);
    final labelStyle = xls.CellStyle(fontSize: 10);
    final headerStyle = xls.CellStyle(
      bold: true,
      horizontalAlign: xls.HorizontalAlign.Center,
      fontColorHex: xls.ExcelColor.white,
      backgroundColorHex: xls.ExcelColor.fromHexString('#0E7C61'),
    );
    final centerStyle = xls.CellStyle(horizontalAlign: xls.HorizontalAlign.Center);

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

    writeMerged(ExportRows.judulKehadiran, titleStyle);
    writeMerged(ExportRows.namaSekolah, subtitleStyle);
    if (periode != null && periode.trim().isNotEmpty) writeMerged(periode, labelStyle);
    row++; // spasi

    for (final section in sections) {
      writeMerged('Kelas   : ${section.kelas}', labelStyle);
      writeMerged('Halaqoh : ${section.halaqoh}', labelStyle);
      if (section.guruPembimbing != null && section.guruPembimbing!.trim().isNotEmpty) {
        writeMerged('Guru Pembimbing : ${section.guruPembimbing}', labelStyle);
      }
      for (var c = 0; c < headers.length; c++) {
        final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
        cell.value = xls.TextCellValue(headers[c]);
        cell.cellStyle = headerStyle;
      }
      row++;
      final rows = _r.buildAttendanceMonthRows(section.items, month);
      for (var r = 0; r < rows.length; r++) {
        for (var c = 0; c < rows[r].length; c++) {
          // Kotak kosong (tidak ada laporan) dibiarkan benar-benar kosong.
          if (rows[r][c].isEmpty) continue;
          final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row + r));
          cell.value = xls.TextCellValue(rows[r][c]);
          if (c != 1) cell.cellStyle = centerStyle;
        }
      }
      row += rows.length + 1; // +1 spasi antar kelompok
    }

    writeMerged(ExportRows.attendanceLegend, labelStyle);

    sheet.setColumnWidth(0, 5);   // No
    sheet.setColumnWidth(1, 30);  // Nama
    for (var c = 2; c < headers.length; c++) {
      sheet.setColumnWidth(c, 4.5); // tanggal 1..N + total H,S,I,L,P,A
    }

    final bytes = book.encode()!;
    return persistExportedFile('${exportFileSlug(judul)}.xlsx', Uint8List.fromList(bytes));
  }

  Future<ExportedFile> exportGroupedExcel(
      List<ExportKelasHalaqohSection<SantriRecord>> sections, {
        required String judul,
        String? periode,
        bool includeTanggal = false,
        String? fixedTanggalLabel,
      }) async {
    final book = xls.Excel.createExcel();
    const sheetName = 'Laporan';
    book.rename('Sheet1', sheetName);
    final sheet = book[sheetName];

    final headers = includeTanggal ? ExportRows.weeklyHeaders : ExportRows.headers;
    final titleStyle = xls.CellStyle(bold: true, fontSize: 14);
    final subtitleStyle = xls.CellStyle(fontSize: 11, italic: true);
    final labelStyle = xls.CellStyle(fontSize: 10);
    final sectionStyle = xls.CellStyle(fontSize: 12);
    final headerStyle = xls.CellStyle(
      bold: true,
      fontColorHex: xls.ExcelColor.white,
      backgroundColorHex: xls.ExcelColor.fromHexString('#0E7C61'),
    );

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

    writeMerged(ExportRows.judulLaporan, titleStyle);
    writeMerged(ExportRows.namaSekolah, subtitleStyle);
    if (periode != null && periode.trim().isNotEmpty) writeMerged(periode, labelStyle);

    for (final section in sections) {
      row++; // spasi antar grup
      writeMerged('Kelas   : ${section.kelas}', sectionStyle);
      writeMerged('Halaqoh : ${section.halaqoh}', sectionStyle);
      if (section.guruPembimbing != null && section.guruPembimbing!.trim().isNotEmpty) {
        writeMerged('Guru Pembimbing : ${section.guruPembimbing}', sectionStyle);
      }
      for (var c = 0; c < headers.length; c++) {
        final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
        cell.value = xls.TextCellValue(headers[c]);
        cell.cellStyle = headerStyle;
      }
      row++;
      final rows = includeTanggal
          ? _r.buildWeeklyRowsText(section.items, fixedTanggalLabel: fixedTanggalLabel)
          : _r.buildRows(section.items);
      // Kolom "Capaian" (index 3, versi gabungan-per-santri) bisa multi-baris ("\n" per hari setoran,
      // lihat _weeklyCapaianForSantri) — WAJIB textWrapping.WrapText agar "\n" benar-benar ganti baris
      // di Excel, bukan digabung jadi 1 baris panjang.
      final wrapStyle = xls.CellStyle(
        textWrapping: xls.TextWrapping.WrapText,
        verticalAlign: xls.VerticalAlign.Top,
      );
      for (var r = 0; r < rows.length; r++) {
        for (var c = 0; c < rows[r].length; c++) {
          final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row + r));
          cell.value = xls.TextCellValue(rows[r][c]);
          if (includeTanggal && c == 3) cell.cellStyle = wrapStyle;
        }
      }
      row += rows.length;
    }

    if (includeTanggal) {
      // 8 kolom versi gabungan-per-siswa: No, Hari/Tanggal, Nama Murid,
      // Capaian, Baris, Keterangan, Nilai, Status, Catatan (lihat ExportRows.weeklyHeaders).
      sheet.setColumnWidth(0, 5);
      sheet.setColumnWidth(1, 18);
      sheet.setColumnWidth(2, 20);
      sheet.setColumnWidth(3, 40);
      sheet.setColumnWidth(4, 8);
      sheet.setColumnWidth(5, 18);
      sheet.setColumnWidth(6, 12);
      sheet.setColumnWidth(7, 16);
      sheet.setColumnWidth(8, 22);
    } else {
      sheet.setColumnWidth(0, 5);
      sheet.setColumnWidth(1, 22);
      sheet.setColumnWidth(2, 24);
      sheet.setColumnWidth(3, 12);
      sheet.setColumnWidth(4, 8);
      sheet.setColumnWidth(5, 18);
      sheet.setColumnWidth(6, 10);
      sheet.setColumnWidth(7, 14);
      sheet.setColumnWidth(8, 22);
    }

    final allRecords = [for (final s in sections) ...s.items];
    final keteranganSummary = _r.keteranganSummaryPerSantri(allRecords);
    if (keteranganSummary.isNotEmpty) {
      row++;
      writeMerged('Rekap Keterangan (Izin/Sakit/Alpa)', xls.CellStyle(bold: true, fontSize: 11));
      for (final e in keteranganSummary) {
        writeMerged('- ${e.key}: ${e.value}', labelStyle);
      }
    }

    final bytes = book.encode()!;
    return persistExportedFile('${exportFileSlug(judul)}.xlsx', Uint8List.fromList(bytes));
  }

  Future<ExportedFile> exportGroupedMonthlyRecapExcel(
      List<ExportKelasHalaqohSection<SantriMonthlyRecap>> sections, {
        required String judul,
        required int totalWeeks,
        String? periode,
      }) async {
    final book = xls.Excel.createExcel();
    const sheetName = 'Rekap Bulanan';
    book.rename('Sheet1', sheetName);
    final sheet = book[sheetName];

    final headers = _r.monthlyHeaders(totalWeeks);
    final titleStyle = xls.CellStyle(bold: true, fontSize: 14);
    final subtitleStyle = xls.CellStyle(fontSize: 11, italic: true);
    final labelStyle = xls.CellStyle(fontSize: 10);
    final sectionStyle = xls.CellStyle(fontSize: 12);

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

    writeMerged(ExportRows.judulLaporan, titleStyle);
    writeMerged(ExportRows.namaSekolah, subtitleStyle);
    if (periode != null && periode.trim().isNotEmpty) writeMerged(periode, labelStyle);

    final headerStyle = xls.CellStyle(
      bold: true,
      fontColorHex: xls.ExcelColor.white,
      backgroundColorHex: xls.ExcelColor.fromHexString('#0E7C61'),
    );

    for (final section in sections) {
      row++; // spasi antar grup
      writeMerged('Kelas   : ${section.kelas}', sectionStyle);
      writeMerged('Halaqoh : ${section.halaqoh}', sectionStyle);
      if (section.guruPembimbing != null && section.guruPembimbing!.trim().isNotEmpty) {
        writeMerged('Guru Pembimbing : ${section.guruPembimbing}', sectionStyle);
      }
      for (var c = 0; c < headers.length; c++) {
        final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
        cell.value = xls.TextCellValue(headers[c]);
        cell.cellStyle = headerStyle;
      }
      row++;
      final rows = _r.monthlyRows(section.items, totalWeeks);
      // Kolom "Pekan 1..N" (index 2..totalWeeks+1) bisa multi-baris ("\n" per hari setoran, lihat
      // SantriMonthlyRecap.capaianForWeek) — WAJIB textWrapping.WrapText seperti exportGroupedExcel
      // agar "\n" benar-benar ganti baris di Excel.
      final wrapStyle = xls.CellStyle(
        textWrapping: xls.TextWrapping.WrapText,
        verticalAlign: xls.VerticalAlign.Top,
      );
      for (var r = 0; r < rows.length; r++) {
        for (var c = 0; c < rows[r].length; c++) {
          final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row + r));
          cell.value = xls.TextCellValue(rows[r][c]);
          if (c >= 2 && c <= totalWeeks + 1) cell.cellStyle = wrapStyle;
        }
      }
      row += rows.length;
    }

    sheet.setColumnWidth(0, 5);
    sheet.setColumnWidth(1, 22);
    for (var w = 0; w < totalWeeks; w++) {
      sheet.setColumnWidth(2 + w, 26);
    }
    sheet.setColumnWidth(2 + totalWeeks, 12);
    sheet.setColumnWidth(3 + totalWeeks, 20);
    sheet.setColumnWidth(4 + totalWeeks, 14); // Nilai
    sheet.setColumnWidth(5 + totalWeeks, 20); // Status (ketuntasan)

    final bytes = book.encode()!;
    return persistExportedFile('${exportFileSlug(judul)}.xlsx', Uint8List.fromList(bytes));
  }
}
