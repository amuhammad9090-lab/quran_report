import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/santri_monthly_recap.dart';
import '../../models/santri_record.dart';
import '../platform_file/exported_file.dart';
import '../platform_file/file_actions.dart';
import 'export_rows.dart';

/// Pembuat PDF (A4) untuk laporan biasa, laporan gabungan per Kelas+Halaqoh (1 tabel per kelompok,
/// dengan baris Guru Pembimbing), dan rekap bulanan. Hanya urusan layout PDF; isi baris dari [ExportRows].
class ExportPdf {
  const ExportPdf();

  static const _r = ExportRows();

  // Font PDF bawaan (Helvetica base14, tidak di-embed) tak punya "–" (en dash) dan "•" (bullet) dari
  // data record, jadi tampil kotak/tofu. Diterapkan HANYA di jalur PDF (bukan di ExportRows) agar
  // Excel & Word (Unicode penuh) tetap memakai "–"/"•".
  String _pdfSafe(String s) => s
      .replaceAll('–', '-') // en dash
      .replaceAll('—', '-') // em dash (jaga-jaga, walau harusnya udah gak kepakai lagi)
      .replaceAll('•', '-'); // bullet

  List<String> _pdfSafeHeaders(List<String> headers) => headers.map(_pdfSafe).toList();

  List<List<String>> _pdfSafeRows(List<List<String>> rows) =>
      rows.map((row) => row.map(_pdfSafe).toList()).toList();

