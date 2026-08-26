import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'export_service.dart';

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
  // notifikasi -> path file, supaya tap notifikasi bisa langsung buka
  // filenya (pakai OpenFilex yang sama dengan ExportService.openFile).
  final Map<int, String> _notifIdToPath = {};
  int _nextId = 1000;

  Future<void> init() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final path = _notifIdToPath[response.id];
        if (path != null) {
          ExportService.instance.openFile(File(path));
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
  Future<void> notifySaved({required String fileName, required File file}) async {
    if (!_initialized) return; // Diamkan kalau belum di-init dari main.dart.
    final id = _nextId++;
    _notifIdToPath[id] = file.path;
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
