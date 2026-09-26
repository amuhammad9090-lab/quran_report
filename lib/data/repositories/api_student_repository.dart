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

  /// Cek Firestore & sinkronkan cache Hive kalau perlu (dipanggil
  /// eksplisit — mis. admin buka layar "Kelola Data Murid"/"Kelola
  /// Murid" [supaya lihat data terbaru sebelum edit], tombol refresh
  /// manual, ATAU dari background sync di [_refreshInBackgroundIfDue]
  /// kalau cooldown-nya sudah lewat).
  ///
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

  /// <-- BERUBAH (bug fix): dulu method ini nelan SEMUA error dari
  /// [ApiAuthRepository.refresh] diam-diam dan return `[]` -- niatnya
  /// "aman", TAPI akibatnya kebalik: [_matchGuruAccountId] dipanggil
  /// dengan list KOSONG selalu balikin `null`, jadi tiap kali resolusi
  /// ini gagal (offline/timeout/permission-denied sesaat), SEMUA santri
  /// yang lagi ditulis (updateKelasHalaqoh/bulkUpdateKelasHalaqoh) ikut
  /// KETIMPA `guruAccountId: null` -- padahal sebelumnya sudah benar --
  /// TANPA ada error apa pun yang kelihatan ke admin. Ini yang bikin
  /// santri yang guru pembimbingnya sudah di-assign tetap balik null.
  ///
  /// Sekarang: error DILEMPAR APA ADANYA ke pemanggil (updateKelasHalaqoh/
  /// bulkUpdateKelasHalaqoh/migrateSeedToFirestore/resyncAllGuruAccountIds)
  /// -- masing-masing yang mutuskan cara aman buat handle-nya (biasanya:
  /// PERTAHANKAN guruAccountId lama, JANGAN ditimpa null, lalu tetap
  /// kasih tau admin lewat exception supaya tidak senyap).
  Future<List<UserAccount>> _accountsForGuruResolution() {
    return ApiAuthRepository.instance.refresh();
  }

  /// Cocokkan [kelas]+[halaqoh] ke SATU akun guru dari [accounts] (hasil
  /// [_accountsForGuruResolution]) lewat [KelasHalaqoh.==] (yang sudah menormalisasi
  /// [halaqoh], lihat KelasHalaqoh.fromJson) -- BUKAN `arrayContains` Firestore, supaya
  /// tidak rapuh kalau ejaan halaqoh di assignment guru & di data santri beda kapitalisasi
  /// /spasi. Fakta "1 halaqoh = 1 guru" (dikonfirmasi user) berarti hasilnya seharusnya
  /// selalu 0 atau 1 kecocokan -- kalau ternyata >1 (data tidak konsisten), yang dipakai
  /// yang PERTAMA ketemu, bukan error, supaya penyimpanan kelas/halaqoh tetap jalan.
  String? _matchGuruAccountId(List<UserAccount> accounts, String kelas, String halaqoh) {
    final target = KelasHalaqoh(kelas: kelas, halaqoh: normalizeHalaqoh(halaqoh));
    for (final acc in accounts) {
      if (acc.assignments.contains(target)) return acc.id;
    }
    return null;
  }

  /// Ubah kelas/halaqoh satu santri (mis. naik dari Tahsin ke Tahfizh).
  /// HANYA dipanggil dari layar admin (Kelola Data Murid) — pengecekan
  /// role dilakukan di layer UI, bukan di sini.
  ///
  /// <-- BERUBAH: sekarang menaikkan versi metadata (`schools/{id}/
  /// metadata/students`) DALAM SATU BATCH ATOMIC yang sama dengan tulis
  /// data student-nya (BAGIAN C audit) -- supaya tidak pernah ada
  /// kondisi "student berubah tapi metadata tidak", yang bisa membuat
  /// device lain (atau device ini sendiri sesi berikutnya) salah kira
  /// cache-nya masih up-to-date.
  ///
  /// <-- BERUBAH (bug fix, lihat [_accountsForGuruResolution]): kalau
  /// resolusi akun guru gagal (offline/permission-denied sesaat),
  /// kelas/halaqoh TETAP disimpan (itu yang diminta admin), tapi
  /// `guruAccountId` LAMA dipertahankan APA ADANYA -- BUKAN ditimpa
  /// `null` seperti sebelumnya -- lalu method ini tetap melempar error
  /// di akhir supaya admin TAHU perlu simpan ulang nanti (bukan senyap).
  Future<void> updateKelasHalaqoh(
    Student student, {
    required String kelas,
    required String halaqoh,
  }) async {
    List<UserAccount> accounts = const [];
    Object? resolutionError;
    try {
      accounts = await _accountsForGuruResolution();
    } catch (e) {
      resolutionError = e;
    }

    final updated = Student(
      id: student.id,
      nama: student.nama,
      kelas: kelas,
      halaqoh: halaqoh,
      schoolId: student.schoolId,
      guruAccountId: resolutionError == null
          ? _matchGuruAccountId(accounts, kelas, halaqoh)
          : student.guruAccountId,
    );

    final version = DateTime.now().millisecondsSinceEpoch;
    final batch = FirebaseFirestore.instance.batch();
    batch.set(_collection.doc(student.id), updated.toJson());
    batch.set(_metaDoc, {'version': version});
    await batch.commit().timeout(const Duration(seconds: 15));

    final box = await _openBox();
    await box.put(student.id, jsonEncode(updated.toJson()));
    await AppPrefsService.instance.setStudentsMetaVersion(version);
    await AppPrefsService.instance.setStudentsLastSync(DateTime.now());

    if (_memCache != null) {
      _memCache = [for (final s in _memCache!) if (s.id == student.id) updated else s];
    }

    if (resolutionError != null) {
      throw StateError(
        'Kelas/halaqoh tersimpan, tapi guru pembimbing gagal disinkron ($resolutionError). '
        'guruAccountId lama dipertahankan -- coba simpan ulang nanti.',
      );
    }
  }

  /// Ubah kelas/halaqoh BANYAK santri sekaligus (dipakai admin dari
  /// import Excel di Halaman Kelola, sesudah preview & konfirmasi --
  /// BUKAN dari input bebas). Batched biar aman buat ratusan santri
  /// sekaligus (limit 500 operasi per batch WriteBatch Firestore, sama
  /// pola batch-nya kayak [migrateSeedToFirestore]).
  ///
  /// <-- BERUBAH: chunk TERAKHIR ikut menaikkan versi metadata dalam
  /// batch atomic yang sama (sama alasannya seperti [updateKelasHalaqoh]
  /// di atas — BAGIAN C audit). Sengaja TIDAK bulk-rewrite 302 students
  /// cuma buat migrasi metadata (lihat [_performRefresh]/
  /// [_bumpMetadataVersion] yang menangani kasus "metadata belum ada"
  /// secara terpisah, lewat 1 dokumen kecil, bukan nulis ulang semua
  /// student).
  ///
  /// <-- BERUBAH (bug fix, lihat [_accountsForGuruResolution]): kalau
  /// resolusi akun guru gagal, kelas/halaqoh tiap santri TETAP disimpan
  /// apa adanya, tapi `guruAccountId` masing-masing dipertahankan ke
  /// nilai LAMA-nya (bukan `null`) -- ini yang dipanggil reconcile di
  /// KelolaGuruScreen tiap assignment guru diedit, jadi kalau ini
  /// senyap nulis null, guru pembimbing yang BARU SAJA di-assign gak
  /// pernah ke-reflect ke Portal Ortu tanpa admin pernah tahu kenapa.
  /// Method ini tetap melempar error di akhir kalau resolusinya gagal,
  /// supaya pemanggil (reconcile/import Excel) bisa kasih tau admin.
  Future<int> bulkUpdateKelasHalaqoh(List<Student> updatedStudents) async {
    if (updatedStudents.isEmpty) return 0;
    const batchSize = 400;
    var written = 0;
    final version = DateTime.now().millisecondsSinceEpoch;

    List<UserAccount> accounts = const [];
    Object? resolutionError;
    try {
      accounts = await _accountsForGuruResolution();
    } catch (e) {
      resolutionError = e;
    }

    updatedStudents = [
      for (final s in updatedStudents)
        Student(
          id: s.id,
          nama: s.nama,
          kelas: s.kelas,
          halaqoh: s.halaqoh,
          schoolId: s.schoolId,
          guruAccountId: resolutionError == null
              ? _matchGuruAccountId(accounts, s.kelas, s.halaqoh)
              : s.guruAccountId,
        ),
    ];

    for (var i = 0; i < updatedStudents.length; i += batchSize) {
      final end = (i + batchSize > updatedStudents.length) ? updatedStudents.length : i + batchSize;
      final chunk = updatedStudents.sublist(i, end);
      final isLastChunk = end == updatedStudents.length;

      final batch = FirebaseFirestore.instance.batch();
      for (final s in chunk) {
        batch.set(_collection.doc(s.id), s.toJson());
      }
      if (isLastChunk) {
        batch.set(_metaDoc, {'version': version});
      }
      await batch.commit().timeout(const Duration(seconds: 20));
      written += chunk.length;
    }

    final box = await _openBox();
    for (final s in updatedStudents) {
      await box.put(s.id, jsonEncode(s.toJson()));
    }
    await AppPrefsService.instance.setStudentsMetaVersion(version);
    await AppPrefsService.instance.setStudentsLastSync(DateTime.now());
    if (_memCache != null) {
      final byId = {for (final s in updatedStudents) s.id: s};
      _memCache = [for (final s in _memCache!) byId[s.id] ?? s];
    }

    if (resolutionError != null) {
      throw StateError(
        'Kelas/halaqoh $written santri tersimpan, tapi guru pembimbing gagal disinkron '
        '($resolutionError). guruAccountId lama dipertahankan -- coba lagi nanti, atau '
        'pakai "Sinkronkan Guru Pembimbing" di Kelola Guru.',
      );
    }

    return written;
  }

  /// Migrasi SEKALI-JALAN: tulis [kSeedStudentsJson] ke Firestore.
  ///
  /// PENTING (fix): id yang SUDAH ADA di Firestore (mis. sudah pernah
  /// di-migrasi sebelumnya, diedit lewat Kelola Murid, atau diupdate
  /// lewat Import Excel di Halaman Kelola) SENGAJA DILEWATIN -- cuma id
  /// yang BELUM ADA sama sekali yang ditulis. Ini yang bikin tombol ini
  /// aman dipencet berkali-kali TANPA nimpa balik ke data lama (sebelum
  /// fix ini, migrate nulis ulang SEMUA id dari seed tiap kali dipencet,
  /// jadi kalau dipencet SESUDAH ada perubahan dari Kelola Murid/Import,
  /// perubahan itu ketimpa balik ke nilai seed yang lama).
  ///
  /// <-- BERUBAH: kalau ada id baru yang ditulis, metadata dinaikkan
  /// (BAGIAN C), lalu cache di-refresh paksa (`force: true`) -- BUKAN
  /// lewat metadata check biasa, karena metadata yang barusan kita set
  /// sendiri di sini tidak boleh membuat [refresh] mengira "tidak ada
  /// perubahan" dan melewatkan full fetch yang justru diperlukan supaya
  /// cache mencerminkan data Firestore yang SEBENARNYA (termasuk
  /// perubahan dari Kelola Murid/Import yang sengaja tidak ikut ditulis
  /// ulang di atas).
  Future<int> migrateSeedToFirestore() async {
    final seedStudents = kSeedStudentsJson.map(Student.fromJson).toList();

    final snapshot = await _collection.get().timeout(const Duration(seconds: 15));
    final existingIds = snapshot.docs.map((d) => d.id).toSet();

    // <-- BERUBAH (bug fix, lihat _accountsForGuruResolution): dokumen yang
    // ditulis di sini SELALU baru (id yang sudah ada di-skip di atas), jadi
    // tidak ada guruAccountId lama yang bisa "ketimpa" -- tapi errornya
    // tetap dilempar di akhir (bukan ditelan) supaya admin tahu perlu
    // resync manual kalau resolusi guru gagal pas migrasi ini jalan.
    List<UserAccount> accounts = const [];
    Object? resolutionError;
    try {
      accounts = await _accountsForGuruResolution();
    } catch (e) {
      resolutionError = e;
    }
    final toWrite = [
      for (final s in seedStudents)
        if (!existingIds.contains(s.id))
          Student(
            id: s.id,
            nama: s.nama,
            kelas: s.kelas,
            halaqoh: s.halaqoh,
            schoolId: s.schoolId,
            guruAccountId: _matchGuruAccountId(accounts, s.kelas, s.halaqoh),
          ),
    ];

    const batchSize = 400;
    for (var i = 0; i < toWrite.length; i += batchSize) {
      final end = (i + batchSize > toWrite.length) ? toWrite.length : i + batchSize;
      final chunk = toWrite.sublist(i, end);

      final batch = FirebaseFirestore.instance.batch();
      for (final s in chunk) {
        batch.set(_collection.doc(s.id), s.toJson());
      }
      await batch.commit().timeout(const Duration(seconds: 20));
    }

    if (toWrite.isNotEmpty) {
      await _bumpMetadataVersion();
    }

    // Seger-in cache dari Firestore YANG SEBENARNYA (bukan cuma daftar
    // seed) -- biar konsisten sama data yang beneran ada sekarang,
    // termasuk perubahan dari Kelola Murid/Import yang gak ikut ditulis
    // ulang di atas.
    await refresh(force: true);

    if (resolutionError != null) {
      throw StateError(
        '${toWrite.length} santri baru tersimpan, tapi guru pembimbing gagal disinkron '
        '($resolutionError) -- pakai "Sinkronkan Guru Pembimbing" di Kelola Guru setelah ini.',
      );
    }

    return toWrite.length;
  }

  /// <-- BARU: backfill SEKALI-JALAN buat SEMUA santri (bukan cuma yang
  /// "kena dampak" edit assignment terakhir seperti reconcile di
  /// KelolaGuruScreen). Nutup 2 celah: (1) assignment guru yang dibuat
  /// SEBELUM reconcile itu ada di kode, jadi tidak pernah ke-backfill
  /// otomatis; (2) santri yang guruAccountId-nya sempat ke-null-kan gara-
  /// gara [_accountsForGuruResolution] dulu gagal senyap (lihat riwayat
  /// bug di sana). Dipanggil manual dari tombol admin di Kelola Guru --
  /// BUKAN otomatis, karena baca+tulis semua santri sekaligus.
  ///
  /// Sengaja BUKAN percobaan "aman" kalau resolusi gagal: kalau
  /// [_accountsForGuruResolution] gagal di sini, method ini LANGSUNG
  /// melempar error TANPA menulis apa pun -- beda dari
  /// [updateKelasHalaqoh]/[bulkUpdateKelasHalaqoh] yang harus tetap
  /// menyimpan kelas/halaqoh yang memang diminta admin. Di sini TIDAK
  /// ada perubahan kelas/halaqoh yang "wajib tersimpan" -- satu-satunya
  /// tujuan method ini MEMANG resolusi guru, jadi kalau itu gagal, lebih
  /// aman batal total daripada menulis ulang ratusan santri dengan data
  /// yang salah/null.
  Future<int> resyncAllGuruAccountIds() async {
    final accounts = await _accountsForGuruResolution();
    final students = await refresh(force: true);

    final changed = <Student>[];
    for (final s in students) {
      final resolved = _matchGuruAccountId(accounts, s.kelas, s.halaqoh);
      if (resolved != s.guruAccountId) {
        changed.add(Student(
          id: s.id,
          nama: s.nama,
          kelas: s.kelas,
          halaqoh: s.halaqoh,
          schoolId: s.schoolId,
          guruAccountId: resolved,
        ));
      }
    }

    if (changed.isEmpty) return 0;

    const batchSize = 400;
    final version = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < changed.length; i += batchSize) {
      final end = (i + batchSize > changed.length) ? changed.length : i + batchSize;
      final chunk = changed.sublist(i, end);
      final isLastChunk = end == changed.length;

      final batch = FirebaseFirestore.instance.batch();
      for (final s in chunk) {
        batch.set(_collection.doc(s.id), s.toJson());
      }
      if (isLastChunk) {
        batch.set(_metaDoc, {'version': version});
      }
      await batch.commit().timeout(const Duration(seconds: 20));
    }

    final box = await _openBox();
    for (final s in changed) {
      await box.put(s.id, jsonEncode(s.toJson()));
    }
    await AppPrefsService.instance.setStudentsMetaVersion(version);
    await AppPrefsService.instance.setStudentsLastSync(DateTime.now());
    if (_memCache != null) {
      final byId = {for (final s in changed) s.id: s};
      _memCache = [for (final s in _memCache!) byId[s.id] ?? s];
    }

    return changed.length;
  }
}
