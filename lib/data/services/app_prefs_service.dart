import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- BARU
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/utils/app_config.dart'; // <-- BARU

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
  static const _keyActivatedIdentityDisplay = 'activated_report_identity_display';
  static const _keyPasswordOverrides = 'password_overrides';
  static const _keyDownloadNotifPaths = 'download_notif_paths';
  static const _keyAdminModeActive = 'admin_mode_active'; // <-- BARU

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

  // <-- BARU: toggle "Mode Admin" global di Profil (lihat AccessScope &
  // AuthProvider.setAdminModeActive). Disimpan PER DEVICE (bukan per akun
  // di Firestore) — konsisten dengan `sessionUserId` yang juga per device.
  // Default true (nilai lama sebelum fitur ini ada = admin selalu bypass
  // semua scope), jadi upgrade dari versi lama tidak mendadak
  // "mengunci" admin ke assignment sendiri tanpa dia sadar.
  bool get adminModeActive => _box.get(_keyAdminModeActive) != 'false';

  Future<void> setAdminModeActive(bool value) async {
    await _box.put(_keyAdminModeActive, value ? 'true' : 'false');
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
    _mirrorActivatedMetaToFirestore();
  }

  Future<void> removeActivatedIdentity(String key) async {
    final current = activatedIdentityKeys.toSet()..remove(key);
    await _box.put(_keyActivatedIdentities, jsonEncode(current.toList()));
    // Kartu identitasnya sendiri dilepas -> mapping folder-nya (kalau ada)
    // ikut jadi tidak relevan, hapus juga biar nggak jadi sampah.
    await removeActivatedIdentityFolder(key);
    _mirrorActivatedMetaToFirestore();
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
    _mirrorActivatedMetaToFirestore();
  }

  Future<void> removeActivatedIdentityFolder(String key) async {
    final current = activatedIdentityFolders;
    if (current.remove(key) == null) return;
    await _box.put(_keyActivatedIdentityFolders, jsonEncode(current));
    _mirrorActivatedMetaToFirestore();
  }

  // --- Kapitalisasi ASLI (kelas|halaqoh|nama) buat kartu identitas yang
  // masih KOSONG (belum ada SantriRecord) ---
  //
  // BUG FIX: sebelumnya kapitalisasi asli cuma disimpan in-memory
  // (`RecordsProvider._lastActivatedDisplay`), bukan di-persist ke sini —
  // begitu app di-kill/restart SEBELUM identitas itu sempat dibuatkan
  // laporan pertamanya, RAM-nya ikut hilang dan kartu itu fallback
  // nampilin `identityKey` (yang emang sengaja di-lowercase buat
  // perbandingan, lihat [reportIdentityKey]) apa adanya — nama santri
  // keliatan huruf kecil semua. Sekarang kapitalisasi aslinya DISIMPAN di
  // sini (persist ke disk) tiap kali identitas diaktifkan, jadi selamat
  // dari restart app juga — sama persis pola fix-nya kayak
  // [passwordOverrides]/[downloadNotifPaths] di atas.
  Map<String, String> get activatedIdentityDisplay {
    final raw = _box.get(_keyActivatedIdentityDisplay);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map;
      return map.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  /// [value] format "kelas|halaqoh|nama" (kapitalisasi ASLI, bukan yang
  /// di-lowercase) — dipisah lagi pas dibaca di [RecordsProvider.load].
  Future<void> setActivatedIdentityDisplay(String key, String value) async {
    final current = activatedIdentityDisplay;
    current[key] = value;
    await _box.put(_keyActivatedIdentityDisplay, jsonEncode(current));
    _mirrorActivatedMetaToFirestore();
  }

  Future<void> removeActivatedIdentityDisplay(String key) async {
    final current = activatedIdentityDisplay;
    if (current.remove(key) == null) return;
    await _box.put(_keyActivatedIdentityDisplay, jsonEncode(current));
    _mirrorActivatedMetaToFirestore();
  }

  // <-- BARU: mirror snapshot LENGKAP 3 data identitas "kartu kosong"
  // (activated keys + folder tujuan + kapitalisasi asli) ke 1 dokumen
  // Firestore kecil, fire-and-forget (gagal diam-diam, sama polanya
  // seperti StorageService._mirrorToFirestore — Hive lokal tetap sumber
  // kebenaran). Beda dari data laporan yang di-mirror PER RECORD, di sini
  // cukup 1 dokumen karena ukurannya kecil & jarang berubah.
  //
  // Alasan metadata ini juga perlu di-backup (bukan cuma data laporan):
  // kartu santri yang BELUM PERNAH diisi laporan sama sekali ("kartu
  // kosong") kapitalisasi namanya CUMA ada di sini — kalau Hive lokal
  // hilang (app di-uninstall install ulang, atau kalau dipakai sebagai
  // Web/PWA lalu cache/PWA-nya dibersihkan) dan metadata ini tidak
  // ke-backup, kartu kosong itu bakal balik nampilin nama huruf kecil
  // semua (fallback ke identityKey yang emang sengaja lowercase) — lihat
  // RecordsProvider.laporanCards.
  void _mirrorActivatedMetaToFirestore() {
    FirebaseFirestore.instance
        .collection('schools')
        .doc(kSchoolId)
        .collection('appMeta')
        .doc('activatedIdentities')
        .set({
          'keys': activatedIdentityKeys,
          'folders': activatedIdentityFolders,
          'display': activatedIdentityDisplay,
        })
        .catchError((_) {});
  }

  /// <-- BARU: kebalikan dari mirror di atas — tarik snapshot metadata
  /// kartu kosong dari Firestore, di-UNION (bukan ditimpa total) dengan
  /// yang sudah ada lokal, supaya identitas yang baru diaktifkan di
  /// device ini setelah restore terakhir tetap aman. Dipanggil bareng
  /// StorageService.restoreFromFirestore() dari tombol "Pulihkan dari
  /// Cloud" di Pengaturan (lihat SettingsScreen._restoreFromCloud).
  Future<void> restoreActivatedMetaFromFirestore() async {
    final doc = await FirebaseFirestore.instance
        .collection('schools')
        .doc(kSchoolId)
        .collection('appMeta')
        .doc('activatedIdentities')
        .get();
    final data = doc.data();
    if (data == null) return;

    final cloudKeys = (data['keys'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final cloudFolders = (data['folders'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
        const {};
    final cloudDisplay = (data['display'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
        const {};

    final mergedKeys = activatedIdentityKeys.toSet()..addAll(cloudKeys);
    await _box.put(_keyActivatedIdentities, jsonEncode(mergedKeys.toList()));

    final mergedFolders = activatedIdentityFolders..addAll(cloudFolders);
    await _box.put(_keyActivatedIdentityFolders, jsonEncode(mergedFolders));

    final mergedDisplay = activatedIdentityDisplay..addAll(cloudDisplay);
    await _box.put(_keyActivatedIdentityDisplay, jsonEncode(mergedDisplay));
  }

  // --- Override password akun lokal ---
  //
  // BUG FIX: sebelumnya ganti password cuma diterapkan ke cache in-memory
  // punya LocalAuthRepository (lihat riwayat perubahan di sana) — begitu
  // app di-kill (bukan cuma logout, tapi bener-bener ditutup prosesnya),
  // seluruh state di RAM ikut hilang, jadi pas dibuka lagi password balik
  // ke seed semula sementara user ngira udah kesimpen. Sekarang hash
  // password baru DISIMPAN di sini (Hive, persist ke disk) dan
  // LocalAuthRepository menerapkannya di atas data seed tiap kali akun
  // dimuat ulang — jadi selamat dari logout maupun app di-kill total.
  Map<String, String> get passwordOverrides {
    final raw = _box.get(_keyPasswordOverrides);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map;
      return map.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> setPasswordOverride(String userId, String newHash) async {
    final current = passwordOverrides;
    current[userId] = newHash;
    await _box.put(_keyPasswordOverrides, jsonEncode(current));
  }

  // --- Mapping id notifikasi unduhan -> path file (buat DownloadNotificationService) ---
  //
  // BUG FIX: tap notifikasi "Tersimpan ke Download" nggak ngapa-ngapain
  // kalau app sempat di-tutup total (bukan cuma minimize) sebelum
  // notifikasinya di-tap — soalnya mapping id->file sebelumnya cuma
  // disimpan di Map in-memory (`DownloadNotificationService._notifIdToFile`),
  // yang otomatis kosong lagi tiap app di-launch ulang dari awal. Sekarang
  // mapping-nya ikut disimpan di sini (persist ke disk) supaya masih ada
  // walau app-nya sempat mati duluan pas notifikasi di-tap.
  Map<String, String> get downloadNotifPaths {
    final raw = _box.get(_keyDownloadNotifPaths);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map;
      return map.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> setDownloadNotifPath(int notifId, String filePath) async {
    final current = downloadNotifPaths;
    current['$notifId'] = filePath;
    await _box.put(_keyDownloadNotifPaths, jsonEncode(current));
  }

  Future<void> removeDownloadNotifPath(int notifId) async {
    final current = downloadNotifPaths;
    if (current.remove('$notifId') == null) return;
    await _box.put(_keyDownloadNotifPaths, jsonEncode(current));
  }
}
