import '../../../core/utils/docx_builder.dart';
import '../../models/santri_monthly_recap.dart';
import '../../models/santri_record.dart';
import '../platform_file/exported_file.dart';
import '../platform_file/file_actions.dart';
import 'export_rows.dart';

/// Pembuat Word (.docx, lewat [DocxBuilder]) untuk laporan biasa, gabungan per Kelas+Halaqoh, dan
/// rekap bulanan. Hanya urusan layout dokumen; isi baris dari [ExportRows].
class ExportWord {
  const ExportWord();

  static const _r = ExportRows();

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
    final headers = includeTanggal ? ExportRows.headersWithTanggal : ExportRows.headers;
    final kelasValue = kelas ?? _r.joinUnique(records.map((r) => r.kelas));
    final halaqohValue = halaqoh ?? _r.joinUnique(records.map((r) => r.halaqoh));

    builder.addTitle(ExportRows.judulLaporan);
    builder.addSubtitle(ExportRows.namaSekolah);
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
      includeTanggal ? _r.buildRowsWithTanggal(records, fixedTanggalLabel: fixedTanggalLabel) : _r.buildRows(records),
    );
    builder.addSpacer();
    builder.addParagraph('Total data: ${records.length}', bold: true);

    final keteranganSummary = _r.keteranganSummaryPerSantri(records);
    if (keteranganSummary.isNotEmpty) {
      builder.addSpacer();
      builder.addParagraph('Rekap Keterangan (Izin/Sakit/Alpa)', bold: true);
      for (final e in keteranganSummary) {
        builder.addParagraph('- ${e.key}: ${e.value}');
      }
    }

    final bytes = builder.build();
    return persistExportedFile('${exportFileSlug(judul)}.docx', bytes);
  }

  Future<ExportedFile> exportGroupedWord(
      List<ExportKelasHalaqohSection<SantriRecord>> sections, {
        required String judul,
        String? periode,
        bool includeTanggal = false,
        String? fixedTanggalLabel,
      }) async {
    final builder = DocxBuilder();
    final headers = includeTanggal ? ExportRows.weeklyHeaders : ExportRows.headers;

    builder.addTitle(ExportRows.judulLaporan);
    builder.addSubtitle(ExportRows.namaSekolah);
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
          ? _r.buildWeeklyRowsText(section.items, fixedTanggalLabel: fixedTanggalLabel)
          : _r.buildRows(section.items);
      builder.addTable(headers, rows);
    }

    final allRecords = [for (final s in sections) ...s.items];
    builder.addSpacer();
    builder.addParagraph('Total data: ${allRecords.length}', bold: true);

    final keteranganSummary = _r.keteranganSummaryPerSantri(allRecords);
    if (keteranganSummary.isNotEmpty) {
      builder.addSpacer();
      builder.addParagraph('Rekap Keterangan (Izin/Sakit/Alpa)', bold: true);
      for (final e in keteranganSummary) {
        builder.addParagraph('- ${e.key}: ${e.value}');
      }
    }

    final bytes = builder.build();
    return persistExportedFile('${exportFileSlug(judul)}.docx', bytes);
  }

  Future<ExportedFile> exportGroupedMonthlyRecapWord(
      List<ExportKelasHalaqohSection<SantriMonthlyRecap>> sections, {
        required String judul,
        required int totalWeeks,
        String? periode,
      }) async {
    final builder = DocxBuilder();
    final headers = _r.monthlyHeaders(totalWeeks);

    builder.addTitle(ExportRows.judulLaporan);
    builder.addSubtitle(ExportRows.namaSekolah);
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
      builder.addTable(headers, _r.monthlyRows(section.items, totalWeeks));
    }

    final totalSantri = sections.fold<int>(0, (sum, s) => sum + s.items.length);
    builder.addSpacer();
    builder.addParagraph('Total santri: $totalSantri', bold: true);

    final bytes = builder.build();
    return persistExportedFile('${exportFileSlug(judul)}.docx', bytes);
  }
}
