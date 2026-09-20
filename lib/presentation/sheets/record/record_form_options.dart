import '../../../core/access/access_scope.dart';
import '../../../providers/records_provider.dart';
import '../../../providers/students_provider.dart';

/// Opsi dropdown Kelas/Halaqoh/Nama Anak pada form laporan. Bila [restrictToOwn] (guru pembimbing,
/// atau admin yang Mode Admin-nya nonaktif) opsi dibatasi ke assignment akun; selain itu gabungan
/// riwayat laporan dan master santri yang boleh diakses.
class RecordFormOptions {
  final AccessScope? scope;
  final bool restrictToOwn;
  final RecordsProvider dataset;
  final StudentsProvider students;

  const RecordFormOptions({
    required this.scope,
    required this.restrictToOwn,
    required this.dataset,
    required this.students,
  });

  List<String> kelas() {
    final accessibleStudents = students.accessibleFor(scope);
    if (restrictToOwn) {
      return (scope!.user.assignments.map((a) => a.kelas).toSet().toList()..sort());
    }
    return ({...dataset.distinctKelas, ...accessibleStudents.map((s) => s.kelas)}.toList()..sort());
  }

  // PENTING: kelas & halaqoh adalah PASANGAN per assignment (lihat KelasHalaqoh), jadi opsi
  // halaqoh dipengaruhi kelas yang dipilih ([kelas]), bukan gabungan semua halaqoh user.
  List<String> halaqoh(String? kelas) {
    final accessibleStudents = students.accessibleFor(scope);
    if (restrictToOwn) {
      final validForKelas = scope!.user.assignments
          .where((a) => a.kelas == kelas)
          .map((a) => a.halaqoh)
          .toList();
      // Kelas belum dipilih/cocok -> tampilkan union halaqoh semua assignment agar dropdown tak
      // kosong; begitu kelas valid dipilih otomatis menyempit ke halaqoh yang berpasangan.
      return validForKelas.isNotEmpty
          ? validForKelas
          : (scope!.user.assignments.map((a) => a.halaqoh).toSet().toList()..sort());
    }
    return ({...dataset.distinctHalaqoh, ...accessibleStudents.map((s) => s.halaqoh)}.toList()..sort());
  }

  /// Nama santri: kelas & halaqoh HARUS dipilih dulu; isinya gabungan riwayat laporan (sudah
  /// discope lewat RecordsProvider) dan master santri assignment ini, jadi santri yang belum
  /// pernah dilaporkan tetap bisa dipilih tanpa menampilkan santri kelas/halaqoh lain.
  List<String> nama(String? kelas, String? halaqoh) {
    if (kelas == null || kelas.trim().isEmpty || halaqoh == null || halaqoh.trim().isEmpty) {
      return const [];
    }
    final accessibleStudents = students.accessibleFor(scope);
    final names = <String>{
      ...accessibleStudents
          .where((s) => s.kelas == kelas && s.halaqoh == halaqoh)
          .map((s) => s.nama),
      ...dataset.all
          .where((r) => r.kelas == kelas && r.halaqoh == halaqoh)
          .map((r) => r.namaAnak),
    };
    return names.toList()..sort();
  }
}
