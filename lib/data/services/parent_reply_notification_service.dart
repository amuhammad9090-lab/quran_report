// <-- BARU (seluruh file)
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../app.dart';
import '../../presentation/screens/notifications/notifications_screen.dart';
import '../models/parent_note.dart';
import 'app_prefs_service.dart';

/// Local push notification khusus buat "Balasan Orang Tua" (ParentNotes)
/// -- Opsi B dari diskusi peningkatan app (skeleton loading DIBATALKAN,
/// notifikasi TETAP jalan tapi tanpa Cloud Functions/FCM server-side).
///
/// KENAPA LOCAL NOTIFICATION, BUKAN FCM BENERAN:
/// Project ini SENGAJA didesain tanpa Cloud Functions sama sekali (lihat
/// catatan panjang di `firestore.rules` soal plan Spark) -- push
/// notification FCM yang beneran nyampe pas app di-KILL TOTAL butuh
/// server-side trigger (Cloud Function yang jalan begitu dokumen
/// `parentNotes` baru dibuat), dan itu WAJIB upgrade ke plan Blaze +
/// nambah backend baru di luar Flutter app ini -- perubahan arsitektur
/// besar yang di luar cakupan permintaan ini (user sudah pilih skip opsi
/// itu). Solusi ini pakai listener Firestore yang SUDAH ADA di
/// [ParentNotesProvider] (live stream, bukan FCM) buat trigger
/// `flutter_local_notifications` yang JUGA SUDAH ADA di project (dipakai
/// [DownloadNotificationService]) begitu ada catatan baru masuk.
///
/// KONSEKUENSI (WAJIB DIPAHAMI): notifikasi ini CUMA nyala selama proses
/// app masih hidup (foreground ATAU background biasa/minimized) --
/// PERSIS seperti listener Firestore lain di app ini. Kalau app di-SWIPE
/// KILL TOTAL dari recent-apps, listener-nya ikut mati, dan balasan baru
/// yang masuk selama itu TIDAK akan memicu notifikasi sampai app dibuka
/// manual lagi (beda dari FCM asli yang tetap nyampe walau app mati).
/// Ini trade-off yang disadari & disetujui, bukan bug.
///
/// SETUP TAMBAHAN YANG DIBUTUHKAN (belum otomatis lewat kode ini saja):
/// 1) `flutter_local_notifications` & `POST_NOTIFICATIONS` permission
///    SUDAH ADA di project ini (dipakai [DownloadNotificationService]) --
///    tidak perlu setup ulang.
/// 2) Panggil [ParentReplyNotificationService.instance.init()] SEKALI di
///    main.dart, SEBELUM `runApp()` -- sejajar dengan
///    `DownloadNotificationService.instance.init()`.
/// 3) `QuranReportApp.navigatorKey` (lihat app.dart) WAJIB dipasang ke
///    `MaterialApp.navigatorKey` -- dipakai buat buka halaman Notifikasi
///    dari sini tanpa butuh BuildContext (perlu banget buat kasus tap
///    notifikasi pas app baru saja nyala dari kondisi mati/terminated).
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

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Notification id dibuat deterministik dari hash id dokumen ParentNote
  // (bukan counter incremental seperti DownloadNotificationService) --
  // supaya kalau ada race/duplicate event buat catatan yang SAMA, id-nya
  // sama juga (plugin otomatis replace notifikasi lama, bukan numpuk
  // notifikasi ganda -- lihat B21 "Hindari duplicate notification").
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

    // TERMINATED STATE (B12): app baru nyala TOTAL dari nol gara-gara tap
    // notifikasi ini. Beda dari DownloadNotificationService yang cukup
    // langsung buka file, di sini kita perlu NAVIGASI (buka halaman
    // Notifikasi) -- dan Navigator/provider tree PASTI belum siap sama
    // sekali di titik ini (dipanggil sebelum runApp()). Ditunda lewat
    // [_navigateAfterAppReady] yang nunggu SplashScreen selesai
    // redirect-nya dulu (lihat dokumentasi method itu).
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

  /// Buka halaman Notifikasi + tandai catatan terkait sudah dibaca.
  ///
  /// [coldStart]=true berarti app baru saja nyala TOTAL gara-gara tap
  /// notifikasi ini (dipanggil dari `init()`, sebelum `runApp()`).
  /// SplashScreen (lihat splash_screen.dart) selalu nahan 3000ms sebelum
  /// `pushReplacement` ke Login/Home -- kalau kita push halaman
  /// Notifikasi lebih cepat dari itu, hasilnya bisa numpuk aneh di atas
  /// Splash yang belum sempat redirect. Solusi paling sederhana & aman
  /// (tanpa ubah SplashScreen sama sekali, sesuai batasan "jangan ubah
  /// navigation existing"): tunggu sedikit lebih lama dari delay Splash
  /// itu, BARU push -- di titik itu Splash sudah pasti selesai redirect
  /// ke Home/Login, jadi halaman Notifikasi mendarat bersih di atasnya.
  /// Untuk tap selagi app hidup ([coldStart]=false), Splash sudah lama
  /// lewat, jadi push langsung tanpa delay tambahan.
  Future<void> _navigateAfterAppReady(String noteId, {required bool coldStart}) async {
    if (coldStart) {
      await Future.delayed(const Duration(milliseconds: 3400));
    } else {
      // Tetap tunggu 1 frame biar aman kalau method ini kebetulan
      // terpanggil sebelum navigator ke-attach penuh.
      await Future.delayed(Duration.zero);
    }
    final nav = QuranReportApp.navigatorKey.currentState;
    if (nav == null) return; // App ditutup lagi / navigator belum siap -- jangan crash.
    nav.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    await AppPrefsService.instance.removePendingParentReplyNoteId();
    // markAsRead spesifik catatan ybs SENGAJA tidak dipanggil dari sini
    // (service ini tidak boleh butuh akses Provider tree/BuildContext
    // buat baca ParentNotesProvider) -- guru tetap bisa tandai baca
    // manual seperti biasa begitu halaman Notifikasi kebuka. Membuka
    // halaman yang benar sudah memenuhi maksud "buka thread terkait"
    // (B13) karena app ini memang tidak punya halaman detail per-thread
    // terpisah -- daftar Notifikasi ITU SENDIRI adalah "thread"-nya
    // (lihat notifications_screen.dart).
  }

  /// Dipanggil dari [ParentNotesProvider] setiap kali stream Firestore
  /// yang SUDAH ADA mendeteksi catatan BENAR-BENAR baru (bukan snapshot
  /// awal, bukan update field isRead/dismissed) -- lihat dokumentasi
  /// lengkap soal deteksi "baru" di parent_notes_provider.dart.
  Future<void> notifyNewReply(ParentNote note) async {
    if (kIsWeb || !_initialized) return;
    // Persist noteId (bukan cuma in-memory) supaya kalau app di-kill
    // SEBELUM notifikasi sempat di-tap, lalu di-tap belakangan dari
    // notification tray sistem (yang mentrigger cold start), payload-nya
    // tetap valid walau proses Dart sebelumnya sudah tidak ada -- pola
    // sama persis dengan `AppPrefsService.downloadNotifPaths` di
    // DownloadNotificationService.
    await AppPrefsService.instance.setPendingParentReplyNoteId(note.id);

    final preview = _truncate(note.message);
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      // Body panjang (preview pesan) sering kepotong di 1 baris kalau
      // cuma pakai body biasa -- BigTextStyleInformation biar full
      // preview-nya kebaca begitu notifikasi di-expand, sesuai B4/B10
      // ("isi pesan tampil langsung", bukan cuma 1 baris kepotong).
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
