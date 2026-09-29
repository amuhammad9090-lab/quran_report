import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/utils/app_config.dart';

/// Data update dari dokumen Firestore:
/// schools/{kSchoolId}/appConfig/guru_android
///
/// Field:
///  - latestVersionCode (int)  : angka setelah "+" di pubspec (build number)
///  - latestVersionName (str)  : mis. "1.2.0"
///  - minVersionCode    (int)  : di bawah ini => update WAJIB (tanpa tombol "Nanti")
///  - apkUrl            (str)  : link langsung ke file .apk
///  - changelog         (str)  : teks singkat "apa yang baru"
class AppUpdateInfo {
  final int latestVersionCode;
  final String latestVersionName;
  final String apkUrl;
  final String changelog;
  final bool forced;

  const AppUpdateInfo({
    required this.latestVersionCode,
    required this.latestVersionName,
    required this.apkUrl,
    required this.changelog,
    required this.forced,
  });
}

class AppUpdateService {
  AppUpdateService._();

  static const _docPath = 'appConfig/guru_android';

  /// Alasan hasil cek terakhir (buat debug / ditampilkan di SnackBar).
  static String lastStatus = 'belum dicek';

  /// Toleran: terima number maupun string ("2") dari Firestore.
  static int _asInt(Object? v) {
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}'.trim()) ?? 0;
  }

  static void _log(String m) {
    lastStatus = m;
    debugPrint('[update] $m');
  }

  /// Return [AppUpdateInfo] kalau ada versi lebih baru, selain itu null.
  /// Sengaja "fail silent": gagal cek update tidak boleh ganggu app.
  static Future<AppUpdateInfo?> check() async {
    // Hanya Android (APK). Web otomatis selalu versi terbaru.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _log('dilewati: bukan Android');
      return null;
    }

    try {
      final pkg = await PackageInfo.fromPlatform();
      final current = int.tryParse(pkg.buildNumber) ?? 0;

      final snap = await FirebaseFirestore.instance
          .doc('schools/$kSchoolId/$_docPath')
          .get()
          .timeout(const Duration(seconds: 8));
      final d = snap.data();
      if (d == null) {
        _log('dokumen schools/$kSchoolId/$_docPath tidak ditemukan');
        return null;
      }

      final latest = _asInt(d['latestVersionCode']);
      final min = _asInt(d['minVersionCode']);
      final url = (d['apkUrl'] as String?)?.trim() ?? '';
      final status = 'HP build=$current, Firestore latest=$latest min=$min, '
          'apkUrl=${url.isEmpty ? "KOSONG" : "ada"}';

      if (url.isEmpty) {
        _log('$status -> apkUrl kosong');
        return null;
      }
      if (latest <= current) {
        _log('$status -> sudah versi terbaru (latest harus > build HP)');
        return null;
      }
      _log('$status -> ADA UPDATE');

      return AppUpdateInfo(
        latestVersionCode: latest,
        latestVersionName: (d['latestVersionName'] as String?) ?? '',
        apkUrl: url,
        changelog: (d['changelog'] as String?) ?? '',
        forced: current < min,
      );
    } catch (e) {
      _log('gagal cek update: $e');
      return null;
    }
  }
}
