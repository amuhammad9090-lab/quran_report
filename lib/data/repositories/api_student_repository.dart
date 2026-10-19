import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/utils/app_config.dart';
import '../../core/utils/text_utils.dart';
import '../local_seed/local_seed_data.dart';
import '../models/kelas_halaqoh.dart';
import '../models/student.dart';
import '../models/user_account.dart';
import '../services/app_prefs_service.dart';
import 'api_auth_repository.dart';
import 'student_repository.dart';

part 'api_student_repository_admin.dart';

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
///
/// <-- BERUBAH (audit optimasi Firestore read, ±302 santri):
/// Sebelumnya SETIAP kali [getAll] dipanggil dari cache (praktis tiap
/// kali app dibuka, lihat StudentsProvider.load() di main.dart) DAN
/// setiap kali [refresh] dipanggil manual (mis. buka layar Kelola
/// Murid/Kelola Data), app melakukan full `students.get()` — ±302
/// dokumen dibaca berulang-ulang walau datanya sama sekali tidak
/// berubah. Sekarang ada dua lapis penghematan:
///
/// 1. Cooldown persisten ([_backgroundRefreshInterval], 6 jam) — background
///    sync (dipicu dari [getAll]) di-skip TOTAL (0 Firestore read) kalau
///    belum lewat cooldown sejak sync terakhir yang BERHASIL.
/// 2. Metadata check ([_performRefresh]) — begitu boleh sync (baik lewat
///    cooldown di atas, ATAU manual refresh yang SELALU boleh jalan),
///    yang dibaca duluan cuma 1 dokumen ringan
///    `schools/{id}/metadata/students`. Kalau versinya SAMA dengan versi
///    lokal terakhir, cache Hive dianggap masih valid — TIDAK ada full
///    `students.get()` sama sekali (cuma 1 read, bukan ±302). Full fetch
///    HANYA terjadi kalau versi metadata berubah, metadata belum pernah
///    ada (migration/fallback), atau dipaksa (`force: true`, dipakai
///    [migrateSeedToFirestore]).
///
/// Operasi tulis ([updateKelasHalaqoh], [bulkUpdateKelasHalaqoh]) sudah
/// diubah supaya SELALU ikut menaikkan versi metadata itu (dalam batch
/// atomic yang sama dengan tulis data student-nya) — lihat masing-masing
/// method. Kalau ini tidak dilakukan, device lain (atau device ini
/// sendiri di sesi berikutnya) akan salah kira cache-nya masih valid
/// padahal sudah ada perubahan.
class ApiStudentRepository implements StudentRepository {
  ApiStudentRepository._();
  static final ApiStudentRepository instance = ApiStudentRepository._();

  static const _boxName = 'students_cache';
  Box<String>? _box;
  List<Student>? _memCache;

  /// <-- BARU: jarak minimal antar background sync otomatis (dipicu dari
  /// [getAll], BUKAN dari refresh manual yang ditekan user sendiri —
  /// itu selalu boleh jalan, cuma tetap lewat metadata check di
  /// [_performRefresh]). Contoh perilaku (lihat juga catatan audit):
  /// buka app jam 07:00 -> boleh sync; buka lagi jam 08:00/10:00/12:00
  /// (masih dalam 6 jam) -> tidak sync otomatis; lewat jam 13:00 -> boleh
  /// sync lagi.
  static const _backgroundRefreshInterval = Duration(hours: 6);

  /// <-- BARU: guard "jangan bikin Firestore GET kedua" kalau sync
  /// sedang berlangsung — dipakai bersama oleh background sync maupun
  /// tombol refresh manual (keduanya sama-sama lewat [refresh]), jadi
  /// kalau kebetulan tumpang tindih, caller kedua cukup nebeng nunggu
  /// Future yang sama, bukan bikin request baru.
  Future<List<Student>>? _refreshInFlight;

  Future<Box<String>> _openBox() async {
    if (_box != null) return _box!;
    await Hive.initFlutter();
    return _box = await Hive.openBox<String>(_boxName);
  }

  CollectionReference<Map<String, dynamic>> get _collection => FirebaseFirestore.instance
      .collection('schools')
      .doc(kSchoolId)
      .collection('students');

  /// <-- BARU: dokumen metadata ringan (1 doc, bukan koleksi) buat cek
  /// "ada perubahan data student atau tidak" tanpa perlu baca seluruh
  /// koleksi `students`. Field yang dipakai: `version` (int, epoch ms
  /// client-side saat penulisan — lihat [updateKelasHalaqoh]/
  /// [bulkUpdateKelasHalaqoh]/[_bumpMetadataVersion]).
  DocumentReference<Map<String, dynamic>> get _metaDoc => FirebaseFirestore.instance
      .collection('schools')
      .doc(kSchoolId)
      .collection('metadata')
      .doc('students');

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
    // kalau cache masih kosong) dipakai LANGSUNG buat return cepat, sync
    // yang sebenarnya jalan di BACKGROUND (gak di-await) buat nyegerin
    // cache itu buat pemakaian BERIKUTNYA -- dan cuma jalan kalau memang
    // sudah waktunya (lihat [_refreshInBackgroundIfDue]).
    if (box.isNotEmpty) {
      final cached = box.values
          .map((v) => Student.fromJson(jsonDecode(v) as Map<String, dynamic>))
          .toList();
      _memCache = cached;
      unawaited(_refreshInBackgroundIfDue());
      return cached;
    }

