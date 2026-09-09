import 'package:flutter/material.dart';

import '../core/access/access_scope.dart';
import '../data/models/student.dart';
import '../data/repositories/api_student_repository.dart';
import '../data/repositories/student_repository.dart';

/// Data master santri (bukan laporan) — sumber untuk autocomplete di
/// form laporan & hitung "santri yang diampu" di Profile.
class StudentsProvider extends ChangeNotifier {
  // <-- BERUBAH: default-nya sekarang [ApiStudentRepository] (Firestore +
  // cache Hive lokal, fallback ke seed kalau offline/belum pernah
  // online) -- bukan lagi [LocalStudentRepository] (seed doang, gak bisa
  // diedit tanpa build ulang APK). Lihat catatan lengkap di
  // ApiStudentRepository.
  StudentsProvider({StudentRepository? repository})
      : _repo = repository ?? ApiStudentRepository.instance;

  final StudentRepository _repo;
  List<Student> _all = [];

  List<Student> get all => _all;

  Future<void> load() async {
    _all = await _repo.getAll();
    notifyListeners();
  }

  /// Santri yang boleh diakses [scope] (null/admin = semua).
  List<Student> accessibleFor(AccessScope? scope) =>
      scope == null ? _all : scope.scopeStudents(_all);
}
