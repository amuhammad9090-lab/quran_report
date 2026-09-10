import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/utils/app_config.dart';
import '../local_seed/local_seed_data.dart';
import '../models/student.dart';
import 'student_repository.dart';

/// Data master murid, sumbernya Firestore (`schools/{id}/students`) —
/// PENGGANTI [LocalStudentRepository] biar kelas/halaqoh (mis. santri
/// Tahsin naik ke Tahfizh, pindah halaqoh) bisa diedit admin dari dalam
/// app, TANPA perlu build ulang APK.
///
/// [getAll] sengaja one-shot `.get()` (BUKAN listener `.snapshots()` —
/// lihat catatan boros di ParentNoteService.watchAll), lalu di-cache ke
/// Hive lokal supaya:
/// 1. App tetap bisa dipakai offline (autocomplete form laporan, hitung
///    "santri yang diampu") pakai data hasil fetch TERAKHIR yang sukses.
/// 2. Gak fetch ulang dari Firestore tiap kali provider di-load — cukup
///    sekali per proses app (di-cache in-memory juga), refresh
///    berikutnya lewat [refresh] (dipanggil manual, bukan otomatis).
///
/// Fallback berlapis kalau Firestore gagal/timeout DAN belum ada cache
/// Hive sama sekali (device baru / migrasi belum pernah jalan sekali
/// pun): pakai [kSeedStudentsJson] bawaan APK, biar app tidak pernah
/// benar-benar kosong datanya.
class ApiStudentRepository implements StudentRepository {
  ApiStudentRepository._();
  static final ApiStudentRepository instance = ApiStudentRepository._();

  static const _boxName = 'students_cache';
  Box<String>? _box;
  List<Student>? _memCache;

  Future<Box<String>> _openBox() async {
    if (_box != null) return _box!;
    await Hive.initFlutter();
    return _box = await Hive.openBox<String>(_boxName);
  }

  CollectionReference<Map<String, dynamic>> get _collection => FirebaseFirestore.instance
      .collection('schools')
      .doc(kSchoolId)
      .collection('students');

  @override
  Future<List<Student>> getAll() async {
    if (_memCache != null) return _memCache!;

    final box = await _openBox();

    // <-- PENTING: [getAll] TIDAK menunggu Firestore. Ini dipanggil dari
    // StudentsProvider.load() yang antara lain jalan SEBELUM runApp()
    // lewat restoreSession-nya AuthProvider (lihat main.dart) -- kalau
    // di sini nunggu network dulu, bug "app lambat kebuka pas sinyal
    // jelek" yang baru dibenerin (lihat catatan di main.dart) bakal balik
    // lagi, cuma pindah penyebab doang. Jadi: cache Hive (atau seed
    // kalau cache masih kosong) dipakai LANGSUNG buat return cepat, fetch
    // Firestore yang sebenarnya jalan di BACKGROUND (gak di-await) buat
    // nyegerin cache itu buat pemakaian BERIKUTNYA.
    if (box.isNotEmpty) {
      final cached = box.values
          .map((v) => Student.fromJson(jsonDecode(v) as Map<String, dynamic>))
          .toList();
      _memCache = cached;
      unawaited(_refreshInBackground());
      return cached;
    }

    // Belum ada cache Hive sama sekali (device baru / migrasi belum
    // pernah jalan) -- pakai seed bawaan APK dulu biar app tetap
    // responsif, SAMBIL nyoba fetch asli di background.
    final seeded = kSeedStudentsJson.map(Student.fromJson).toList();
    _memCache = seeded;
    unawaited(_refreshInBackground());
    return seeded;
  }

  Future<void> _refreshInBackground() async {
    try {
      await refresh();
    } catch (_) {}
  }

