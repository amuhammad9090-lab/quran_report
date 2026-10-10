import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/app_config.dart';
import '../models/ketuntasan_config.dart';
import 'app_prefs_service.dart';

/// Standar ketuntasan bersama semua guru: disimpan di Firestore (`settings/ketuntasan`, hanya admin
/// yang boleh menulis) dan di-cache di HP supaya tetap terbaca saat offline.
class KetuntasanSettingsService {
  KetuntasanSettingsService._();
  static final KetuntasanSettingsService instance = KetuntasanSettingsService._();

  KetuntasanConfig _config = KetuntasanConfig.defaults();
  KetuntasanConfig get config => _config;

  DocumentReference<Map<String, dynamic>> get _doc => FirebaseFirestore.instance
      .collection('schools')
      .doc(kSchoolId)
      .collection('settings')
      .doc('ketuntasan');

  /// Muat dari cache HP (dipanggil sekali saat app start).
  void loadCached() {
    final raw = AppPrefsService.instance.ketuntasanJson;
    if (raw == null) return;
    try {
      _config = KetuntasanConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Cache rusak: pakai bawaan.
    }
  }

  /// Ambil versi terbaru dari Firestore. Gagal/offline = diam saja, tetap pakai cache.
  Future<void> refresh() async {
    try {
      final snap = await _doc.get().timeout(const Duration(seconds: 20));
      final data = snap.data();
      if (data == null) return;
      _config = KetuntasanConfig.fromJson(data);
      await AppPrefsService.instance.setKetuntasanJson(jsonEncode(_config.toJson()));
    } catch (_) {}
  }

  /// Simpan standar baru (hanya admin). Lempar error kalau gagal.
  Future<void> save(KetuntasanConfig next) async {
    await _doc.set({...next.toJson(), 'updatedAt': FieldValue.serverTimestamp()}).timeout(
      const Duration(seconds: 20),
    );
    _config = next;
    await AppPrefsService.instance.setKetuntasanJson(jsonEncode(next.toJson()));
  }
}