    // Belum ada cache Hive sama sekali (device baru / migrasi belum
    // pernah jalan) -- pakai seed bawaan APK dulu biar app tetap
    // responsif, SAMBIL nyoba sync asli di background.
    final seeded = kSeedStudentsJson.map(Student.fromJson).toList();
    _memCache = seeded;
    unawaited(_refreshInBackgroundIfDue());
    return seeded;
  }

  Future<void> _refreshInBackgroundIfDue() async {
    final lastSync = AppPrefsService.instance.studentsLastSync;
    if (lastSync != null && DateTime.now().difference(lastSync) < _backgroundRefreshInterval) {
      // Cooldown belum lewat -- SKIP TOTAL, tidak ada Firestore read
      // sama sekali (bukan cuma skip full fetch-nya; metadata check di
      // [_performRefresh] pun tidak dipanggil).
      return;
    }
    try {
      await refresh();
    } catch (_) {}
  }

  /// <-- BERUBAH: dulu method ini SELALU melakukan full
  /// `students.get()` (±302 reads) tiap dipanggil. Sekarang lewat
  /// [_performRefresh]: kalau metadata `schools/{id}/metadata/students`
  /// menunjukkan versi yang SAMA dengan versi lokal terakhir, cukup 1
  /// read metadata — TIDAK ada full fetch. Full fetch cuma terjadi kalau
  /// memang ada perubahan (atau [force] = true, ATAU metadata belum
  /// pernah ada sama sekali).
  Future<List<Student>> refresh({bool force = false}) {
    if (!force) {
      final inFlight = _refreshInFlight;
      if (inFlight != null) return inFlight;
    }
    final future = _performRefresh(force: force);
    if (!force) {
      _refreshInFlight = future;
      unawaited(future.whenComplete(() {
        if (identical(_refreshInFlight, future)) {
          _refreshInFlight = null;
        }
      }));
    }
    return future;
  }

  Future<List<Student>> _performRefresh({required bool force}) async {
    final box = await _openBox();

    try {
      int? remoteVersion;
      bool metaMissing = false;

      if (!force) {
        final metaSnap = await _metaDoc.get().timeout(const Duration(seconds: 8));
        remoteVersion = _versionOf(metaSnap);
        metaMissing = !metaSnap.exists;
        final localVersion = AppPrefsService.instance.studentsMetaVersion;

        if (!metaMissing && remoteVersion != null && remoteVersion == localVersion && box.isNotEmpty) {
          // Metadata belum berubah -- cache lokal masih valid. TOTAL
          // Firestore read kali ini cuma 1 (dokumen metadata), BUKAN
          // ±302 (koleksi students).
          await AppPrefsService.instance.setStudentsLastSync(DateTime.now());
          final cached = box.values
              .map((v) => Student.fromJson(jsonDecode(v) as Map<String, dynamic>))
              .toList();
          _memCache = cached;
          return cached;
        }
      }

      // Perlu full fetch: metadata berubah / belum ada / dipaksa / cache
      // lokal kosong.
      final snapshot = await _collection.get().timeout(const Duration(seconds: 10));
      if (snapshot.docs.isNotEmpty) {
        final students = snapshot.docs.map((d) => Student.fromJson(d.data())).toList();
        await box.clear();
        await box.putAll({for (final s in students) s.id: jsonEncode(s.toJson())});
        _memCache = students;

        if (!force) {
          if (metaMissing) {
            // Metadata belum pernah ada sama sekali (mis. belum pernah
            // ada operasi tulis lewat versi baru ini) -- buat sekarang
            // sebagai migration/fallback, SUPAYA refresh berikutnya bisa
            // memakai metadata check ini. Cache TIDAK dianggap valid
            // hanya karena belum ada metadata -- makanya kita tetap full
            // fetch dulu (lihat kondisi di atas), baru buat metadata
            // SESUDAH fetch berhasil.
            await _bumpMetadataVersion();
          } else if (remoteVersion != null) {
            await AppPrefsService.instance.setStudentsMetaVersion(remoteVersion);
          }
        }
        await AppPrefsService.instance.setStudentsLastSync(DateTime.now());
        return students;
      }
    } catch (_) {
      // Offline/timeout/belum ada koneksi -- lanjut ke fallback di bawah,
      // JANGAN dilempar ke pemanggil (autocomplete/Profile tetap harus
      // dapat sesuatu buat ditampilkan, bukan error), dan JANGAN update
      // lastSync/metaVersion (supaya begitu koneksi balik, sync
      // berikutnya tetap dicoba lagi, bukan malah nunggu cooldown penuh
      // dari percobaan yang gagal).
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

  int? _versionOf(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists) return null;
    final data = snap.data();
    final version = data?['version'];
    if (version is int) return version;
    // Backward-compat kalau suatu saat field-nya `updatedAt` (Timestamp)
    // alih-alih `version` (int) -- lihat catatan BAGIAN B spesifikasi
    // audit ("updatedAt atau version").
    final updatedAt = data?['updatedAt'];
    if (updatedAt is Timestamp) return updatedAt.millisecondsSinceEpoch;
    return null;
  }

  /// Buat/perbarui dokumen metadata ke versi (epoch ms) SEKARANG, lalu
  /// simpan nilainya lokal juga -- dipakai saat metadata belum pernah
  /// ada sama sekali (migration/fallback di [_performRefresh]) atau
  /// setelah [migrateSeedToFirestore].
  Future<void> _bumpMetadataVersion() async {
    final version = DateTime.now().millisecondsSinceEpoch;
    await _metaDoc.set({'version': version}).timeout(const Duration(seconds: 10));
    await AppPrefsService.instance.setStudentsMetaVersion(version);
  }
}
