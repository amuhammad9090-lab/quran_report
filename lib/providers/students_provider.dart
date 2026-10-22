import 'dart:async';

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
      : _repo = repository ?? ApiStudentRepository.instance {
    // Refresh latar belakang repo selesai -> muat ulang, supaya daftar siswa terbaru langsung tampil.
    if (repository == null) {
      ApiStudentRepository.instance.onRefreshed = () => unawaited(load());
    }
  }

  final StudentRepository _repo;
  List<Student> _all = [];

  List<Student> get all => _all;

  Future<void> load() async {
    _all = await _repo.getAll();
    notifyListeners();
  }

  /// Cek data siswa terbaru di cloud SEKARANG (tanpa menunggu jendela 6 jam), lalu muat ulang.
  /// Murah: 1 read dokumen metadata; daftar siswa penuh baru diunduh kalau memang berubah. Dipanggil
  /// saat app dibuka, login, dan penugasan guru berubah, supaya label halaqoh tak basi.
  Future<void> refreshFromCloud() async {
    final repo = _repo;
    if (repo is ApiStudentRepository) {
      try {
        await repo.refresh();
      } catch (_) {}
    }
    await load();
  }

  /// Santri yang boleh diakses [scope] (null/admin = semua).
  List<Student> accessibleFor(AccessScope? scope) =>
      scope == null ? _all : scope.scopeStudents(_all);
}
