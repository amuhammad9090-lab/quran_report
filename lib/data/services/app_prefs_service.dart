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
  static const _keyRecordDraft = 'record_form_draft';

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

  // --- Draft form "Laporan Baru" ---
  // Cuma dipakai buat laporan BARU (bukan edit) — supaya kalau bottom
  // sheet-nya ke-tutup nggak sengaja (swipe/tap di luar) sebelum sempat
  // tekan Simpan, isian yang udah diketik/dipilih nggak hilang begitu
  // saja. Disimpan sebagai JSON mentah di sini (bukan di-parse) — biar
  // service ini tetap generik, parsing/model-nya jadi urusan pemanggil
  // (RecordFormSheet).
  String? get recordDraftJson => _box.get(_keyRecordDraft);

  Future<void> saveRecordDraft(String json) async {
    await _box.put(_keyRecordDraft, json);
  }

  Future<void> clearRecordDraft() async {
    await _box.delete(_keyRecordDraft);
  }
}