  /// Paksa fetch ulang dari Firestore DAN TUNGGU hasilnya (dipanggil
  /// eksplisit — mis. saat admin buka layar "Kelola Data Murid" [supaya
  /// lihat data terbaru sebelum edit], atau tombol refresh manual.
  /// BUKAN dipanggil dari [getAll]/startup, lihat catatan di atas).
  Future<List<Student>> refresh() async {
    final box = await _openBox();

    try {
      final snapshot = await _collection.get().timeout(const Duration(seconds: 10));
      if (snapshot.docs.isNotEmpty) {
        final students = snapshot.docs.map((d) => Student.fromJson(d.data())).toList();
        await box.clear();
        await box.putAll({for (final s in students) s.id: jsonEncode(s.toJson())});
        _memCache = students;
        return students;
      }
    } catch (_) {
      // Offline/timeout/belum ada koneksi -- lanjut ke fallback di bawah,
      // JANGAN dilempar ke pemanggil (autocomplete/Profile tetap harus
      // dapat sesuatu buat ditampilkan, bukan error).
    }

    if (box.isNotEmpty) {
      final cached = box.values
          .map((v) => Student.fromJson(jsonDecode(v) as Map<String, dynamic>))
          .toList();
      _memCache = cached;
      return cached;
    }

    // Fallback terakhir: seed bawaan APK (device baru / migrasi belum
    // pernah dijalankan admin sama sekali).
    final seeded = kSeedStudentsJson.map(Student.fromJson).toList();
    _memCache = seeded;
    return seeded;
  }

  /// Ubah kelas/halaqoh satu santri (mis. naik dari Tahsin ke Tahfizh).
  /// HANYA dipanggil dari layar admin (Kelola Data Murid) — pengecekan
  /// role dilakukan di layer UI, bukan di sini.
  Future<void> updateKelasHalaqoh(
    Student student, {
    required String kelas,
    required String halaqoh,
  }) async {
    final updated = Student(
      id: student.id,
      nama: student.nama,
      kelas: kelas,
      halaqoh: halaqoh,
      schoolId: student.schoolId,
    );

    await _collection.doc(student.id).set(updated.toJson()).timeout(const Duration(seconds: 15));

    final box = await _openBox();
    await box.put(student.id, jsonEncode(updated.toJson()));

    if (_memCache != null) {
      _memCache = [for (final s in _memCache!) if (s.id == student.id) updated else s];
    }
  }

  /// Ubah kelas/halaqoh BANYAK santri sekaligus (dipakai admin dari
  /// import Excel di Halaman Kelola, sesudah preview & konfirmasi --
  /// BUKAN dari input bebas). Batched biar aman buat ratusan santri
  /// sekaligus (limit 500 operasi per batch WriteBatch Firestore, sama
  /// pola batch-nya kayak [migrateSeedToFirestore]).
  Future<int> bulkUpdateKelasHalaqoh(List<Student> updatedStudents) async {
    if (updatedStudents.isEmpty) return 0;
    const batchSize = 400;
    var written = 0;

    for (var i = 0; i < updatedStudents.length; i += batchSize) {
      final end = (i + batchSize > updatedStudents.length) ? updatedStudents.length : i + batchSize;
      final chunk = updatedStudents.sublist(i, end);

      final batch = FirebaseFirestore.instance.batch();
      for (final s in chunk) {
        batch.set(_collection.doc(s.id), s.toJson());
      }
      await batch.commit().timeout(const Duration(seconds: 20));
      written += chunk.length;
    }

    final box = await _openBox();
    for (final s in updatedStudents) {
      await box.put(s.id, jsonEncode(s.toJson()));
    }
    if (_memCache != null) {
      final byId = {for (final s in updatedStudents) s.id: s};
      _memCache = [for (final s in _memCache!) byId[s.id] ?? s];
    }

    return written;
  }

  /// Migrasi SEKALI-JALAN: tulis seluruh [kSeedStudentsJson] ke
  /// Firestore. Aman dipencet berkali-kali (upsert per id lewat `.set`,
  /// bukan nambah dobel) — dipanggil dari tombol admin di Settings.
  Future<int> migrateSeedToFirestore() async {
    final students = kSeedStudentsJson.map(Student.fromJson).toList();
    const batchSize = 400;
    var written = 0;

    for (var i = 0; i < students.length; i += batchSize) {
      final end = (i + batchSize > students.length) ? students.length : i + batchSize;
      final chunk = students.sublist(i, end);

      final batch = FirebaseFirestore.instance.batch();
      for (final s in chunk) {
        batch.set(_collection.doc(s.id), s.toJson());
      }
      await batch.commit().timeout(const Duration(seconds: 20));
      written += chunk.length;
    }

    // Langsung seger-in cache Hive & in-memory juga, biar gak perlu
    // nunggu refresh berikutnya buat lihat hasilnya.
    final box = await _openBox();
    await box.clear();
    await box.putAll({for (final s in students) s.id: jsonEncode(s.toJson())});
    _memCache = students;

    return written;
  }
}
