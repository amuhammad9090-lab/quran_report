import 'dart:convert';

import 'package:archive/archive.dart';

/// Builder minimal untuk file .docx (Office Open XML).
/// Mendukung: judul, paragraf, dan tabel sederhana — cukup untuk
/// kebutuhan laporan tabular. Tidak butuh dependency Word khusus,
/// murni menyusun struktur zip + XML secara manual.
class DocxBuilder {
  final List<String> _bodyXmlParts = [];

  /// Halaman A4 landscape (dipakai tabel lebar, mis. rekap kehadiran bulanan).
  final bool landscape;

  DocxBuilder({this.landscape = false});

  void addTitle(String text) {
    _bodyXmlParts.add('''
<w:p><w:pPr><w:jc w:val="center"/></w:pPr>
<w:r><w:rPr><w:b/><w:sz w:val="36"/></w:rPr><w:t xml:space="preserve">${_esc(text)}</w:t></w:r></w:p>
''');
  }

  void addSubtitle(String text) {
    _bodyXmlParts.add('''
<w:p><w:pPr><w:jc w:val="center"/></w:pPr>
<w:r><w:rPr><w:i/><w:sz w:val="20"/><w:color w:val="666666"/></w:rPr><w:t xml:space="preserve">${_esc(text)}</w:t></w:r></w:p>
''');
  }

  void addSpacer() {
    _bodyXmlParts.add('<w:p/>');
  }

  void addParagraph(String text, {bool bold = false}) {
    final boldTag = bold ? '<w:b/>' : '';
    _bodyXmlParts.add('''
<w:p><w:r><w:rPr>$boldTag<w:sz w:val="20"/></w:rPr><w:t xml:space="preserve">${_esc(text)}</w:t></w:r></w:p>
''');
  }

  /// Tabel sederhana: baris pertama otomatis jadi header (bold, shading).
  ///
  /// Opsional (default-nya = perilaku lama, kolom sama lebar total 9000):
  /// [columnWidths] lebar tiap kolom dalam dxa, [compact] font + margin sel lebih kecil buat tabel
  /// padat, [centerFromColumn] kolom mulai index ini rata tengah.
  void addTable(
    List<String> headers,
    List<List<String>> rows, {
    List<int>? columnWidths,
    bool compact = false,
    int? centerFromColumn,
  }) {
    final colCount = headers.length;
    final defaultWidth = (9000 / colCount).floor();
    final widths = columnWidths ?? List<int>.filled(colCount, defaultWidth);
    final totalWidth = widths.fold<int>(0, (a, b) => a + b);
    final headerSz = compact ? 14 : 18;
    final cellSz = compact ? 14 : 17;
    final cellMar = compact
        ? '<w:tblCellMar><w:left w:w="30" w:type="dxa"/><w:right w:w="30" w:type="dxa"/></w:tblCellMar>'
        : '';
    String jc(int col) =>
        (centerFromColumn != null && col >= centerFromColumn) ? '<w:pPr><w:jc w:val="center"/></w:pPr>' : '';

    final buffer = StringBuffer();
    buffer.write('<w:tbl>');
    buffer.write('''
<w:tblPr>
  <w:tblStyle w:val="TableGrid"/>
  <w:tblW w:w="$totalWidth" w:type="dxa"/>
  <w:tblBorders>
    <w:top w:val="single" w:sz="4" w:color="CCCCCC"/>
    <w:left w:val="single" w:sz="4" w:color="CCCCCC"/>
    <w:bottom w:val="single" w:sz="4" w:color="CCCCCC"/>
    <w:right w:val="single" w:sz="4" w:color="CCCCCC"/>
    <w:insideH w:val="single" w:sz="4" w:color="CCCCCC"/>
    <w:insideV w:val="single" w:sz="4" w:color="CCCCCC"/>
  </w:tblBorders>
  $cellMar
</w:tblPr>
''');
    buffer.write('<w:tblGrid>');
    for (var i = 0; i < colCount; i++) {
      buffer.write('<w:gridCol w:w="${widths[i]}"/>');
    }
    buffer.write('</w:tblGrid>');

    // Header row
    buffer.write('<w:tr>');
    for (var i = 0; i < headers.length; i++) {
      final h = headers[i];
      buffer.write('''
<w:tc>
  <w:tcPr><w:tcW w:w="${widths[i]}" w:type="dxa"/><w:shd w:val="clear" w:fill="0E7C61"/></w:tcPr>
  <w:p>${jc(i)}<w:r><w:rPr><w:b/><w:color w:val="FFFFFF"/><w:sz w:val="$headerSz"/></w:rPr><w:t xml:space="preserve">${_esc(h)}</w:t></w:r></w:p>
</w:tc>
''');
    }
    buffer.write('</w:tr>');

    // Data rows
    for (var r = 0; r < rows.length; r++) {
      final fill = r.isEven ? 'FFFFFF' : 'F3F6F4';
      buffer.write('<w:tr>');
      for (var i = 0; i < rows[r].length; i++) {
        final cell = rows[r][i];
        buffer.write('''
<w:tc>
  <w:tcPr><w:tcW w:w="${widths[i]}" w:type="dxa"/><w:shd w:val="clear" w:fill="$fill"/></w:tcPr>
  <w:p>${jc(i)}<w:r><w:rPr><w:sz w:val="$cellSz"/></w:rPr>${_runContent(cell)}</w:r></w:p>
</w:tc>
''');
      }
      buffer.write('</w:tr>');
    }

    buffer.write('</w:tbl>');
    _bodyXmlParts.add(buffer.toString());
  }

