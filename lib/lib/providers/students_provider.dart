import 'package:flutter/material.dart';

import '../core/access/access_scope.dart';
import '../data/models/student.dart';
import '../data/repositories/local_student_repository.dart';
import '../data/repositories/student_repository.dart';

/// Data master santri (bukan laporan) — sumber untuk autocomplete di
/// form laporan & hitung "santri yang diampu" di Profile.
class StudentsProvider extends ChangeNotifier {
  StudentsProvider({StudentRepository? repository})
      : _repo = repository ?? LocalStudentRepository();

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
