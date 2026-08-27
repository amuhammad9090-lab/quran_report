import '../local_seed/local_seed_data.dart';
import '../models/user_account.dart';
import '../services/app_prefs_service.dart';
import '../services/auth_hash_service.dart';
import 'auth_repository.dart';

/// Implementasi lokal [AuthRepository] — baca dari [kSeedAccountsJson] &
/// verifikasi password via [AuthHashService]. Lihat catatan security di
/// `AuthHashService` sebelum menganggap ini aman untuk production.
class LocalAuthRepository implements AuthRepository {
  List<UserAccount>? _cache;

  List<UserAccount> _accounts() {
    if (_cache != null) return _cache!;
    final seeded = kSeedAccountsJson.map(UserAccount.fromJson).toList();
    // Timpa passwordHash dari seed dengan override yang pernah disimpan
    // user (lihat AppPrefsService.passwordOverrides) — supaya ganti
    // password tetap kepakai walau app sempat ditutup total, bukan cuma
    // logout. Ini dibaca SEKALI aja pas cache pertama kali dibangun
    // (bukan tiap _accounts() dipanggil), karena override cuma berubah
    // lewat updatePasswordHash di bawah yang juga langsung update cache.
    final overrides = AppPrefsService.instance.passwordOverrides;
    _cache = [
      for (final acc in seeded)
        if (overrides.containsKey(acc.id))
          acc.copyWith(passwordHash: overrides[acc.id])
        else
          acc,
    ];
    return _cache!;
  }

  @override
  Future<UserAccount?> login(String username, String password) async {
    final normalizedUsername = username.trim().toLowerCase();
    for (final acc in _accounts()) {
      if (acc.username.toLowerCase() == normalizedUsername) {
        final valid = AuthHashService.instance.verify(password, acc.passwordHash);
        return valid ? acc : null;
      }
    }
    return null;
  }

  @override
  Future<UserAccount?> findById(String id) async {
    for (final acc in _accounts()) {
      if (acc.id == id) return acc;
    }
    return null;
  }

  @override
  Future<List<UserAccount>> allAccounts() async => List.unmodifiable(_accounts());

  @override
  Future<bool> updatePasswordHash(String userId, String newHash) async {
    final accounts = _accounts();
    final index = accounts.indexWhere((acc) => acc.id == userId);
    if (index == -1) return false;
    accounts[index] = accounts[index].copyWith(passwordHash: newHash);
    // Persist ke Hive (lihat AppPrefsService.passwordOverrides) — INI yang
    // sebelumnya kelewat, cuma update cache in-memory jadi hilang begitu
    // app di-kill total. Sekarang login pakai password baru tetap jalan
    // setelah logout ATAUPUN app ditutup & dibuka lagi dari awal.
    await AppPrefsService.instance.setPasswordOverride(userId, newHash);
    return true;
  }
}
