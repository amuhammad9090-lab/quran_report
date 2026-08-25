import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'presentation/screens/auth/splash_screen.dart';

class QuranReportApp extends StatelessWidget {
  const QuranReportApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Quran Report',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.mode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      locale: const Locale('id', 'ID'),
      // Banyak kartu/baris di app ini (mis. tabel Rekap Bulanan, kartu
      // santri) didesain dengan tinggi & padding yang pas untuk skala
      // teks normal. Kalau user set font sistem Android-nya ke paling
      // besar (200%), layout itu bisa pecah/overflow parah. Di-clamp ke
      // rentang 0.85-1.25 biar tetap ada penyesuaian buat aksesibilitas,
      // tapi nggak sampai merusak layout.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.25),
          ),
          child: child!,
        );
      },
      // Startup routing: Splash -> (Onboarding kalau belum selesai) ->
      // (Login kalau belum authenticated) -> Home. Lihat SplashScreen.
      home: const SplashScreen(),
    );
  }
}