  // -------------------- PDF (A4 potrait) --------------------
  Future<ExportedFile> exportPdf(
      List<SantriRecord> records, {
        required String judul,
        String? kelas,
        String? halaqoh,
        String? periode,
        String? guruPembimbing,
        bool includeTanggal = false,
        String? fixedTanggalLabel,
      }) async {
    final doc = pw.Document();
    final headers = _pdfSafeHeaders(includeTanggal ? ExportRows.headersWithTanggal : ExportRows.headers);
    final rows = _pdfSafeRows(includeTanggal
        ? _r.buildRowsWithTanggal(records, fixedTanggalLabel: fixedTanggalLabel)
        : _r.buildRows(records));
    final kelasValue = kelas ?? _r.joinUnique(records.map((r) => r.kelas));
    final halaqohValue = halaqoh ?? _r.joinUnique(records.map((r) => r.halaqoh));
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
              ExportRows.judulLaporan,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              ExportRows.namaSekolah,
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
          if (_r.keteranganSummaryPerSantri(records).isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Rekap Keterangan (Izin/Sakit/Alpa)',
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 3),
            for (final e in _r.keteranganSummaryPerSantri(records))
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 2),
                child: pw.Text('- ${e.key}: ${e.value}', style: const pw.TextStyle(fontSize: 8.5)),
              ),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    return persistExportedFile('${exportFileSlug(judul)}.pdf', bytes);
  }

  Future<ExportedFile> exportGroupedPdf(
      List<ExportKelasHalaqohSection<SantriRecord>> sections, {
        required String judul,
        String? periode,
        bool includeTanggal = false,
        String? fixedTanggalLabel,
      }) async {
    final doc = pw.Document();
    // includeTanggal=true (satu-satunya pemakai grouped export: Generate Laporan Pekanan) -> tabel
    // gabungan PER SANTRI (buildWeeklyRowsText); false = fallback ke tabel per-laporan lama.
    final headers = _pdfSafeHeaders(includeTanggal ? ExportRows.weeklyHeaders : ExportRows.headers);
    final columnWidths = includeTanggal
        ? const {
      0: pw.FixedColumnWidth(20),
      1: pw.FlexColumnWidth(1.7),
      2: pw.FlexColumnWidth(1.6),
      3: pw.FlexColumnWidth(3.2),
      4: pw.FlexColumnWidth(0.8),
      5: pw.FlexColumnWidth(1.6),
      6: pw.FlexColumnWidth(1.8),
    }
        : const {
      0: pw.FixedColumnWidth(26),
      1: pw.FlexColumnWidth(2.0),
      2: pw.FlexColumnWidth(2.0),
      3: pw.FlexColumnWidth(1.1),
      4: pw.FlexColumnWidth(0.8),
      5: pw.FlexColumnWidth(1.4),
      6: pw.FlexColumnWidth(1.8),
    };
    final cellAlignments = includeTanggal
        ? const {0: pw.Alignment.center, 4: pw.Alignment.center}
        : const {0: pw.Alignment.center, 4: pw.Alignment.center};

    final body = <pw.Widget>[];
    for (var s = 0; s < sections.length; s++) {
      final section = sections[s];
      if (s > 0) body.add(pw.SizedBox(height: 18));
      // Kelas dan Halaqoh dipisah jadi 2 baris teks biasa (seperti kop exportPdf), bukan 1 baris dengan
      // em dash "—" yang tak ada di font bawaan PDF (Helvetica, tidak di-embed) dan tampil tofu.
      body.add(pw.Text('Kelas   : ${section.kelas}',
          style: const pw.TextStyle(fontSize: 11)));
      body.add(pw.SizedBox(height: 2));
      body.add(pw.Text('Halaqoh : ${section.halaqoh}',
          style: const pw.TextStyle(fontSize: 11)));
      if (section.guruPembimbing != null && section.guruPembimbing!.trim().isNotEmpty) {
        body.add(pw.SizedBox(height: 2));
        body.add(pw.Text('Guru Pembimbing : ${section.guruPembimbing}',
            style: const pw.TextStyle(fontSize: 11)));
      }
      body.add(pw.SizedBox(height: 6));
      final rows = _pdfSafeRows(includeTanggal
          ? _r.buildWeeklyRowsText(section.items, fixedTanggalLabel: fixedTanggalLabel)
          : _r.buildRows(section.items));
      body.add(pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0E7C61)),
        cellStyle: const pw.TextStyle(fontSize: 8.5),
        cellHeight: 24,
        cellAlignment: pw.Alignment.centerLeft,
        columnWidths: columnWidths,
        cellAlignments: cellAlignments,
        oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
      ));
    }

    final allRecords = [for (final s in sections) ...s.items];
    final keteranganSummary = _r.keteranganSummaryPerSantri(allRecords);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        // Column judul/sekolah/periode dibungkus pw.Align agar SELALU selebar halaman; tanpa itu Column
        // shrink-wrap ke baris terpanjang dan textAlign.center hanya center relatif ke baris itu, bukan
        // ke tengah HALAMAN (teknik sama dengan Align Kelas/Halaqoh di exportPdf).
        header: (context) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(ExportRows.judulLaporan,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 2),
              pw.Text(ExportRows.namaSekolah,
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center),
              if (periode != null && periode.trim().isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(periode,
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                    textAlign: pw.TextAlign.center),
              ],
              pw.SizedBox(height: 14),
            ],
          ),
        ),
        build: (context) => [
          ...body,
          pw.SizedBox(height: 14),
          pw.Text('Total data: ${allRecords.length}',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          if (keteranganSummary.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text('Rekap Keterangan (Izin/Sakit/Alpa)',
                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 3),
            for (final e in keteranganSummary)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 2),
                child: pw.Text('- ${e.key}: ${e.value}', style: const pw.TextStyle(fontSize: 8.5)),
              ),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    return persistExportedFile('${exportFileSlug(judul)}.pdf', bytes);
  }

  Future<ExportedFile> exportGroupedMonthlyRecapPdf(
      List<ExportKelasHalaqohSection<SantriMonthlyRecap>> sections, {
        required String judul,
        required int totalWeeks,
        String? periode,
      }) async {
    final doc = pw.Document();
    final headers = _pdfSafeHeaders(_r.monthlyHeaders(totalWeeks));

    final body = <pw.Widget>[];
    for (var s = 0; s < sections.length; s++) {
      final section = sections[s];
      if (s > 0) body.add(pw.SizedBox(height: 16));
      // Lihat catatan di exportGroupedPdf soal kenapa dipecah 2 baris
      // (bukan 1 baris pakai em dash "—") — sama-sama biar gak tofu.
      body.add(pw.Text('Kelas   : ${section.kelas}',
          style: const pw.TextStyle(fontSize: 10.5)));
      body.add(pw.SizedBox(height: 2));
      body.add(pw.Text('Halaqoh : ${section.halaqoh}',
          style: const pw.TextStyle(fontSize: 10.5)));
      if (section.guruPembimbing != null && section.guruPembimbing!.trim().isNotEmpty) {
        body.add(pw.SizedBox(height: 2));
        body.add(pw.Text('Guru Pembimbing : ${section.guruPembimbing}',
            style: const pw.TextStyle(fontSize: 10.5)));
      }
      body.add(pw.SizedBox(height: 6));
      body.add(pw.TableHelper.fromTextArray(
        headers: headers,
        data: _pdfSafeRows(_r.monthlyRows(section.items, totalWeeks)),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
        headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0E7C61)),
        cellStyle: const pw.TextStyle(fontSize: 7.5),
        cellHeight: 22,
        cellAlignment: pw.Alignment.centerLeft,
        cellAlignments: const {0: pw.Alignment.center},
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
        oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      ));
    }

    final totalSantri = sections.fold<int>(0, (sum, s) => sum + s.items.length);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        // Lihat catatan di exportGroupedPdf soal pw.Align ini — tanpa
        // dibungkus gini, Column shrink-wrap ke baris terpanjang &
        // textAlign.center jadi nggak ke-tengah HALAMAN.
        header: (context) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(ExportRows.judulLaporan,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 2),
              pw.Text(ExportRows.namaSekolah,
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
        ),
        build: (context) => [
          ...body,
          pw.SizedBox(height: 12),
          pw.Text('Total santri: $totalSantri',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );

    final bytes = await doc.save();
    return persistExportedFile('${exportFileSlug(judul)}.pdf', bytes);
  }
}
