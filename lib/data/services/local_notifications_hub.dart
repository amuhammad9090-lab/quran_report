import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Pintu tunggal ke plugin notifikasi lokal. Plugin hanya punya SATU callback tap: bila dua service
/// memanggil `initialize` sendiri-sendiri, yang terakhir menimpa dan tap salah alamat. Di sini
/// `initialize` cukup sekali dan tap diteruskan ke service pemilik notifikasinya.
class LocalNotificationsHub {
  LocalNotificationsHub._();
  static final LocalNotificationsHub instance = LocalNotificationsHub._();

  /// Payload notifikasi unduhan. Notifikasi unduhan lama tanpa payload (null) tetap dianggap unduhan.
  static const downloadPayloadPrefix = 'download:';

  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  /// Dipasang DownloadNotificationService: menerima id notifikasi unduhan yang diketuk.
  void Function(int? id)? onDownloadTap;

  /// Dipasang ParentReplyNotificationService: menerima id catatan dari notifikasi balasan ortu.
  void Function(String noteId)? onParentReplyTap;

  Future<void>? _initFuture;
  NotificationResponse? _launchResponse;

  /// Notifikasi yang mengetuk-membuka app dari kondisi tertutup total (null kalau tidak ada).
  /// Tiap service memeriksa apakah itu miliknya setelah [ensureInitialized].
  NotificationResponse? get launchResponse => _launchResponse;

  /// Aman dipanggil berkali-kali; inisialisasi plugin hanya jalan sekali. No-op di Web.
  Future<void> ensureInitialized() => _initFuture ??= _init();

  Future<void> _init() async {
    if (kIsWeb) return;
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await plugin.initialize(initSettings, onDidReceiveNotificationResponse: _dispatch);
    // Android 13+ butuh izin notifikasi runtime; di versi lama otomatis granted.
    await plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    final details = await plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      _launchResponse = details?.notificationResponse;
    }
  }

  /// True bila [response] milik notifikasi unduhan (payload kosong atau berawalan `download:`).
  static bool isDownloadResponse(NotificationResponse response) {
    final payload = response.payload;
    return payload == null || payload.startsWith(downloadPayloadPrefix);
  }

  /// Id catatan bila [response] milik notifikasi balasan orang tua, selain itu null.
  static String? parentReplyNoteId(NotificationResponse response) =>
      isDownloadResponse(response) ? null : response.payload;

  void _dispatch(NotificationResponse response) {
    final noteId = parentReplyNoteId(response);
    if (noteId != null) {
      onParentReplyTap?.call(noteId);
    } else {
      onDownloadTap?.call(response.id);
    }
  }
}
