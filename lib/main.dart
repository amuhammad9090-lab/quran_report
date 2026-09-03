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
import 'data/services/quran_engine_service.dart';
import 'data/services/storage_service.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/folders_provider.dart';
import 'providers/parent_notes_provider.dart'; // <-- BARU
import 'providers/records_provider.dart';
import 'providers/students_provider.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mirror laporan ke Firestore buat Portal Orang Tua. Sign-in
  // ANONIM (bukan akun guru).
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (_) {
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

  // Notifikasi "Catatan dari Orang Tua"
  final parentNotesProvider = ParentNotesProvider();
  parentNotesProvider.updateScope(authProvider.scope);
  parentNotesProvider.start();

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