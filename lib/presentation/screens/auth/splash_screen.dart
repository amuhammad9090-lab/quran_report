import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/services/app_prefs_service.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../home/main_shell.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

/// Splash — titik masuk app. Alur startup:
/// Splash -> cek onboarding -> cek session -> Onboarding / Login / Home
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
    await Future.delayed(const Duration(milliseconds: 3000));
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.splashGradientStart, AppColors.splashGradientEnd],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppIconMark(size: 96, borderRadius: 26),
                      const SizedBox(height: 22),
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
                        'Laporan Tahsin & Tahfizh Santri',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 28,
                  child: Column(
                    children: [
                      const SmpitLogoBadge(size: 44, withBackground: false),
                      const SizedBox(height: 10),
                      Text(
                        'Powered by SMPIT Al Madinah',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
