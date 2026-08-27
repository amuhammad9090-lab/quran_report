import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
      onDidReceiveNotificationResponse: (response) {
        final file = _notifIdToFile[response.id];
        if (file != null) {
          ExportService.instance.openFile(file);
        }
      },
    );
    // Android 13+ perlu izin notifikasi runtime -- di versi lama izin ini
    // otomatis granted, jadi aman dipanggil di semua versi.
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  /// Panggil setelah [ExportService.saveToDevice] sukses.
  Future<void> notifySaved({required String fileName, required ExportedFile file}) async {
    if (kIsWeb || !_initialized) return; // Diamkan kalau belum di-init dari main.dart / di Web.
    final id = _nextId++;
    _notifIdToFile[id] = file;
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
