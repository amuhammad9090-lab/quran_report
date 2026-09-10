import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;

import '../../core/utils/text_utils.dart';
import '../models/kelas_halaqoh.dart';
import '../models/student.dart';
import '../models/user_account.dart';
import 'platform_file/exported_file.dart';
import 'platform_file/file_actions.dart';

const _sheetMurid = 'Murid';
const _sheetGuru = 'Guru';

// ---------------------------------------------------------------------------
// Murid (Student) — kelas & halaqoh bisa diubah lewat Excel.
// ---------------------------------------------------------------------------

/// Satu baris hasil bandingin file Excel import vs data santri SEKARANG.
/// Ini PREVIEW doang (belum ditulis ke mana-mana).
class StudentImportRow {
  final Student current;
  final String newKelas;
  final String newHalaqoh;
  const StudentImportRow({
    required this.current,
    required this.newKelas,
    required this.newHalaqoh,
  });

  bool get isChanged => current.kelas != newKelas || current.halaqoh != newHalaqoh;

  Student toUpdatedStudent() => Student(
        id: current.id,
        nama: current.nama,
        kelas: newKelas,
        halaqoh: newHalaqoh,
        schoolId: current.schoolId,
      );
}

class StudentImportResult {
  final List<StudentImportRow> rows;
  final List<String> unknownIds;
  const StudentImportResult({required this.rows, required this.unknownIds});

  List<StudentImportRow> get changedRows => rows.where((r) => r.isChanged).toList();
}

// ---------------------------------------------------------------------------
// Guru (UserAccount) — HANYA displayName & assignments (kelas+halaqoh) yang
// bisa diubah lewat Excel. `username`/`role` sengaja cuma kolom REFERENSI
// (ditulis ke file biar gampang dikenali barisnya), diabaikan saat parseImport
// -- perubahan username/password/role tetap lewat alur yang sudah ada,
// BUKAN dari bulk-edit di sini (biar gak ada resiko admin gak sengaja ganti
// login/akses guru cuma gara-gara typo di spreadsheet).
// ---------------------------------------------------------------------------

class AccountImportRow {
  final UserAccount current;
  final String newDisplayName;
  final List<KelasHalaqoh> newAssignments;
  const AccountImportRow({
    required this.current,
    required this.newDisplayName,
    required this.newAssignments,
  });

  bool get isChanged =>
      current.displayName != newDisplayName || !_sameAssignments(current.assignments, newAssignments);

  static bool _sameAssignments(List<KelasHalaqoh> a, List<KelasHalaqoh> b) {
    if (a.length != b.length) return false;
    final aKeys = a.map((e) => e.key).toSet();
    final bKeys = b.map((e) => e.key).toSet();
    return aKeys.length == bKeys.length && aKeys.containsAll(bKeys);
  }

  UserAccount toUpdatedAccount() => current.copyWith(
        displayName: newDisplayName,
        assignments: newAssignments,
      );
}

class AccountImportResult {
  final List<AccountImportRow> rows;
  final List<String> unknownIds;
  const AccountImportResult({required this.rows, required this.unknownIds});

  List<AccountImportRow> get changedRows => rows.where((r) => r.isChanged).toList();
}

/// Bungkusan hasil parse SATU file Excel yang isinya dua sheet sekaligus
/// (Murid & Guru) -- lihat [SchoolDataExcelService].
class SchoolDataImportResult {
  final StudentImportResult students;
  final AccountImportResult accounts;
  const SchoolDataImportResult({required this.students, required this.accounts});

  bool get hasAnyChange => students.changedRows.isNotEmpty || accounts.changedRows.isNotEmpty;
}

