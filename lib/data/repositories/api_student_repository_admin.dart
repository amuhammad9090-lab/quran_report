part of 'api_student_repository.dart';

/// Operasi tulis ADMIN pada data siswa (ubah kelas/halaqoh, hapus, migrasi seed, resync guru).
/// Dipisah dari [ApiStudentRepository] supaya file tidak membengkak; API pemanggil TIDAK berubah.
extension ApiStudentRepositoryAdminOps on ApiStudentRepository {
  /// Sekarang: error DILEMPAR APA ADANYA ke pemanggil (updateKelasHalaqoh/
  /// bulkUpdateKelasHalaqoh/migrateSeedToFirestore/resyncAllGuruAccountIds)
  /// -- masing-masing yang mutuskan cara aman buat handle-nya (biasanya:
  /// PERTAHANKAN guruAccountId lama, JANGAN ditimpa null, lalu tetap
  /// kasih tau admin lewat exception supaya tidak senyap).
  Future<List<UserAccount>> _accountsForGuruResolution() {
    return ApiAuthRepository.instance.refresh();
  }

  /// <-- BERUBAH: dulu cuma balikin `String? accountId` (nama method lama:
  /// `_matchGuruAccountId`). Sekarang balikin [UserAccount]-nya UTUH supaya
  /// pemanggil bisa sekalian ambil [UserAccount.displayName] buat field
  /// [Student.guruNama] (denormalisasi nama guru pembimbing ke
  /// `students/{id}` -- Portal Ortu tidak boleh baca dokumen
  /// `accounts/{accountId}` langsung, lihat firestore.rules). SATU kali
  /// pencarian buat id & nama sekaligus -- bukan 2 method terpisah yang bisa
  /// beda hasil kalau `accounts` berubah di antara 2 panggilan.
  UserAccount? _matchGuruAccount(List<UserAccount> accounts, String kelas, String halaqoh) {
    final target = KelasHalaqoh(kelas: kelas, halaqoh: normalizeHalaqoh(halaqoh));
    for (final acc in accounts) {
      if (acc.assignments.contains(target)) return acc;
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

    final matchedAccount = resolutionError == null ? _matchGuruAccount(accounts, kelas, halaqoh) : null;
    final updated = Student(
      id: student.id,
      nama: student.nama,
      kelas: kelas,
      halaqoh: halaqoh,
      schoolId: student.schoolId,
      guruAccountId: resolutionError == null ? matchedAccount?.id : student.guruAccountId,
      guruNama: resolutionError == null ? matchedAccount?.displayName : student.guruNama,
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
        () {
          final matchedAccount = resolutionError == null ? _matchGuruAccount(accounts, s.kelas, s.halaqoh) : null;
          return Student(
            id: s.id,
            nama: s.nama,
            kelas: s.kelas,
            halaqoh: s.halaqoh,
            schoolId: s.schoolId,
            guruAccountId: resolutionError == null ? matchedAccount?.id : s.guruAccountId,
            guruNama: resolutionError == null ? matchedAccount?.displayName : s.guruNama,
          );
        }(),
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
        'Kelas/halaqoh $written siswa tersimpan, tapi guru pembimbing gagal disinkron '
        '($resolutionError). guruAccountId lama dipertahankan -- coba lagi nanti, atau '
        'pakai "Sinkronkan Guru Pembimbing" di Kelola Guru.',
      );
    }

    return written;
  }

  /// Hapus satu santri dari data master (dokumen `students/{id}` + cache lokal) dan naikkan versi
  /// metadata dalam satu batch, supaya device lain ikut menarik daftar terbaru.
  /// Laporan harian yang sudah ditulis guru TIDAK ikut terhapus (laporan memang berdiri sendiri).
  Future<void> deleteStudent(Student student) async {
    final version = DateTime.now().millisecondsSinceEpoch;
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_collection.doc(student.id));
    batch.set(_metaDoc, {'version': version});
    await batch.commit().timeout(const Duration(seconds: 15));

    final box = await _openBox();
    await box.delete(student.id);
    await AppPrefsService.instance.setStudentsMetaVersion(version);
    await AppPrefsService.instance.setStudentsLastSync(DateTime.now());
    if (_memCache != null) {
      _memCache = [for (final s in _memCache!) if (s.id != student.id) s];
    }
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
          () {
            final matchedAccount = _matchGuruAccount(accounts, s.kelas, s.halaqoh);
            return Student(
              id: s.id,
              nama: s.nama,
              kelas: s.kelas,
              halaqoh: s.halaqoh,
              schoolId: s.schoolId,
              guruAccountId: matchedAccount?.id,
              guruNama: matchedAccount?.displayName,
            );
          }(),
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
        '${toWrite.length} siswa baru tersimpan, tapi guru pembimbing gagal disinkron '
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
      final matchedAccount = _matchGuruAccount(accounts, s.kelas, s.halaqoh);
      final resolved = matchedAccount?.id;
      final resolvedNama = matchedAccount?.displayName;
      if (resolved != s.guruAccountId || resolvedNama != s.guruNama) {
        changed.add(Student(
          id: s.id,
          nama: s.nama,
          kelas: s.kelas,
          halaqoh: s.halaqoh,
          schoolId: s.schoolId,
          guruAccountId: resolved,
          guruNama: resolvedNama,
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
