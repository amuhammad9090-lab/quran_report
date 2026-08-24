import 'dart:convert';
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
  static const _keyActivatedIdentities = 'activated_report_identities';
  static const _keyActivatedIdentityFolders = 'activated_report_identity_folders';

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

  // --- Identitas laporan yang "diaktifkan" (kartu santri di tab Laporan
  // yang belum punya laporan pekanan sama sekali) ---
  //
  // Ini BUKAN database laporan baru — cuma daftar kecil kunci
  // "kelas|halaqoh|nama" yang menandai santri mana yang sudah dibuatkan
  // kartu lewat "Buat Laporan", supaya kartunya tetap kelihatan di tab
  // Laporan walau belum ada satupun SantriRecord tersimpan untuknya.
  // Begitu laporan pekanan pertamanya tersimpan, santri itu otomatis
  // muncul lewat data laporan asli juga (lihat RecordsProvider.laporanCards)
  // — daftar ini tetap dipertahankan sebagai union, bukan pengganti.
  List<String> get activatedIdentityKeys {
    final raw = _box.get(_keyActivatedIdentities);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addActivatedIdentity(String key) async {
    final current = activatedIdentityKeys.toSet()..add(key);
    await _box.put(_keyActivatedIdentities, jsonEncode(current.toList()));
  }

  Future<void> removeActivatedIdentity(String key) async {
    final current = activatedIdentityKeys.toSet()..remove(key);
    await _box.put(_keyActivatedIdentities, jsonEncode(current.toList()));
    // Kartu identitasnya sendiri dilepas -> mapping folder-nya (kalau ada)
    // ikut jadi tidak relevan, hapus juga biar nggak jadi sampah.
    await removeActivatedIdentityFolder(key);
  }

  // --- Folder tujuan untuk kartu identitas yang masih KOSONG (belum ada
  // SantriRecord sama sekali) ---
  //
  // Kartu kosong bisa "dipindahkan ke folder" juga (drag/tap Pindahkan),
  // tapi karena belum ada SantriRecord yang benar-benar bisa dikasih
  // folderId, mapping "identitas -> folder tujuan" ini yang jadi
  // penanda sementara. Dipakai 2 tempat: (a) supaya kartu kosong itu
  // tetap kelihatan nangkring di dalam folder yang benar waktu folder
  // dibuka, dan (b) sebagai `initialFolderId` waktu laporan PERTAMA buat
  // identitas ini dibuat, biar otomatis langsung masuk folder yang sama
  // (lihat RecordsProvider.moveIdentityToFolder & LaporanTab._openWeek).
  // Begitu identitas ini punya laporan asli, mapping ini jadi basi dan
  // dibersihkan otomatis (lihat RecordsProvider._cleanupStaleActivatedFolders).
  Map<String, String> get activatedIdentityFolders {
    final raw = _box.get(_keyActivatedIdentityFolders);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map;
      return map.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> setActivatedIdentityFolder(String key, String folderId) async {
    final current = activatedIdentityFolders;
    current[key] = folderId;
    await _box.put(_keyActivatedIdentityFolders, jsonEncode(current));
  }

  Future<void> removeActivatedIdentityFolder(String key) async {
    final current = activatedIdentityFolders;
    if (current.remove(key) == null) return;
    await _box.put(_keyActivatedIdentityFolders, jsonEncode(current));
  }
}