/// Export/import data GURU & MURID sekaligus lewat SATU file Excel (dua
/// sheet: "Murid" & "Guru") -- jalan keluar buat perubahan massal (mis.
/// reshuffle halaqoh pas kenaikan Tahsin -> Tahfizh, atau update
/// assignment banyak guru sekaligus di awal semester) tanpa klik satu-satu
/// di Kelola Murid/Kelola Guru, dan tanpa edit kode + build ulang APK.
///
/// Formatnya SENGAJA disamain sama sumber seed asli (`data_guru_dan_murid.xlsx`,
/// lihat komentar di local_seed_data.dart) supaya satu format Excel dipakai
/// konsisten dari awal (bikin seed) sampai seterusnya (maintenance harian).
///
/// Alurnya: [saveWorkbook] -> admin BUKA file, edit kolom yang boleh diubah
/// (kelas/halaqoh buat murid, nama/assignment buat guru) -> file yang SAMA
/// di-upload balik lewat [parseImport] -> hasilnya ditampilkan sebagai
/// preview (lihat KelolaDataScreen) sebelum admin konfirmasi -> baru
/// [ApiStudentRepository.bulkUpdateKelasHalaqoh] /
/// [ApiAuthRepository.bulkUpdateAssignments] yang beneran nulis ke Firestore.
///
/// PENTING: kolom `id` dipakai SATU-SATUNYA buat cocokin baris (BUKAN
/// `nama`/`username` -- bisa ada nama kembar). Baris yang id-nya gak
/// dikenali masuk ke `unknownIds`, BUKAN bikin seluruh proses gagal.
class SchoolDataExcelService {
  SchoolDataExcelService._();
  static final SchoolDataExcelService instance = SchoolDataExcelService._();

  // Kolom sheet Murid.
  static const _mColId = 0;
  static const _mColNama = 1;
  static const _mColKelas = 2;
  static const _mColHalaqoh = 3;

  // Kolom sheet Guru. Kolom index 3 ("role") sengaja gak punya konstanta
  // di sini -- cuma dibuat pas export (lihat guruHeaders) buat referensi
  // visual admin, TIDAK PERNAH dibaca balik di parseImport (perubahan
  // role tetap lewat alur yang sudah ada, bukan bulk-edit Excel).
  static const _gColId = 0;
  static const _gColUsername = 1;
  static const _gColDisplayName = 2;
  static const _gColAssignments = 4;

  xls.CellStyle get _headerStyle => xls.CellStyle(
        bold: true,
        fontColorHex: xls.ExcelColor.white,
        backgroundColorHex: xls.ExcelColor.fromHexString('#0E7C61'),
      );