  // Isi 1 <w:r> (run) dari teks cell — kalau ada "\n" (mis. cell Capaian
  // gabungan di rekap pekanan per-santri, lihat
  // ExportService.weeklyRowsGroupedBySantriFor), tiap baris dipisah
  // <w:br/> beneran, BUKAN dibiarkan jadi 1 baris panjang (Word menganggap
  // "\n" polos di dalam <w:t> cuma whitespace, bukan ganti baris).
  String _runContent(String cell) {
    final lines = cell.split('\n');
    final buf = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) buf.write('<w:br/>');
      buf.write('<w:t xml:space="preserve">${_esc(lines[i])}</w:t>');
    }
    return buf.toString();
  }

  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  List<int> build() {
    final archive = Archive();

    void addFile(String path, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    addFile('[Content_Types].xml', _contentTypesXml);
    addFile('_rels/.rels', _relsXml);
    addFile('word/_rels/document.xml.rels', _documentRelsXml);
    addFile('word/styles.xml', _stylesXml);
    addFile('word/document.xml', _documentXml());

    final zipData = ZipEncoder().encode(archive);
    return zipData ?? <int>[];
  }

  String _documentXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>
${_bodyXmlParts.join('\n')}
<w:sectPr>
  ${landscape ? '<w:pgSz w:w="16838" w:h="11906" w:orient="landscape"/>' : '<w:pgSz w:w="11906" w:h="16838"/>'}
  <w:pgMar w:top="1000" w:right="1000" w:bottom="1000" w:left="1000" w:header="708" w:footer="708" w:gutter="0"/>
</w:sectPr>
</w:body>
</w:document>''';
  }

  static const _contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';

  static const _relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

  static const _documentRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

  static const _stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="table" w:styleId="TableGrid">
    <w:name w:val="Table Grid"/>
    <w:basedOn w:val="TableNormal"/>
  </w:style>
  <w:style w:type="table" w:styleId="TableNormal">
    <w:name w:val="Normal Table"/>
  </w:style>
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
        <w:sz w:val="20"/>
      </w:rPr>
    </w:rPrDefault>
  </w:docDefaults>
</w:styles>''';
}
