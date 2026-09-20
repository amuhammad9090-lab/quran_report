import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_prefs_service.dart';
import 'export_service.dart';
import 'local_notifications_hub.dart';
import 'platform_file/exported_file.dart';

/// Notifikasi "Unduhan selesai" di notification tray setiap kali user menyimpan file export ke
/// perangkat lewat [ExportService.saveToDevice]; mengetuknya membuka file hasil unduhan. No-op di
/// Web (browser sudah punya UI unduhan sendiri). Panggil [init] sekali di main.dart sebelum runApp().
class DownloadNotificationService {
  DownloadNotificationService._();
  static final DownloadNotificationService instance = DownloadNotificationService._();

  static const _channelId = 'download_status';
  static const _channelName = 'Status Unduhan';
  static const _channelDesc = 'Notifikasi saat laporan berhasil disimpan ke Download';

  final _hub = LocalNotificationsHub.instance;
  bool _initialized = false;

  // Id notifikasi -> ExportedFile, supaya tap langsung membuka file yang sama lewat
  // ExportService.openFile. Setelah app dimatikan, path diambil dari AppPrefsService.downloadNotifPaths.
  final Map<int, ExportedFile> _notifIdToFile = {};
  int _nextId = 1000;

  Future<void> init() async {
    if (kIsWeb || _initialized) return;
    // Tap selagi app hidup: tetap lewat hub agar tidak bentrok dengan notifikasi lain.
    _hub.onDownloadTap = (id) {
      _openFromNotification(id);
    };
    await _hub.ensureInitialized();
    _initialized = true;

    // App dinyalakan dari nol oleh tap notifikasi unduhan: callback tap live TIDAK dipanggil untuk
    // tap itu, jadi baca launch details dan buka file dari path yang dipersist (bukan in-memory).
    final launch = _hub.launchResponse;
    if (launch != null && LocalNotificationsHub.isDownloadResponse(launch)) {
      final id = launch.id;
      if (id != null) await _openFromNotification(id);
    }
  }

  Future<void> _openFromNotification(int? id) async {
    if (id == null) return;
    // In-memory dulu (app masih hidup), fallback ke penyimpanan persisten (app baru menyala).
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
    await _hub.plugin.show(
      id,
      'Unduhan selesai',
      '$fileName tersimpan ke folder Download. Ketuk untuk membuka.',
      const NotificationDetails(android: androidDetails),
      payload: '${LocalNotificationsHub.downloadPayloadPrefix}$id',
    );
  }
}
