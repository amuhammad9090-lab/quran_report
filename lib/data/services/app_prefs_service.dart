import 'package:hive_flutter/hive_flutter.dart';

/// Persistensi key-value kecil untuk app-level state (status onboarding,
/// session user yang lagi login). Pakai Hive Box terpisah dari
/// `StorageService` (yang isinya data laporan/folder) supaya nggak
/// campur aduk tanggung jawab — tapi tetap satu mekanisme storage yang
/// sama (Hive), sesuai punya project ini, bukan nambah database baru.
///
/// Asumsi: `Hive.initFlutter()` sudah dipanggil sebelumnya (lewat
/// `StorageService.instance.init()` di main.dart) — di sini cuma buka
/// box baru, tidak init ulang.
class AppPrefsService {
  AppPrefsService._();
  static final AppPrefsService instance = AppPrefsService._();

  static const _boxName = 'app_prefs';
  static const _keyOnboardingComplete = 'onboarding_complete';
  static const _keySessionUserId = 'session_user_id';

  late Box<String> _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  bool get onboardingComplete => _box.get(_keyOnboardingComplete) == 'true';

  Future<void> setOnboardingComplete() async {
    await _box.put(_keyOnboardingComplete, 'true');
  }

  String? get sessionUserId => _box.get(_keySessionUserId);

  Future<void> setSessionUserId(String userId) async {
    await _box.put(_keySessionUserId, userId);
  }

  Future<void> clearSession() async {
    await _box.delete(_keySessionUserId);
  }
}
