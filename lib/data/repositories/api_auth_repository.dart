import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/utils/app_config.dart';
import '../local_seed/local_seed_data.dart';
import '../models/kelas_halaqoh.dart';
import '../models/user_account.dart';
import '../services/app_prefs_service.dart';
import '../services/auth_hash_service.dart';
import 'auth_repository.dart';

/// Data akun guru/admin, sumbernya Firestore (`schools/{id}/accounts`) —
/// PENGGANTI [LocalAuthRepository] biar assignment kelas+halaqoh guru
/// bisa diedit admin dari dalam app, TANPA build ulang APK.
///
/// Pola cache/fallback SAMA PERSIS seperti [ApiStudentRepository] (lihat
/// catatan lengkap di sana) — one-shot fetch, cache Hive buat offline,
/// fallback ke seed bawaan APK kalau belum pernah online sama sekali.
///
/// `passwordHash` TETAP diperlakukan seperti sebelumnya: [updatePasswordHash]
/// HANYA nulis ke override Hive LOKAL (lihat AppPrefsService.passwordOverrides),
/// TIDAK ditulis balik ke Firestore — supaya tidak menambah kompleksitas
/// sinkronisasi password lintas-device. Ini persis perilaku
/// [LocalAuthRepository] sebelumnya, tidak berubah.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository._();
  static final ApiAuthRepository instance = ApiAuthRepository._();

  static const _boxName = 'accounts_cache';
  Box<String>? _box;
  List<UserAccount>? _memCache;

  Future<Box<String>> _openBox() async {
    if (_box != null) return _box!;
    await Hive.initFlutter();
    return _box = await Hive.openBox<String>(_boxName);
  }

  CollectionReference<Map<String, dynamic>> get _collection => FirebaseFirestore.instance
      .collection('schools')
      .doc(kSchoolId)
      .collection('accounts');

  /// <-- BARU (migrasi auth). Koleksi "index" kecil: dokumen ID = email
  /// Google (huruf kecil semua), isinya cuma `{accountId: '...'}` --
  /// SATU-SATUNYA alasan koleksi ini ada adalah supaya Firestore Security
  /// Rules bisa mengecek "email Google yang login ini terdaftar atau
  /// tidak" lewat `exists()`/`get()` pada PATH LANGSUNG (rules TIDAK bisa
  /// menjalankan query `where(googleEmail == ...)` terhadap koleksi
  /// `accounts`, yang document ID-nya id akun seperti 'usr_02', bukan
  /// email). Lihat comment lengkap di firestore.rules (`isGuruApp()`) dan
  /// laporan migrasi soal langkah manual bootstrap yang WAJIB dilakukan
  /// sekali di Firebase Console sebelum admin pertama bisa login.
  CollectionReference<Map<String, dynamic>> get _accountsByEmailCollection => FirebaseFirestore.instance
      .collection('schools')
      .doc(kSchoolId)
      .collection('accountsByEmail');

  List<UserAccount> _withLocalOverrides(List<UserAccount> accounts) {
    final overrides = AppPrefsService.instance.passwordOverrides;
    // <-- BARU: sama alasannya kayak passwordOverrides -- foto profil
    // (AuthProvider.updatePhotoPath) juga cuma di-override LOKAL (Hive),
    // TIDAK ditulis balik ke Firestore, biar tidak menambah kompleksitas
    // sinkronisasi foto lintas-device (persis pola passwordOverrides).
    // Kalau userId TIDAK ADA di map ini, `photoPath` dibiarkan apa
    // adanya (null dari seed) -- itu sudah berarti "belum/tidak ada foto
    // custom", sama seperti kalau fotonya baru saja dihapus.
    final photoOverrides = AppPrefsService.instance.photoOverrides;
    if (overrides.isEmpty && photoOverrides.isEmpty) return accounts;
    return [
      for (final acc in accounts)
        acc.copyWith(
          passwordHash: overrides[acc.id],
          photoPath: photoOverrides[acc.id],
        ),
    ];
  }

  Future<List<UserAccount>> _accounts() async {
    if (_memCache != null) return _withLocalOverrides(_memCache!);

    final box = await _openBox();

    // <-- PENTING: sama seperti ApiStudentRepository -- ini JANGAN
    // nunggu Firestore, soalnya dipanggil dari restoreSession() yang
    // jalan SEBELUM runApp() (lihat main.dart). Cache Hive (atau seed
    // kalau masih kosong) dipakai LANGSUNG, fetch asli jalan di
    // BACKGROUND buat nyegerin cache-nya buat pemakaian berikutnya
    // (termasuk supaya guru tetap bisa LOGIN offline pakai data
    // terakhir yang berhasil di-fetch).
    if (box.isNotEmpty) {
      final cached = box.values
          .map((v) => UserAccount.fromJson(jsonDecode(v) as Map<String, dynamic>))
          .toList();
      _memCache = cached;
      unawaited(_refreshInBackground());
      return _withLocalOverrides(cached);
    }

    final seeded = kSeedAccountsJson.map(UserAccount.fromJson).toList();
    _memCache = seeded;
    unawaited(_refreshInBackground());
    return _withLocalOverrides(seeded);
  }


  Future<void> _refreshInBackground() async {
    try {
      await refresh();
    } catch (_) {}
  }

  /// Paksa fetch ulang dari Firestore DAN TUNGGU hasilnya (dipanggil
  /// eksplisit — mis. admin buka layar "Kelola Akun Guru", atau tombol
  /// refresh manual. BUKAN dipanggil dari [_accounts]/startup).
  Future<List<UserAccount>> refresh() async {
    final box = await _openBox();

    try {
      final snapshot = await _collection.get().timeout(const Duration(seconds: 10));
      if (snapshot.docs.isNotEmpty) {
        final accounts = snapshot.docs.map((d) => UserAccount.fromJson(d.data())).toList();
        await box.clear();
        await box.putAll({for (final a in accounts) a.id: jsonEncode(a.toJson())});
        _memCache = accounts;
        return accounts;
      }
    } catch (_) {
      // Offline/timeout -- lanjut ke fallback (login TETAP harus bisa
      // jalan offline pakai data terakhir yang berhasil di-fetch).
    }

    if (box.isNotEmpty) {
      final cached = box.values
          .map((v) => UserAccount.fromJson(jsonDecode(v) as Map<String, dynamic>))
          .toList();
      _memCache = cached;
      return cached;
    }

    final seeded = kSeedAccountsJson.map(UserAccount.fromJson).toList();
    _memCache = seeded;
    return seeded;
  }

  @override
  Future<UserAccount?> login(String username, String password) async {
    final normalizedUsername = username.trim().toLowerCase();
    for (final acc in await _accounts()) {
      if (acc.username.toLowerCase() == normalizedUsername) {
        final valid = AuthHashService.instance.verify(password, acc.passwordHash);
        return valid ? acc : null;
      }
    }
    return null;
  }

  @override
  Future<UserAccount?> findById(String id) async {
    for (final acc in await _accounts()) {
      if (acc.id == id) return acc;
    }
    return null;
  }

  /// <-- BARU (migrasi auth: Anonymous -> Google Sign-In). Whitelist
  /// check: cari akun yang [UserAccount.googleEmail]-nya cocok [email]
  /// (case-insensitive -- keduanya dibandingkan dalam bentuk lowercase).
  /// Dipakai [AuthProvider.signInWithGoogle] & [AuthProvider.restoreSession]
  /// SESUDAH Firebase Authentication sendiri berhasil (Google login
  /// valid) -- ini murni langkah AUTHORIZATION terpisah: "Firebase Auth
  /// menjawab siapa user ini, Firestore account menjawab apakah dia
  /// boleh pakai Quran Report" (lihat spesifikasi migrasi). Null berarti
  /// authentication SUKSES tapi authorization GAGAL (akun Google itu
  /// belum di-mapping admin lewat KelolaGuruScreen/[updateGoogleEmail])
  /// -- caller HARUS menampilkan pesan "akun belum terdaftar", BUKAN
  /// menganggap ini error jaringan.
  ///
  /// Pakai [_accounts()] yang sama seperti [login]/[findById] (cache
  /// Hive-dulu + background refresh) -- supaya guru yang SUDAH PERNAH
  /// login sebelumnya tetap bisa restore session walau offline (lihat
  /// [AuthProvider.restoreSession]), TANPA mengubah pola cache/cooldown
  /// Firestore read yang sudah dioptimasi (lihat audit sebelumnya --
  /// method ini TIDAK menambah Firestore read baru, cuma baca dari cache
  /// yang sama dengan [login]/[allAccounts]).
  @override
  Future<UserAccount?> findByGoogleEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final acc in await _accounts()) {
      if (acc.googleEmail != null && acc.googleEmail == normalized) return acc;
    }

    // <-- BARU (fix bug nyata dari lapangan, migrasi auth). [_accounts()]
    // cache-first (lihat dokumentasinya) bisa BASI persis di momen paling
    // krusial: begitu admin baru saja mendaftarkan/mengubah
    // [UserAccount.googleEmail] guru ini di Firestore (lewat KelolaGuruScreen
    // ATAU manual di Console), device guru itu SENDIRI (apalagi kalau
    // sebelumnya sudah pernah buka app & punya cache akun dari SEBELUM
    // field itu ada/berubah) belum tentu sudah sempat nge-refresh cache
    // lokalnya duluan. Tanpa fallback ini, percobaan Google Sign-In
    // PERTAMA guru itu bakal salah ditolak "belum terdaftar" walau
    // sebenarnya SUDAH terdaftar di Firestore -- baru berhasil di
    // percobaan KEDUA (setelah background refresh dari percobaan pertama
    // sempat selesai). Sekarang: begitu tidak ketemu di cache, langsung
    // coba SATU KALI full refresh paksa dulu sebelum benar-benar
    // menyerah -- supaya percobaan PERTAMA pun langsung berhasil, guru
    // tidak perlu tahu-menahu soal cache/refresh sama sekali.
    try {
      final fresh = await refresh();
      for (final acc in fresh) {
        if (acc.googleEmail != null && acc.googleEmail == normalized) return acc;
      }
    } catch (_) {
      // Offline/gagal refresh (mis. accountsByEmail belum ke-setup jadi
      // permission-denied, atau memang tidak ada internet) -- tetap
      // null, caller (AuthProvider.signInWithGoogle) sudah tau artinya
      // "authorization gagal", entah karena memang belum terdaftar atau
      // karena refresh-nya sendiri gagal.
    }
    return null;
  }

  @override
  Future<List<UserAccount>> allAccounts() async => List.unmodifiable(await _accounts());

  @override
  Future<bool> updatePasswordHash(String userId, String newHash) async {
    final exists = (await _accounts()).any((acc) => acc.id == userId);
    if (!exists) return false;
    await AppPrefsService.instance.setPasswordOverride(userId, newHash);
    return true;
  }

  @override
  Future<bool> updatePhotoPath(String userId, String? photoPath) async {
    final exists = (await _accounts()).any((acc) => acc.id == userId);
    if (!exists) return false;
    // Sama pola & alasannya kayak updatePasswordHash di atas -- lihat
    // catatan bug fix lengkap di AppPrefsService.photoOverrides. Ditulis
    // HANYA ke override Hive lokal, TIDAK ke Firestore (sama seperti
    // password), jadi foto profil ini per-device.
    await AppPrefsService.instance.setPhotoOverride(userId, photoPath);
    return true;
  }

  /// Ubah displayName & assignment (kelas+halaqoh) satu akun guru.
  /// SENGAJA TIDAK menyentuh `passwordHash`/`role` -- itu tetap lewat
  /// alur ganti password yang sudah ada, bukan dari sini. HANYA dipanggil
  /// dari layar admin (Kelola Akun Guru) — pengecekan role dilakukan di
  /// layer UI, bukan di sini.
  Future<void> updateAssignments(
    UserAccount account, {
    required String displayName,
    required List<KelasHalaqoh> assignments,
  }) async {
    final updated = account.copyWith(displayName: displayName, assignments: assignments);

    await _collection.doc(account.id).set(updated.toJson()).timeout(const Duration(seconds: 15));

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
      batch.set(_accountsByEmailCollection.doc(normalizedOrNull), {'accountId': account.id});
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