  ExportedFile buildWorkbook(List<Student> students, List<UserAccount> accounts) {
    final book = xls.Excel.createExcel();

    final muridSheet = book[_sheetMurid];
    const muridHeaders = ['id', 'nama', 'kelas', 'halaqoh'];
    for (var c = 0; c < muridHeaders.length; c++) {
      muridSheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
        ..value = xls.TextCellValue(muridHeaders[c])
        ..cellStyle = _headerStyle;
    }
    final sortedStudents = [...students]..sort((a, b) {
        final byKelas = a.kelas.compareTo(b.kelas);
        if (byKelas != 0) return byKelas;
        final byHalaqoh = a.halaqoh.compareTo(b.halaqoh);
        if (byHalaqoh != 0) return byHalaqoh;
        return a.nama.compareTo(b.nama);
      });
    for (var r = 0; r < sortedStudents.length; r++) {
      final s = sortedStudents[r];
      final values = [s.id, s.nama, s.kelas, s.halaqoh];
      for (var c = 0; c < values.length; c++) {
        muridSheet
            .cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1))
            .value = xls.TextCellValue(values[c]);
      }
    }

    final guruSheet = book[_sheetGuru];
    const guruHeaders = ['id', 'username', 'displayName', 'role', 'assignments'];
    for (var c = 0; c < guruHeaders.length; c++) {
      guruSheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
        ..value = xls.TextCellValue(guruHeaders[c])
        ..cellStyle = _headerStyle;
    }
    final sortedAccounts = [...accounts]..sort((a, b) => a.displayName.compareTo(b.displayName));
    for (var r = 0; r < sortedAccounts.length; r++) {
      final a = sortedAccounts[r];
      final values = [a.id, a.username, a.displayName, a.role.name, _encodeAssignments(a.assignments)];
      for (var c = 0; c < values.length; c++) {
        guruSheet
            .cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1))
            .value = xls.TextCellValue(values[c]);
      }
    }

    // Sheet default bawaan `excel` (biasanya "Sheet1") ikut kebuat kalau
    // belum pernah dipakai -- buang biar file yang dibuka admin cuma ada 2
    // sheet yang relevan (Murid & Guru), gak ada sheet kosong nyasar.
    for (final name in [...book.sheets.keys]) {
      if (name != _sheetMurid && name != _sheetGuru) {
        book.delete(name);
      }
    }

    final bytes = book.encode()!;
    return ExportedFile(bytes: Uint8List.fromList(bytes), filename: _filename());
  }

  Future<ExportedFile> saveWorkbook(List<Student> students, List<UserAccount> accounts) {
    final file = buildWorkbook(students, accounts);
    return persistExportedFile(file.filename, file.bytes);
  }

  String _filename() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'data_guru_dan_murid_${now.year}${two(now.month)}${two(now.day)}.xlsx';
  }

  String _encodeAssignments(List<KelasHalaqoh> assignments) =>
      assignments.map((a) => '${a.kelas}:${a.halaqoh}').join('; ');

  List<KelasHalaqoh> _decodeAssignments(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    return trimmed
        .split(';')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .map((part) {
          final idx = part.indexOf(':');
          if (idx < 0) return null; // format gak dikenali, lewatin aman
          final kelas = part.substring(0, idx).trim();
          final halaqoh = normalizeHalaqoh(part.substring(idx + 1).trim());
          if (kelas.isEmpty || halaqoh.isEmpty) return null;
          return KelasHalaqoh(kelas: kelas, halaqoh: halaqoh);
        })
        .whereType<KelasHalaqoh>()
        .toList();
  }

  String _cellText(xls.CellValue? value) {
    if (value == null) return '';
    if (value is xls.TextCellValue) return value.value.toString().trim();
    // Jaga-jaga kalau Excel/Google Sheets otomatis nge-tipe-in sebuah sel
    // -- tetap ambil representasi tekstualnya apa adanya.
    return value.toString().trim();
  }

  /// Parse [bytes] hasil import (2 sheet: Murid & Guru), cocokin ke data
  /// SEKARANG via kolom `id` di masing-masing sheet. TIDAK menulis apa pun
  /// ke Firestore -- murni penghitungan perubahan buat preview. Salah satu
  /// sheet boleh gak ada/kosong (mis. admin cuma mau update murid doang) --
  /// hasilnya sheet itu cuma bakal punya rows kosong, bukan error.
  SchoolDataImportResult parseImport(
    Uint8List bytes, {
    required List<Student> currentStudents,
    required List<UserAccount> currentAccounts,
  }) {
    final book = xls.Excel.decodeBytes(bytes);

    final studentResult = _parseStudents(book, currentStudents);
    final accountResult = _parseAccounts(book, currentAccounts);
    return SchoolDataImportResult(students: studentResult, accounts: accountResult);
  }

  StudentImportResult _parseStudents(xls.Excel book, List<Student> currentStudents) {
    final sheet = book.tables[_sheetMurid];
    if (sheet == null) return const StudentImportResult(rows: [], unknownIds: []);

    final byId = {for (final s in currentStudents) s.id: s};
    final rows = <StudentImportRow>[];
    final unknownIds = <String>[];

    for (var r = 1; r < sheet.maxRows; r++) {
      final row = sheet.row(r);
      if (row.isEmpty) continue;
      String cellAt(int col) => col < row.length ? _cellText(row[col]?.value) : '';

      final id = cellAt(_mColId);
      if (id.isEmpty) continue;
      final nama = cellAt(_mColNama);
      final kelas = cellAt(_mColKelas);
      final halaqoh = cellAt(_mColHalaqoh);

      final current = byId[id];
      if (current == null) {
        unknownIds.add(nama.isEmpty ? id : '$id ($nama)');
        continue;
      }
      if (kelas.isEmpty || halaqoh.isEmpty) continue;

      rows.add(StudentImportRow(current: current, newKelas: kelas, newHalaqoh: normalizeHalaqoh(halaqoh)));
    }

    return StudentImportResult(rows: rows, unknownIds: unknownIds);
  }

  AccountImportResult _parseAccounts(xls.Excel book, List<UserAccount> currentAccounts) {
    final sheet = book.tables[_sheetGuru];
    if (sheet == null) return const AccountImportResult(rows: [], unknownIds: []);

    final byId = {for (final a in currentAccounts) a.id: a};
    final rows = <AccountImportRow>[];
    final unknownIds = <String>[];

    for (var r = 1; r < sheet.maxRows; r++) {
      final row = sheet.row(r);
      if (row.isEmpty) continue;
      String cellAt(int col) => col < row.length ? _cellText(row[col]?.value) : '';

      final id = cellAt(_gColId);
      if (id.isEmpty) continue;
      final username = cellAt(_gColUsername);
      final displayName = cellAt(_gColDisplayName);
      final assignmentsRaw = cellAt(_gColAssignments);

      final current = byId[id];
      if (current == null) {
        unknownIds.add(username.isEmpty ? id : '$id ($username)');
        continue;
      }
      if (displayName.isEmpty) continue;

      rows.add(AccountImportRow(
        current: current,
        newDisplayName: displayName,
        newAssignments: _decodeAssignments(assignmentsRaw),
      ));
    }

    return AccountImportResult(rows: rows, unknownIds: unknownIds);
  }

  /// Generate representasi KODE DART (persis format `kSeedStudentsJson` &
  /// `kSeedAccountsJson` di local_seed_data.dart) dari data TERBARU
  /// (Firestore) -- buat nyegerin fallback seed sebelum build APK versi
  /// berikutnya. SENGAJA cuma teks doang, TIDAK nulis file apa pun otomatis
  /// (app yang jalan di HP gak bisa nulis balik ke source code-nya
  /// sendiri). `passwordHash` guru diikutsertakan APA ADANYA (hash, bukan
  /// plaintext) supaya seed hasil export tetap konsisten sama akun yang
  /// beneran ada sekarang -- developer tinggal copy-paste, gak perlu
  /// reset password siapa pun.
  String buildSeedDartCode(List<Student> students, List<UserAccount> accounts) {
    String esc(String s) => s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

    final sortedStudents = [...students]..sort((a, b) {
        final byKelas = a.kelas.compareTo(b.kelas);
        if (byKelas != 0) return byKelas;
        final byHalaqoh = a.halaqoh.compareTo(b.halaqoh);
        if (byHalaqoh != 0) return byHalaqoh;
        return a.nama.compareTo(b.nama);
      });
    final sortedAccounts = [...accounts]..sort((a, b) => a.displayName.compareTo(b.displayName));

    final buffer = StringBuffer();
    buffer.writeln('// Auto-generated dari data Firestore terbaru lewat "Export sebagai');
    buffer.writeln('// kode seed (.dart)" di Halaman Kelola -- ${DateTime.now().toIso8601String()}.');
    buffer.writeln('// Tempel tiap list di bawah menggantikan isi konstanta yang namanya sama');
    buffer.writeln('// di local_seed_data.dart.');
    buffer.writeln();

    buffer.writeln('const List<Map<String, dynamic>> kSeedAccountsJson = [');
    for (final a in sortedAccounts) {
      final assignmentsLiteral = a.assignments
          .map((x) => "{'kelas': \"${esc(x.kelas)}\", 'halaqoh': \"${esc(x.halaqoh)}\"}")
          .join(', ');
      buffer.writeln(
        '  {\'id\': "${esc(a.id)}", \'username\': "${esc(a.username)}", '
        '\'displayName\': "${esc(a.displayName)}", \'passwordHash\': "${esc(a.passwordHash)}", '
        '\'role\': "${a.role.name}", \'assignments\': [$assignmentsLiteral], '
        '\'schoolId\': "${esc(a.schoolId)}"},',
      );
    }
    buffer.writeln('];');
    buffer.writeln();

    buffer.writeln('const List<Map<String, dynamic>> kSeedStudentsJson = [');
    for (final s in sortedStudents) {
      final schoolIdLiteral = s.schoolId == null ? 'null' : '"${esc(s.schoolId!)}"';
      buffer.writeln(
        '  {\'id\': "${esc(s.id)}", \'nama\': "${esc(s.nama)}", \'kelas\': "${esc(s.kelas)}", '
        '\'halaqoh\': "${esc(s.halaqoh)}", \'schoolId\': $schoolIdLiteral},',
      );
    }
    buffer.writeln('];');

    return buffer.toString();
  }
}
