import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/services/app_prefs_service.dart';
import '../../../providers/auth_provider.dart';
import '../home/main_shell.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

/// Splash — titik masuk app. Alur startup:
///
///   Splash -> cek onboarding -> cek session -> Onboarding / Login / Home
///
/// Catatan: seluruh data (records/folders/theme/session) sudah di-load
/// SEBELUM runApp (lihat main.dart), jadi Splash di sini murni identitas
/// merek sebentar + keputusan routing, bukan loading state yang berat.
///
/// Layar ini BARU (project sebelumnya belum punya splash/onboarding/login
/// sama sekali) — sengaja dibuat sesederhana mungkin & senada dengan
/// design system existing (bukan "redesign" karena tidak ada yang
/// digantikan), supaya gampang dipoles lagi nanti.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    // Jeda sebentar murni buat keliatan brand-nya, bukan nunggu data
    // (data udah siap semua sebelum runApp).
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final onboardingDone = AppPrefsService.instance.onboardingComplete;
    final auth = context.read<AuthProvider>();

    Widget next;
    if (!onboardingDone) {
      next = const OnboardingScreen();
    } else if (!auth.isAuthenticated) {
      next = const LoginScreen();
    } else {
      next = const MainShell();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 42),
            ),
            const SizedBox(height: 20),
            const Text(
              'Quran Report',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Laporan tahsin & tahfizh santri',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
