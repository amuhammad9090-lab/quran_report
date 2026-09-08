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

// <-- BARU: helper ini, dipisah dari main() biar bisa dibungkus
// [Future.timeout] (lihat catatan panjang di main()).
Future<void> _signInAnonymouslyIfNeeded(FirebaseAuth auth) async {
  final cached = auth.currentUser;
  if (cached == null) {
    await auth.signInAnonymously();
    return;
  }
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
      debugPrint('Firebase app "[DEFAULT]" sudah ada duluan (native/hot-restart) -- pakai yang itu.');
    }

    // <-- BERUBAH: dibungkus [timeout]. Sebelumnya sign-in anonim (atau
    // reload/refresh token buat sesi yang udah ada) SAMA SEKALI gak
    // punya batas waktu -- kalau sinyal lagi lemah/lambat pas app
    // dibuka, `await` ini bisa nggantung lama (SDK Firebase nunggu
    // cukup lama sebelum nyerah sendiri), dan karena semua ini kejadian
    // SEBELUM runApp(), splash/launcher-nya ikut nggantung selama itu
    // juga -- persis gejala "kadang lama kadang biasa aja" tergantung
    // kualitas sinyal pas itu.
    //
    // Sekarang dikasih batas 8 detik: kalau kelamaan, app TETAP lanjut
    // ke runApp() (fitur cloud jadi nonaktif sementara, sama seperti
    // skenario gagal biasa -- lihat FirebaseBootstrapStatus &
    // userMessage-nya).
    await _signInAnonymouslyIfNeeded(FirebaseAuth.instance)
        .timeout(const Duration(seconds: 8));

    FirebaseBootstrapStatus.markReady();
    if (kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
        webExperimentalAutoDetectLongPolling: true,
      );
    }
  } catch (e, st) {
    debugPrint('Firebase init/sign-in anonim GAGAL (atau timeout jaringan): $e');
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