import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/services/app_prefs_service.dart';
import 'data/services/download_notification_service.dart';
import 'data/services/firebase_bootstrap_status.dart';
import 'data/services/quran_engine_service.dart';
import 'data/services/storage_service.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/folders_provider.dart';
import 'providers/parent_notes_provider.dart';
import 'providers/records_provider.dart';
import 'providers/students_provider.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mirror laporan ke Firestore buat Portal Orang Tua. Sign-in
  // ANONIM (bukan akun guru).
  try {
    // <-- BERUBAH: `if (Firebase.apps.isEmpty)` diganti jadi langsung
    // coba initializeApp() + tangkep KHUSUS 'duplicate-app'.
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
      debugPrint('Firebase app "[DEFAULT]" sudah ada duluan (native/hot-restart) -- pakai yang itu.');
    }

    final auth = FirebaseAuth.instance;
    final cached = auth.currentUser;
    if (cached == null) {
      await auth.signInAnonymously();
    } else {
      // reload() beneran nge-fetch ulang ke server -- lebih reliable
      // buat deteksi akun anonim lama yang udah invalid/kehapus
      // dibanding cuma getIdToken(true) doang.
      try {
        await cached.reload();
        final refreshedUser = auth.currentUser;
        if (refreshedUser == null) {
          await auth.signInAnonymously();
        } else {
          await refreshedUser.getIdToken(true);
        }
      } catch (_) {
        await auth.signOut();
        await auth.signInAnonymously();
      }
    }
    FirebaseBootstrapStatus.markReady();
    // BUG FIX (web): dulu ada blok `FirebaseFirestore.instance.settings =
    // Settings(webExperimentalForceLongPolling: true, persistenceEnabled:
    // false)` di sini, tapi kecabut lagi -- makanya Cloud Backup/Pulihkan
    // & Deploy dua-duanya timeout "server tidak merespons" KHUSUS di
    // web-app (Android normal). Ini bug KLASIK Firestore Web SDK: secara
    // default dia nyoba konek pake WebChannel streaming (mirip
    // long-lived HTTP/2 stream) buat komunikasi ke server -- koneksi ini
    // gampang banget di-block/gagal diam-diam (nyangkut, gak
    // error langsung, cuma nunggu sampai timeout) sama proxy/firewall
    // kantor/sekolah, sebagian ISP, atau ad-blocker browser. Android
    // (gRPC native) gak kena masalah ini sama sekali -- makanya app
    // Android mulus tapi web-nya macet PERSIS di 2 fitur yang sama-sama
    // manggil FirebaseFirestore.instance (Backup/Restore & Deploy).
    // Fix: khusus di web, suruh Firestore otomatis DETEKSI kalau
    // WebChannel gagal dan otomatis ganti ke long-polling (HTTP request
    // biasa yang jarang di-block) -- `webExperimentalAutoDetectLongPolling`
    // lebih aman dari versi "force" (cuma pindah ke long-polling kalau
    // memang perlu, bukan maksa selalu). `persistenceEnabled: false`
    // juga dimatiin di web biar gak ada cache IndexedDB antar-tab yang
    // kadang ikut bikin nyangkut. HARUS diset sebelum Firestore
    // dipakai sama sekali (makanya taruh di sini, bukan di
    // StorageService/WeeklyRecapDeployService).
    if (kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
        webExperimentalAutoDetectLongPolling: true,
      );
    }
  } catch (e, st) {
    debugPrint('Firebase init/sign-in anonim GAGAL: $e');
    debugPrint('$st');
    FirebaseBootstrapStatus.markFailed(e);
  }

  if (!kIsWeb) {
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = 'Quran Report';
  }

  await initializeDateFormatting('id_ID', null);
  await StorageService.instance.init();
  await AppPrefsService.instance.init();
  await QuranEngineService.instance.load();
  await DownloadNotificationService.instance.init();

  final themeProvider = ThemeProvider();
  await themeProvider.load();

  final authProvider = AuthProvider();
  await authProvider.restoreSession();

  final recordsProvider = RecordsProvider();
  await recordsProvider.load();

  recordsProvider.updateScope(authProvider.scope);

  final foldersProvider = FoldersProvider();
  await foldersProvider.load();

  final studentsProvider = StudentsProvider();
  await studentsProvider.load();

  final parentNotesProvider = ParentNotesProvider();
  parentNotesProvider.updateScope(authProvider.scope);
  // <-- SEMENTARA DIMATIKAN buat isolasi bug timeout/webchannel

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: recordsProvider),
        ChangeNotifierProvider.value(value: foldersProvider),
        ChangeNotifierProvider.value(value: studentsProvider),
        ChangeNotifierProvider.value(value: parentNotesProvider),
      ],
      child: const QuranReportApp(),
    ),
  );
}