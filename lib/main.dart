import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/services/quran_engine_service.dart';
import 'data/services/storage_service.dart';
import 'providers/records_provider.dart';
import 'providers/folders_provider.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id_ID', null);
  await StorageService.instance.init();
  await QuranEngineService.instance.load();

  final themeProvider = ThemeProvider();
  await themeProvider.load();

  final recordsProvider = RecordsProvider();
  await recordsProvider.load();

  final foldersProvider = FoldersProvider();
  await foldersProvider.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: recordsProvider),
        ChangeNotifierProvider.value(value: foldersProvider),
      ],
      child: const QuranReportApp(),
    ),
  );
}
