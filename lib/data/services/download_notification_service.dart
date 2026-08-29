import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_prefs_service.dart';
import 'export_service.dart';
import 'platform_file/exported_file.dart';

/// Nampilin notifikasi status unduhan ("Tersimpan ke Download") di
/// notification tray HP tiap kali user simpan file ekspor ke penyimpanan
/// perangkat lewat [ExportService.saveToDevice] -- Bug #1 di laporan bug:
/// sebelumnya proses simpan cuma nampilin SnackBar sesaat di dalam app,
/// nggak ada jejak apapun di notifikasi sistem. (Sempat ada bug lain yang
/// nyusul: `saveToDevice` ternyata nggak beneran nulis ke folder Download
/// PUBLIK di Android -- lihat catatan panjang di
/// [ExportService.saveToDevice] -- sudah dibenerin lewat penggantian
/// package, jadi sekarang notifikasi ini valid: filenya emang beneran ada
/// di Download publik pas notifikasi ini muncul.)
///
/// Di Web, seluruh service ini SENGAJA no-op ([kIsWeb] check di [init] &
/// [notifySaved]) -- browser sudah punya UI/notifikasi downloadnya
/// sendiri (bar unduhan bawaan), notifikasi sistem tambahan dari app
/// cuma redundant/tidak relevan di konteks web, dan `flutter_local_
/// notifications` versi Android (`AndroidNotificationDetails` di bawah)
/// memang tidak berlaku di sana.
///
/// CATATAN SETUP (belum otomatis lewat kode ini saja, karena repo yang
/// dianalisis cuma folder lib/ -- pubspec.yaml & folder android/ tidak ada
/// di dalamnya):
/// 1) Tambahkan dependency di pubspec.yaml:
///      flutter_local_notifications: ^18.0.0   // sesuaikan versi terbaru
/// 2) Di android/app/src/main/AndroidManifest.xml, pastikan ada:
///      <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
///    (wajib buat Android 13/API 33 ke atas -- tanpa ini permintaan izin
///    notifikasi di [init] bakal selalu gagal diam-diam.)
/// 3) Panggil [DownloadNotificationService.instance.init()] SEKALI di
///    main.dart, sejajar dengan StorageService.instance.init() dkk,
///    SEBELUM runApp() dipanggil.
class DownloadNotificationService {
  DownloadNotificationService._();
  static final DownloadNotificationService instance = DownloadNotificationService._();

  static const _channelId = 'download_status';
  static const _channelName = 'Status Unduhan';
  static const _channelDesc = 'Notifikasi saat laporan berhasil disimpan ke Download';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // File yang lagi/baru saja ditampilkan notifnya, dipetakan dari id
  // notifikasi -> ExportedFile, supaya tap notifikasi bisa langsung buka
  // filenya lagi (pakai ExportService.openFile yang sama).
  final Map<int, ExportedFile> _notifIdToFile = {};
  int _nextId = 1000;

  Future<void> init() async {
    if (kIsWeb || _initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      // Ini nangkep tap notifikasi selagi app HIDUP (foreground/background,
      // proses belum di-kill) — di kondisi ini `_notifIdToFile` in-memory
      // masih valid, jadi cukup pakai itu.
      onDidReceiveNotificationResponse: (response) => _openFromNotification(response.id),
    );
    // Android 13+ perlu izin notifikasi runtime -- di versi lama izin ini
    // otomatis granted, jadi aman dipanggil di semua versi.
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;

    // BUG FIX: kalau app di-tap dari notifikasi PAS LAGI KETUTUP TOTAL
    // (bukan cuma minimize), Flutter/plugin baru nyala ulang dari nol —
    // `_notifIdToFile` in-memory di atas otomatis KOSONG lagi (state RAM
    // sebelumnya sudah hilang), dan callback `onDidReceiveNotificationResponse`
    // di atas TIDAK dipanggil buat tap yang justru MENYALAKAN app ini
    // (cuma berlaku buat tap selagi app sudah hidup). Makanya sebelumnya
    // tap notifikasi kelihatan "gak ngapa-ngapain" kalau app-nya sempat
    // ketutup duluan. Fix: cek [getNotificationAppLaunchDetails] di sini,
    // dan kalau memang app ini nyala gara-gara tap notifikasi kita, ambil
    // path file dari penyimpanan PERSISTEN (bukan in-memory — lihat
    // AppPrefsService.downloadNotifPaths) lalu buka langsung.
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final id = launchDetails?.notificationResponse?.id;
      if (id != null) await _openFromNotification(id);
    }
  }

  Future<void> _openFromNotification(int? id) async {
    if (id == null) return;
    // In-memory dulu (jalur cepat kalau app-nya emang masih hidup dari
    // tadi), fallback ke penyimpanan persisten kalau kosong (app baru
    // saja nyala ulang gara-gara tap notifikasi ini).
    var file = _notifIdToFile[id];
    if (file == null) {
      final path = AppPrefsService.instance.downloadNotifPaths['$id'];
      if (path == null) return;
      file = ExportedFile(bytes: Uint8List(0), filename: path.split('/').last, path: path);
    }
    await ExportService.instance.openFile(file);
    _notifIdToFile.remove(id);
    await AppPrefsService.instance.removeDownloadNotifPath(id);
  }

  /// Panggil setelah [ExportService.saveToDevice] sukses.
  Future<void> notifySaved({required String fileName, required ExportedFile file}) async {
    if (kIsWeb || !_initialized) return; // Diamkan kalau belum di-init dari main.dart / di Web.
    final id = _nextId++;
    _notifIdToFile[id] = file;
    if (file.path != null) {
      await AppPrefsService.instance.setDownloadNotifPath(id, file.path!);
    }
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );
    await _plugin.show(
      id,
      'Unduhan selesai',
      '$fileName tersimpan ke folder Download. Ketuk untuk membuka.',
      const NotificationDetails(android: androidDetails),
    );
  }
}
