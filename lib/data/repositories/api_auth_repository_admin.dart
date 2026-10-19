part of 'api_auth_repository.dart';

/// Operasi tulis ADMIN pada akun (ubah role, email Google, import massal, migrasi seed).
/// Dipisah dari [ApiAuthRepository] supaya file tidak membengkak; API pemanggil TIDAK berubah
/// (extension ini ikut terekspor lewat library yang sama).
extension ApiAuthRepositoryAdminOps on ApiAuthRepository {
  /// Ubah role akun (admin <-> guru pembimbing). HANYA dipanggil dari layar admin (Kelola Akun
  /// Guru); pengecekan siapa yang boleh ada di layer UI, dan Firestore Rules tetap penentu akhir
  /// boleh-tidaknya tulis ke `accounts/{id}`. Pakai merge supaya cuma field `role` yang berubah.
  /// Nilai yang ditulis 'admin' / 'guru_pembimbing' (sama seperti seed; [UserRole.fromName] baca keduanya).
  Future<void> updateRole(UserAccount account, UserRole newRole) async {
    final roleValue = switch (newRole) {
      UserRole.admin => 'admin',
      UserRole.pengawas => 'pengawas',
      UserRole.guruPembimbing => 'guru_pembimbing',
    };

    // Dua dokumen dijaga sinkron dalam 1 batch: `accounts/{id}.role` (dibaca CLIENT) dan flag
    // `accountsByEmail/{email}.isAdmin` (dibaca Firestore Rules di isAdmin() -- INI yang
    // sebenarnya memberi izin admin di server, lihat firestore.rules).
    final batch = FirebaseFirestore.instance.batch();
    batch.set(_collection.doc(account.id), {'role': roleValue}, SetOptions(merge: true));
    final email = account.googleEmail;
    if (email != null) {
      batch.set(
        _accountsByEmailCollection.doc(email),
        {
          'accountId': account.id,
          'isAdmin': newRole == UserRole.admin,
          'isViewer': newRole == UserRole.pengawas,
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit().timeout(const Duration(seconds: 15));

    final updated = account.copyWith(role: newRole);
    final box = await _openBox();
    await box.put(account.id, jsonEncode(updated.toJson()));
    if (_memCache != null) {
      _memCache = [for (final a in _memCache!) if (a.id == account.id) updated else a];
    }
  }

  /// <-- BARU (migrasi auth: Anonymous -> Google Sign-In). Mapping/ubah
  /// email Google yang di-whitelist buat akun ini -- SATU-SATUNYA cara
  /// admin memberi (atau mencabut, lewat [newGoogleEmail] = null) akses
  /// login Google ke seorang guru. HANYA dipanggil dari layar admin
  /// (Kelola Akun Guru) — pengecekan role dilakukan di layer UI, sama
  /// seperti [updateAssignments].
  ///
  /// Menjaga DUA dokumen tetap sinkron dalam SATU batch atomic:
  /// 1. `accounts/{account.id}.googleEmail` -- buat ditampilkan di UI &
  ///    dibaca [findByGoogleEmail] dari CLIENT.
  /// 2. `accountsByEmail/{email}` -- "index" kecil yang dibaca Firestore
  ///    Security Rules sendiri (lihat [_accountsByEmailCollection]) buat
  ///    memutuskan apakah request ini boleh lewat `isGuruApp()`.
  ///
  /// Kalau [newGoogleEmail] beda dari email lama akun ini, entry index
  /// yang LAMA dihapus (supaya email lama itu tidak "nyangkut" tetap bisa
  /// dipakai login ke akun ini sesudah diganti). Melempar [StateError]
  /// kalau email yang mau dipakai SUDAH di-mapping ke akun LAIN (satu
  /// email Google cuma boleh dipetakan ke satu akun guru).
  Future<void> updateGoogleEmail(UserAccount account, String? newGoogleEmail) async {
    final normalized = newGoogleEmail?.trim().toLowerCase();
    final normalizedOrNull = (normalized == null || normalized.isEmpty) ? null : normalized;
    final oldEmail = account.googleEmail;

    if (normalizedOrNull != null && normalizedOrNull != oldEmail) {
      final existing =
          await _accountsByEmailCollection.doc(normalizedOrNull).get().timeout(const Duration(seconds: 10));
      if (existing.exists && existing.data()?['accountId'] != account.id) {
        throw StateError('Email Google ini sudah dipakai akun lain.');
      }
    }

    final updated = account.copyWith(
      googleEmail: normalizedOrNull,
      clearGoogleEmail: normalizedOrNull == null,
    );

    final batch = FirebaseFirestore.instance.batch();
    batch.set(_collection.doc(account.id), updated.toJson());
    if (oldEmail != null && oldEmail != normalizedOrNull) {
      batch.delete(_accountsByEmailCollection.doc(oldEmail));
    }
    if (normalizedOrNull != null) {
      // `isAdmin` ikut ditulis supaya Firestore Rules (isAdmin()) tahu role akun ini; ini juga
      // yang membuat akun admin lama (index-nya belum punya flag) ter-sinkron tiap kali disimpan.
      batch.set(_accountsByEmailCollection.doc(normalizedOrNull), {
        'accountId': account.id,
        'isAdmin': updated.isAdmin,
        'isViewer': updated.isPengawas,
      });
    }
    await batch.commit().timeout(const Duration(seconds: 15));

    final box = await _openBox();
    await box.put(account.id, jsonEncode(updated.toJson()));
    if (_memCache != null) {
      _memCache = [for (final a in _memCache!) if (a.id == account.id) updated else a];
    }
  }

  /// Ubah displayName & assignments BANYAK akun guru sekaligus (dipakai
  /// admin dari import Excel di Halaman Kelola, sesudah preview &
  /// konfirmasi -- BUKAN dari input bebas). SENGAJA TIDAK menyentuh
  /// `passwordHash`/`role`/`username`, sama seperti [updateAssignments]
  /// satuan -- caller (KelolaDataScreen) hanya boleh mengoper akun hasil
  /// `AccountImportRow.toUpdatedAccount()`, yang sudah menjaga batasan itu.
  Future<int> bulkUpdateAssignments(List<UserAccount> updatedAccounts) async {
    if (updatedAccounts.isEmpty) return 0;
    const batchSize = 400;
    var written = 0;

    for (var i = 0; i < updatedAccounts.length; i += batchSize) {
      final end = (i + batchSize > updatedAccounts.length) ? updatedAccounts.length : i + batchSize;
      final chunk = updatedAccounts.sublist(i, end);

      final batch = FirebaseFirestore.instance.batch();
      for (final a in chunk) {
        batch.set(_collection.doc(a.id), a.toJson());
      }
      await batch.commit().timeout(const Duration(seconds: 20));
      written += chunk.length;
    }

    final box = await _openBox();
    for (final a in updatedAccounts) {
      await box.put(a.id, jsonEncode(a.toJson()));
    }
    if (_memCache != null) {
      final byId = {for (final a in updatedAccounts) a.id: a};
      _memCache = [for (final a in _memCache!) byId[a.id] ?? a];
    }

    return written;
  }

  /// Migrasi SEKALI-JALAN: tulis seluruh [kSeedAccountsJson] ke
  /// Firestore. Aman dipencet berkali-kali (upsert per id).
  /// Migrasi SEKALI-JALAN: tulis [kSeedAccountsJson] ke Firestore.
  ///
  /// PENTING (fix): id yang SUDAH ADA di Firestore (mis. sudah pernah
  /// di-migrasi sebelumnya, diedit lewat Kelola Guru, atau diupdate
  /// lewat Import Excel di Halaman Kelola) SENGAJA DILEWATIN -- cuma id
  /// yang BELUM ADA sama sekali yang ditulis. Ini yang bikin tombol ini
  /// aman dipencet berkali-kali TANPA nimpa balik ke data lama (sebelum
  /// fix ini, migrate nulis ulang SEMUA id dari seed tiap kali dipencet,
  /// jadi kalau dipencet SESUDAH ada perubahan dari Kelola Guru/Import,
  /// perubahan itu ketimpa balik ke nilai seed yang lama).
  Future<int> migrateSeedToFirestore() async {
    final seedAccounts = kSeedAccountsJson.map(UserAccount.fromJson).toList();

    final snapshot = await _collection.get().timeout(const Duration(seconds: 15));
    final existingIds = snapshot.docs.map((d) => d.id).toSet();

    final toWrite = seedAccounts.where((a) => !existingIds.contains(a.id)).toList();

    const batchSize = 400;
    for (var i = 0; i < toWrite.length; i += batchSize) {
      final end = (i + batchSize > toWrite.length) ? toWrite.length : i + batchSize;
      final chunk = toWrite.sublist(i, end);

      final batch = FirebaseFirestore.instance.batch();
      for (final a in chunk) {
        batch.set(_collection.doc(a.id), a.toJson());
      }
      await batch.commit().timeout(const Duration(seconds: 20));
    }

    // Seger-in cache dari Firestore YANG SEBENARNYA (bukan cuma daftar
    // seed) -- biar konsisten sama data yang beneran ada sekarang,
    // termasuk perubahan dari Kelola Guru/Import yang gak ikut ditulis
    // ulang di atas.
    await refresh();

    return toWrite.length;
  }
}
