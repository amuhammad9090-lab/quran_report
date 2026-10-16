import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/services/app_prefs_service.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/common/app_icon_mark.dart';
import '../../widgets/common/intro_animations.dart';
import '../../widgets/common/smpit_logo_badge.dart';
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

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  // Gelembung latar yang bergerak pelan (bolak-balik) supaya latar tidak terasa statis.
  late final AnimationController _drift =
      AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
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

    Navigator.of(context).pushReplacement(fadeRoute(next));
  }

  Widget _bubble(double size, double alpha, Alignment from, Alignment to) {
    return AnimatedBuilder(
      animation: _drift,
      builder: (context, _) => Align(
        alignment: Alignment.lerp(from, to, Curves.easeInOut.transform(_drift.value))!,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
        ),
      ),
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
                _bubble(220, 0.06, const Alignment(-1.3, -0.9), const Alignment(-0.9, -0.6)),
                _bubble(160, 0.05, const Alignment(1.3, 0.2), const Alignment(0.95, 0.45)),
                _bubble(110, 0.06, const Alignment(-0.9, 0.95), const Alignment(-0.5, 0.75)),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PulseRings(
                        size: 230,
                        child: FadeSlideIn(
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutBack,
                          offset: Offset.zero,
                          scaleFrom: 0.3,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 28,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: const AppIconMark(size: 96, borderRadius: 26),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const FadeSlideIn(
                        delay: Duration(milliseconds: 550),
                        child: Text(
                          'Quran Report',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 750),
                        child: Text(
                          'Laporan Tahsin & Tahfizh Siswa',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const FadeSlideIn(
                        delay: Duration(milliseconds: 1100),
                        offset: Offset.zero,
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation(Colors.white70),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 28,
                  child: FadeSlideIn(
                    delay: const Duration(milliseconds: 1000),
                    offset: const Offset(0, 14),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
