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

  List<UserAccount> _withPasswordOverrides(List<UserAccount> accounts) {
    final overrides = AppPrefsService.instance.passwordOverrides;
    if (overrides.isEmpty) return accounts;
    return [
      for (final acc in accounts)
        if (overrides.containsKey(acc.id)) acc.copyWith(passwordHash: overrides[acc.id]) else acc,
    ];
  }

  Future<List<UserAccount>> _accounts() async {
    if (_memCache != null) return _withPasswordOverrides(_memCache!);

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
      return _withPasswordOverrides(cached);
    }

    final seeded = kSeedAccountsJson.map(UserAccount.fromJson).toList();
    _memCache = seeded;
    unawaited(_refreshInBackground());
    return _withPasswordOverrides(seeded);
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

  @override
  Future<List<UserAccount>> allAccounts() async => List.unmodifiable(await _accounts());

  @override
  Future<bool> updatePasswordHash(String userId, String newHash) async {
    final exists = (await _accounts()).any((acc) => acc.id == userId);
    if (!exists) return false;
    await AppPrefsService.instance.setPasswordOverride(userId, newHash);
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

  /// Migrasi SEKALI-JALAN: tulis seluruh [kSeedAccountsJson] ke
  /// Firestore. Aman dipencet berkali-kali (upsert per id).
  Future<int> migrateSeedToFirestore() async {
    final accounts = kSeedAccountsJson.map(UserAccount.fromJson).toList();
    const batchSize = 400;
    var written = 0;

    for (var i = 0; i < accounts.length; i += batchSize) {
      final end = (i + batchSize > accounts.length) ? accounts.length : i + batchSize;
      final chunk = accounts.sublist(i, end);

      final batch = FirebaseFirestore.instance.batch();
      for (final a in chunk) {
        batch.set(_collection.doc(a.id), a.toJson());
      }
      await batch.commit().timeout(const Duration(seconds: 20));
      written += chunk.length;
    }

    final box = await _openBox();
    await box.clear();
    await box.putAll({for (final a in accounts) a.id: jsonEncode(a.toJson())});
    _memCache = accounts;

    return written;
  }
}
