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

/// Satu kelompok Kelas+Halaqoh dalam sebuah dokumen export gabungan
class ExportKelasHalaqohSection<T> {
  final String kelas;
  final String halaqoh;
  final String? guruPembimbing;
  final List<T> items;
  const ExportKelasHalaqohSection({
    required this.kelas,
    required this.halaqoh,
    this.guruPembimbing,
    required this.items,
  });
}

/// 1 baris ringkasan SATU santri di "Generate Laporan Pekanan" — gabungan
/// SEMUA laporan santri itu dalam pekan tsb (bisa >1 laporan kalau ada
/// laporan lebih dari sekali dalam pekan itu).
class SantriWeeklyRow {
  final String namaAnak;
  final String tanggalLabel;
  final String capaian;
  final int totalBaris;
  final String keterangan;
  final String catatan;

  const SantriWeeklyRow({
    required this.namaAnak,
    required this.tanggalLabel,
    required this.capaian,
    required this.totalBaris,
    required this.keterangan,
    required this.catatan,
  });
}

class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  // Kop laporan resmi — tetap sama di semua format & konteks ekspor
  // (laporan biasa, per-folder, maupun rekap bulanan).
  static const _judulLaporan = 'LAPORAN PEKANAN AL QURAN';
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

  /// Versi [_rows] dengan kolom Hari/Tanggal gabungan. Kalau
  /// [fixedTanggalLabel] diisi, SEMUA baris pakai label itu (bukan tanggal
  /// masing-masing record) — dipakai Generate Laporan Pekanan, yang
  /// menampilkan "Hari/Tanggal" sebagai tanggal laporan TERAKHIR dibuat
  /// dalam pekan itu, bukan tanggal per-baris (lihat
  /// GenerateRekapPekananScreen).
  List<List<String>> _rowsWithTanggal(List<SantriRecord> records, {String? fixedTanggalLabel}) {
    final rows = <List<String>>[];
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      rows.add([
        '${i + 1}',
        fixedTanggalLabel ?? _hariTanggalText(r.tanggal),
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

  // --- Wrapper publik dari helper private di atas — dipakai widget UI
  // (bukan cuma proses export) yang butuh nampilin isi kolom PERSIS sama
  // seperti hasil export, mis. [ExportStyleRecordsTable] di Rekap Harian
  // & Generate Rekap Pekanan, biar satu-satunya sumber logic tetap di
  // sini (tidak diduplikasi di layer widget).
  String capaianLabelFor(SantriRecord r) => _capaianLabel(r);
  String ayatHalRangeFor(SantriRecord r) => _ayatHalRange(r);
  String barisTextFor(SantriRecord r) => _barisText(r);
  String catatanTextFor(SantriRecord r) => _catatanText(r);
  String hariTanggalTextFor(DateTime d) => _hariTanggalText(d);

  // -------------------- GENERATE LAPORAN PEKANAN: GABUNG PER SANTRI --------------------
  // Beda dari _rows/_rowsWithTanggal (1 baris = 1 LAPORAN), di sini
  // 1 baris = 1 SANTRI: semua laporannya dalam pekan itu dihimpun jadi
  // 1 baris, kolom Capaian dipecah per jenis (Tahsin/Tahfizh/
  // Tahsin+Tahfizh/Muroja'ah — masing2 cuma tampil kalau memang ada
  // laporannya di pekan itu), dan kolom Baris di-SUM dari SEMUA laporan
  // santri itu. Dipakai [GenerateRekapPekananScreen] (preview lewat
  // [weeklyRowsGroupedBySantriFor], export lewat exportGroupedPdf/
  // Excel/Word) — TIDAK dipakai Rekap Harian (tetap per-laporan, lihat
  // ExportStyleRecordsTable & _rows/_rowsWithTanggal).

  static const _weeklyHeadersGrouped = [
    'No',
    'Hari/Tanggal',
    'Nama Murid',
    'Capaian',
    'Baris',
    'Keterangan',
    'Catatan',
  ];

  // Detail 1 laporan Tahsin/Tahfizh/Muroja'ah TANPA prefix label status —
  // dipakai gabungan per-jenis di bawah, biar label statusnya cuma
  // ditulis SEKALI per jenis (bukan diulang di tiap laporan yang jenisnya
  // sama, beda dari _capaianLabel yang selalu prefix status).
  String _tahsinDetailNoLabel(SantriRecord r) {
    final label = _tahsinPartLabel(r);
    final range = _tahsinPartRange(r);
    return range == '-' ? label : '$label ($range)';
  }

  String _tahfizhDetailNoLabel(SantriRecord r) {
    final names = _tahfizhSurahNames(r);
    final ranges = _tahfizhAyatRanges(r);
    return ranges == '-' ? names : '$names ($ranges)';
  }

  String _murojaahDetailNoLabel(SantriRecord r) {
    final segs = r.tilawahSegmentsEffective;
    if (segs.isEmpty) return '-';
    return segs.map((s) => '${s.surahName} (${s.ayatMulai}-${s.ayatSelesai})').join(' + ');
  }

  // <-- BARU: helper gabung SEMUA laporan JENIS YANG SAMA dalam 1 pekan
  // jadi 1 blok "Label: ..." — kalau cuma 1 laporan tetap 1 baris seperti
  // semula ("Tahsin: xxx"), tapi kalau >1 (santri setor jenis yang sama
  // lebih dari sekali dalam pekan itu) dipecah per baris (bukan "; " lagi)
  // — tiap baris = 1 hari setoran, biar kelihatan jelas & rapi kalau
  // dibuka di Excel (lihat juga SantriMonthlyRecap.capaianForWeek, pola
  // yang sama persis).
  String _joinCategoryPerLine(String label, Iterable<String> details) {
    final list = details.toList();
    if (list.isEmpty) return '';
    if (list.length == 1) return '$label: ${list.first}';
    return '$label:\n${list.join('\n')}';
  }

  String _weeklyCapaianForSantri(List<SantriRecord> recs) {
    final lines = <String>[];
    final tahsin = recs.where((r) => r.status == HafalanStatus.tahsin).toList();
    if (tahsin.isNotEmpty) {
      lines.add(_joinCategoryPerLine('Tahsin', tahsin.map(_tahsinDetailNoLabel)));
    }
    final tahfizh = recs.where((r) => r.status == HafalanStatus.tahfizh).toList();
    if (tahfizh.isNotEmpty) {
      lines.add(_joinCategoryPerLine('Tahfizh', tahfizh.map(_tahfizhDetailNoLabel)));
    }
    final gabungan = recs.where((r) => r.status == HafalanStatus.tahsinTahfizh).toList();
    if (gabungan.isNotEmpty) {
      lines.add(_joinCategoryPerLine(
        'Tahsin+Tahfizh',
        gabungan.map((r) => '${_tahsinDetailNoLabel(r)} & ${_tahfizhDetailNoLabel(r)}'),
      ));
    }
    final murojaah = recs.where((r) => r.status == HafalanStatus.murojaahTasmi).toList();
    if (murojaah.isNotEmpty) {
      lines.add(_joinCategoryPerLine("Muroja'ah/Tasmi'", murojaah.map(_murojaahDetailNoLabel)));
    }
    return lines.isEmpty ? '-' : lines.join('\n');
  }

  // Sama polanya seperti SantriMonthlyRecap.keteranganSummaryText: Hadir
  // tidak dihitung (bukan "keterangan" yang perlu disorot), '-' kalau
  // semua laporan pekan itu Hadir.
  String _weeklyKeteranganForSantri(List<SantriRecord> recs) {
    final counts = <Keterangan, int>{};
    for (final r in recs) {
      if (r.keterangan == Keterangan.hadir) continue;
      counts[r.keterangan] = (counts[r.keterangan] ?? 0) + 1;
    }
    if (counts.isEmpty) return '-';
    final entries = counts.entries.toList()..sort((a, b) => a.key.index.compareTo(b.key.index));
    return entries.map((e) => '${e.value}x ${e.key.shortLabel}').join(', ');
  }

  String _weeklyCatatanForSantri(List<SantriRecord> recs) {
    final notes = recs.map((r) => r.catatan?.trim() ?? '').where((c) => c.isNotEmpty).toList();
    return notes.isEmpty ? '-' : notes.join('; ');
  }

  /// Kumpulkan [records] (biasanya 1 Kelas+Halaqoh dalam 1 pekan) jadi
  /// 1 baris ringkasan per SANTRI (lihat [SantriWeeklyRow]). Kalau
  /// [fixedTanggalLabel] diisi, dipakai untuk semua baris (sama seperti
  /// [_rowsWithTanggal]); kalau tidak, dipakai tanggal laporan TERAKHIR
  /// milik santri itu di pekan tsb. Terurut nama (case-insensitive).
  List<SantriWeeklyRow> weeklyRowsGroupedBySantriFor(
      List<SantriRecord> records, {
        String? fixedTanggalLabel,
      }) {
    final byKey = <String, List<SantriRecord>>{};
    final displayName = <String, String>{};
    for (final r in records) {
      final key = r.namaAnak.trim().toLowerCase();
      byKey.putIfAbsent(key, () => []).add(r);
      displayName[key] = r.namaAnak.trim();
    }
    final keys = byKey.keys.toList()
      ..sort((a, b) => (displayName[a] ?? a).toLowerCase().compareTo((displayName[b] ?? b).toLowerCase()));

    return [
      for (final key in keys)
        _buildWeeklyRow(
          nama: displayName[key] ?? key,
          recs: List<SantriRecord>.from(byKey[key]!)..sort((a, b) => a.tanggal.compareTo(b.tanggal)),
          fixedTanggalLabel: fixedTanggalLabel,
        ),
    ];
  }

  SantriWeeklyRow _buildWeeklyRow({
    required String nama,
    required List<SantriRecord> recs,
    String? fixedTanggalLabel,
  }) {
    return SantriWeeklyRow(
      namaAnak: nama,
      tanggalLabel: fixedTanggalLabel ?? _hariTanggalText(recs.last.tanggal),
      capaian: _weeklyCapaianForSantri(recs),
      totalBaris: recs.fold<int>(0, (sum, r) => sum + (r.totalBaris ?? 0)),
      keterangan: _weeklyKeteranganForSantri(recs),
      catatan: _weeklyCatatanForSantri(recs),
    );
  }

  // Versi teks List<List<String>> dari [weeklyRowsGroupedBySantriFor] —
  // dipakai proses export (Pdf/Excel/Word) yang butuh bentuk baris/kolom
  // mentah, sumber logic-nya tetap SAMA (cuma beda bentuk output) biar
  // preview & hasil export identik.
  List<List<String>> _weeklyRowsGroupedBySantriText(
      List<SantriRecord> records, {
        String? fixedTanggalLabel,
      }) {
    final rows = weeklyRowsGroupedBySantriFor(records, fixedTanggalLabel: fixedTanggalLabel);
    return [
      for (var i = 0; i < rows.length; i++)
        [
          '${i + 1}',
          rows[i].tanggalLabel,
          rows[i].namaAnak,
          rows[i].capaian,
          '${rows[i].totalBaris}',
          rows[i].keterangan,
          rows[i].catatan,
        ],
    ];
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
        String? fixedTanggalLabel,
      }) async {
    final doc = pw.Document();
    final headers = includeTanggal ? _headersWithTanggal : _headers;
    final rows = includeTanggal
        ? _rowsWithTanggal(records, fixedTanggalLabel: fixedTanggalLabel)
        : _rows(records);
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
        String? fixedTanggalLabel,
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

    final rows = includeTanggal
        ? _rowsWithTanggal(records, fixedTanggalLabel: fixedTanggalLabel)
        : _rows(records);
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
        String? fixedTanggalLabel,
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
    builder.addTable(
      headers,
      includeTanggal ? _rowsWithTanggal(records, fixedTanggalLabel: fixedTanggalLabel) : _rows(records),
    );
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

  // -------------------- EXPORT TERKELOMPOK PER KELAS+HALAQOH --------------------
  // Dipakai Generate Laporan Pekanan: 1 dokumen berisi beberapa tabel — 1
  // tabel per Kelas+Halaqoh (bukan 1 tabel besar gabungan semua kelas) —
  // masing-masing dengan baris Guru Pembimbing sendiri kalau ada.

  Future<ExportedFile> exportGroupedPdf(
      List<ExportKelasHalaqohSection<SantriRecord>> sections, {
        required String judul,
        String? periode,
        bool includeTanggal = false,
        String? fixedTanggalLabel,
      }) async {
    final doc = pw.Document();
    // includeTanggal=true (satu-satunya pemakai grouped export, Generate
    // Laporan Pekanan) -> tabel gabungan PER SANTRI (lihat
    // _weeklyRowsGroupedBySantriText); includeTanggal=false dipertahankan
    // fallback ke tabel per-laporan lama.
    final headers = includeTanggal ? _weeklyHeadersGrouped : _headers;
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
      // Sebelumnya 1 baris "Kelas X — Halaqoh Y" (pakai em dash "—") —
      // selain formatnya beda dari kop exportPdf (Kelas/Halaqoh baris
      // terpisah), karakter "—" ini juga TIDAK ada di font bawaan PDF
      // (Helvetica standar, tidak di-embed), jadi muncul kotak-kotak/tofu
      // di banyak PDF viewer. Dipecah jadi 2 baris teks biasa (sama
      // seperti kop exportPdf) — sekaligus menghilangkan karakter itu.
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
      final rows = includeTanggal
          ? _weeklyRowsGroupedBySantriText(section.items, fixedTanggalLabel: fixedTanggalLabel)
          : _rows(section.items);
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
    final keteranganSummary = _keteranganSummaryPerSantri(allRecords);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        // Column judul/sekolah/periode di-bungkus pw.Align biar Column-nya
        // SELALU selebar halaman — tanpa ini, Column cuma shrink-wrap
        // selebar baris terpanjang di dalamnya (biasanya baris "periode"
        // yang paling panjang), jadinya textAlign.center di baris-baris
        // lain cuma ke-center RELATIF ke baris terpanjang itu, bukan ke
        // tengah HALAMAN (makanya kelihatan numpuk ke kiri). Teknik
        // pw.Align yang "minta lebar penuh" ini SAMA PERSIS yang bikin
        // [exportPdf] sudah benar dari sononya (lihat Align Kelas/Halaqoh
        // di sana) — di sini dipakai lagi buat bungkus Column judulnya.
        header: (context) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Column(
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
    return _saveBytes('${_slug(judul)}.pdf', bytes);
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

    final headers = includeTanggal ? _weeklyHeadersGrouped : _headers;
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

    writeMerged(_judulLaporan, titleStyle);
    writeMerged(_namaSekolah, subtitleStyle);
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
          ? _weeklyRowsGroupedBySantriText(section.items, fixedTanggalLabel: fixedTanggalLabel)
          : _rows(section.items);
      // Kolom "Capaian" (index 3 di versi gabungan-per-santri) sekarang
      // isinya bisa multi-baris ("\n" per hari setoran, lihat
      // _weeklyCapaianForSantri) — WAJIB pakai textWrapping.WrapText biar
      // "\n"-nya beneran kelihatan ganti baris waktu dibuka di Excel
      // (tanpa ini, Excel nampilin semua digabung 1 baris panjang).
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
      // 7 kolom versi gabungan-per-santri: No, Hari/Tanggal, Nama Murid,
      // Capaian, Baris, Keterangan, Catatan (lihat _weeklyHeadersGrouped).
      sheet.setColumnWidth(0, 5);
      sheet.setColumnWidth(1, 18);
      sheet.setColumnWidth(2, 20);
      sheet.setColumnWidth(3, 40);
      sheet.setColumnWidth(4, 8);
      sheet.setColumnWidth(5, 18);
      sheet.setColumnWidth(6, 22);
    } else {
      sheet.setColumnWidth(0, 5);
      sheet.setColumnWidth(1, 22);
      sheet.setColumnWidth(2, 24);
      sheet.setColumnWidth(3, 12);
      sheet.setColumnWidth(4, 8);
      sheet.setColumnWidth(5, 18);
      sheet.setColumnWidth(6, 22);
    }

    final allRecords = [for (final s in sections) ...s.items];
    final keteranganSummary = _keteranganSummaryPerSantri(allRecords);
    if (keteranganSummary.isNotEmpty) {
      row++;
      writeMerged('Rekap Keterangan (Izin/Sakit/Alpa)', xls.CellStyle(bold: true, fontSize: 11));
      for (final e in keteranganSummary) {
        writeMerged('- ${e.key}: ${e.value}', labelStyle);
      }
    }

    final bytes = book.encode()!;
    return _saveBytes('${_slug(judul)}.xlsx', Uint8List.fromList(bytes));
  }

  Future<ExportedFile> exportGroupedWord(
      List<ExportKelasHalaqohSection<SantriRecord>> sections, {
        required String judul,
        String? periode,
        bool includeTanggal = false,
        String? fixedTanggalLabel,
      }) async {
    final builder = DocxBuilder();
    final headers = includeTanggal ? _weeklyHeadersGrouped : _headers;

    builder.addTitle(_judulLaporan);
    builder.addSubtitle(_namaSekolah);
    if (periode != null && periode.trim().isNotEmpty) builder.addSubtitle(periode);
    builder.addSpacer();

    for (var s = 0; s < sections.length; s++) {
      final section = sections[s];
      if (s > 0) builder.addSpacer();
      builder.addParagraph('Kelas   : ${section.kelas}');
      builder.addParagraph('Halaqoh : ${section.halaqoh}');
      if (section.guruPembimbing != null && section.guruPembimbing!.trim().isNotEmpty) {
        builder.addParagraph('Guru Pembimbing : ${section.guruPembimbing}');
      }
      final rows = includeTanggal
          ? _weeklyRowsGroupedBySantriText(section.items, fixedTanggalLabel: fixedTanggalLabel)
          : _rows(section.items);
      builder.addTable(headers, rows);
    }

    final allRecords = [for (final s in sections) ...s.items];
    builder.addSpacer();
    builder.addParagraph('Total data: ${allRecords.length}', bold: true);

    final keteranganSummary = _keteranganSummaryPerSantri(allRecords);
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

  // -------------------- REKAP BULANAN TERKELOMPOK PER KELAS+HALAQOH --------------------
  // Sama seperti exportPdf/exportExcel/exportWord (rekap pekanan) tapi
  // 1 baris = 1 SANTRI dengan kolom Pekan 1..N (lihat
  // SantriMonthlyRecap.capaianForWeek), dipecah jadi beberapa tabel — 1
  // tabel per Kelas+Halaqoh — plus baris Guru Pembimbing per tabel kalau
  // ada. Dipakai tombol Generate + tombol export di layar Rekap Bulanan.

  List<String> _monthlyHeadersGrouped(int totalWeeks) => [
    'No',
    'Nama Murid',
    for (var w = 1; w <= totalWeeks; w++) 'Pekan $w',
    'Total Baris',
    'Keterangan',
  ];

  List<List<String>> _monthlyRowsGrouped(List<SantriMonthlyRecap> recaps, int totalWeeks) {
    final rows = <List<String>>[];
    for (var i = 0; i < recaps.length; i++) {
      final r = recaps[i];
      rows.add([
        '${i + 1}',
        r.nama,
        for (var w = 1; w <= totalWeeks; w++) r.capaianForWeek(w),
        '${r.totalBaris}',
        r.keteranganSummaryText,
      ]);
    }
    return rows;
  }

  Future<ExportedFile> exportGroupedMonthlyRecapPdf(
      List<ExportKelasHalaqohSection<SantriMonthlyRecap>> sections, {
        required String judul,
        required int totalWeeks,
        String? periode,
      }) async {
    final doc = pw.Document();
    final headers = _monthlyHeadersGrouped(totalWeeks);

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
        data: _monthlyRowsGrouped(section.items, totalWeeks),
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
    return _saveBytes('${_slug(judul)}.pdf', bytes);
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

    final headers = _monthlyHeadersGrouped(totalWeeks);
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

    writeMerged(_judulLaporan, titleStyle);
    writeMerged(_namaSekolah, subtitleStyle);
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
      final rows = _monthlyRowsGrouped(section.items, totalWeeks);
      // Kolom "Pekan 1..N" (index 2..totalWeeks+1) sekarang isinya bisa
      // multi-baris ("\n" per hari setoran, lihat
      // SantriMonthlyRecap.capaianForWeek) — sama seperti
      // exportGroupedExcel, WAJIB textWrapping.WrapText biar "\n"-nya
      // beneran ganti baris di Excel, bukan digabung 1 baris panjang.
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

    final bytes = book.encode()!;
    return _saveBytes('${_slug(judul)}.xlsx', Uint8List.fromList(bytes));
  }

  Future<ExportedFile> exportGroupedMonthlyRecapWord(
      List<ExportKelasHalaqohSection<SantriMonthlyRecap>> sections, {
        required String judul,
        required int totalWeeks,
        String? periode,
      }) async {
    final builder = DocxBuilder();
    final headers = _monthlyHeadersGrouped(totalWeeks);

    builder.addTitle(_judulLaporan);
    builder.addSubtitle(_namaSekolah);
    if (periode != null && periode.trim().isNotEmpty) builder.addSubtitle(periode);
    builder.addSpacer();

    for (var s = 0; s < sections.length; s++) {
      final section = sections[s];
      if (s > 0) builder.addSpacer();
      builder.addParagraph('Kelas   : ${section.kelas}');
      builder.addParagraph('Halaqoh : ${section.halaqoh}');
      if (section.guruPembimbing != null && section.guruPembimbing!.trim().isNotEmpty) {
        builder.addParagraph('Guru Pembimbing : ${section.guruPembimbing}');
      }
      builder.addTable(headers, _monthlyRowsGrouped(section.items, totalWeeks));
    }

    final totalSantri = sections.fold<int>(0, (sum, s) => sum + s.items.length);
    builder.addSpacer();
    builder.addParagraph('Total santri: $totalSantri', bold: true);

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