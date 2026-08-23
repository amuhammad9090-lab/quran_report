import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/services/app_prefs_service.dart';
import 'data/services/quran_engine_service.dart';
import 'data/services/storage_service.dart';
import 'providers/auth_provider.dart';
import 'providers/folders_provider.dart';
import 'providers/records_provider.dart';
import 'providers/students_provider.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id_ID', null);
  await StorageService.instance.init();
  // AppPrefsService pakai Hive yang sama — init setelah StorageService
  // supaya Hive.initFlutter() cuma dipanggil sekali (di StorageService).
  await AppPrefsService.instance.init();
  await QuranEngineService.instance.load();

  final themeProvider = ThemeProvider();
  await themeProvider.load();

  final authProvider = AuthProvider();
  // Coba pulihkan session yang tersimpan, biar user yang sebelumnya udah
  // login nggak perlu login ulang tiap buka app.
  await authProvider.restoreSession();

  final recordsProvider = RecordsProvider();
  await recordsProvider.load();
  // Kalau session berhasil dipulihkan, langsung terapkan scope-nya dari
  // awal (sebelum widget pertama render) — biar nggak ada "kedipan"
  // data yang belum ke-scope pas app baru dibuka.
  recordsProvider.updateScope(authProvider.scope);

  final foldersProvider = FoldersProvider();
  await foldersProvider.load();

  final studentsProvider = StudentsProvider();
  await studentsProvider.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: recordsProvider),
        ChangeNotifierProvider.value(value: foldersProvider),
        ChangeNotifierProvider.value(value: studentsProvider),
      ],
      child: const QuranReportApp(),
    ),
  );
}
