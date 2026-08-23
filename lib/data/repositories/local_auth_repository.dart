import '../local_seed/local_seed_data.dart';
import '../models/user_account.dart';
import '../services/auth_hash_service.dart';
import 'auth_repository.dart';

/// Implementasi lokal [AuthRepository] — baca dari [kSeedAccountsJson] &
/// verifikasi password via [AuthHashService]. Lihat catatan security di
/// `AuthHashService` sebelum menganggap ini aman untuk production.
class LocalAuthRepository implements AuthRepository {
  List<UserAccount>? _cache;

  List<UserAccount> _accounts() {
    return _cache ??= kSeedAccountsJson.map(UserAccount.fromJson).toList();
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
}
