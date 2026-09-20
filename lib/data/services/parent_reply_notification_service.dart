import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/parent_note.dart';
import 'app_prefs_service.dart';

/// Notifikasi lokal "Balasan Orang Tua", dipicu stream [ParentNotesProvider] (bukan FCM/Cloud
/// Functions, jadi hanya aktif selama proses app hidup). Setup: [init] sekali sebelum `runApp()`
/// + pasang [onOpenNotifications] (main.dart); service ini tidak mengenal UI/navigator.
class ParentReplyNotificationService {
  ParentReplyNotificationService._();
  static final ParentReplyNotificationService instance = ParentReplyNotificationService._();

  static const _channelId = 'parent_reply';
  static const _channelName = 'Balasan Orang Tua';
  static const _channelDesc = 'Notifikasi saat orang tua membalas catatan lewat Portal Ortu';

  /// Panjang maksimal preview pesan di notification body (B5: truncate
  /// HANYA di notifikasi, pesan asli di Firestore/UI dalam app tidak
  /// pernah disentuh/diubah oleh service ini).
  static const _previewMaxLength = 100;

  /// Dipasang dari luar (main.dart): membuka halaman Notifikasi lewat navigator app.
  /// Mengembalikan true kalau berhasil membuka, false kalau navigator belum siap/app ditutup.
  bool Function()? onOpenNotifications;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Id notifikasi deterministik dari hash id ParentNote (bukan counter), jadi event duplikat
  // untuk catatan yang SAMA menimpa notifikasi lama, tidak menumpuk (B21).
  int _notifIdFor(String noteId) => noteId.hashCode & 0x7fffffff;

  Future<void> init() async {
    if (kIsWeb || _initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      // Tap selagi app HIDUP (foreground/background, proses belum
      // di-kill) -- payload (noteId) diambil dari `response.payload`.
      onDidReceiveNotificationResponse: (response) => _handleTap(response.payload),
    );
    // Android 13+ butuh izin runtime -- sudah pernah diminta juga oleh
    // DownloadNotificationService.init(), memanggil ini lagi aman
    // (no-op kalau sudah granted/pernah ditolak).
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;

    // TERMINATED STATE (B12): app nyala dari nol karena tap notifikasi. Navigator/provider tree
    // belum siap (sebelum runApp()), jadi navigasi ditunda lewat [_navigateAfterAppReady]
    // yang menunggu SplashScreen selesai redirect.
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null) _navigateAfterAppReady(payload, coldStart: true);
    }
  }

  void _handleTap(String? payload) {
    if (payload == null) return;
    // App masih hidup (bukan cold start) -- Navigator sudah pasti siap
    // (splash sudah lewat lama), langsung navigasi tanpa delay.
    _navigateAfterAppReady(payload, coldStart: false);
  }

  /// Buka halaman Notifikasi lewat [onOpenNotifications]. Saat [coldStart] menunggu 3400ms
  /// (lebih lama dari delay 3000ms SplashScreen) agar halaman mendarat bersih setelah
  /// redirect ke Home/Login, tanpa mengubah SplashScreen; tap saat app hidup langsung push.
  Future<void> _navigateAfterAppReady(String noteId, {required bool coldStart}) async {
    if (coldStart) {
      await Future.delayed(const Duration(milliseconds: 3400));
    } else {
      // Tetap tunggu 1 frame biar aman kalau method ini kebetulan
      // terpanggil sebelum navigator ke-attach penuh.
      await Future.delayed(Duration.zero);
    }
    final opened = onOpenNotifications?.call() ?? false;
    if (!opened) return; // App ditutup lagi / navigator belum siap -- jangan crash.
    await AppPrefsService.instance.removePendingParentReplyNoteId();
    // markAsRead catatan ybs SENGAJA tidak dipanggil dari sini (service tak boleh mengakses
    // Provider tree); guru menandai baca manual di halaman Notifikasi, yang memang
    // satu-satunya "thread" (tidak ada halaman detail per-thread).
  }

  /// Dipanggil dari [ParentNotesProvider] saat stream Firestore yang SUDAH ADA mendeteksi
  /// catatan BENAR-BENAR baru (bukan snapshot awal / update isRead/dismissed) — lihat
  /// parent_notes_provider.dart.
  Future<void> notifyNewReply(ParentNote note) async {
    if (kIsWeb || !_initialized) return;
    // Persist noteId (bukan in-memory) supaya tap dari notification tray setelah app di-kill
    // (cold start) tetap valid — pola sama dengan `AppPrefsService.downloadNotifPaths`
    // di DownloadNotificationService.
    await AppPrefsService.instance.setPendingParentReplyNoteId(note.id);

    final preview = _truncate(note.message);
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      // BigTextStyleInformation agar preview panjang tidak kepotong 1 baris saat notifikasi
      // di-expand (B4/B10: isi pesan tampil langsung).
      styleInformation: BigTextStyleInformation(preview),
    );
    await _plugin.show(
      _notifIdFor(note.id),
      'Balasan Orang Tua ${note.namaAnak}',
      preview,
      NotificationDetails(android: androidDetails),
      payload: note.id,
    );
  }

  String _truncate(String message) {
    final trimmed = message.trim();
    if (trimmed.length <= _previewMaxLength) return trimmed;
    return '${trimmed.substring(0, _previewMaxLength).trimRight()}...';
  }
}
