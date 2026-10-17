import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/services/app_prefs_service.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/common/intro_animations.dart';
import '../home/main_shell.dart';
import 'login_screen.dart';

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;
  const _OnboardingPage({required this.icon, required this.title, required this.subtitle});
}

const _pages = [
  _OnboardingPage(
    icon: LucideIcons.bookOpen,
    title: 'Catat hafalan siswa\nlebih rapi',
    subtitle: 'Rekap capaian tahsin & tahfizh setiap siswa dalam satu aplikasi.',
  ),
  _OnboardingPage(
    icon: LucideIcons.users,
    title: 'Fokus ke halaqoh\nmasing-masing',
    subtitle: 'Setiap guru pembimbing hanya melihat kelas & halaqoh yang menjadi tanggung jawabnya.',
  ),
  _OnboardingPage(
    icon: LucideIcons.upload,
    title: 'Siap dibagikan\nkapan saja',
    subtitle: 'Ekspor laporan ke PDF, Excel, atau Word dalam beberapa ketukan.',
  ),
];

/// Onboarding — status penyelesaiannya persistent (Hive lewat
/// AppPrefsService).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final _controller = PageController();
  int _index = 0;

  // Ikon utama naik-turun pelan (melayang) selama halaman tampil.
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);

  Future<void> _finish() async {
    try {
      await AppPrefsService.instance.setOnboardingComplete();
    } catch (e, st) {
      debugPrint('Gagal simpan status onboarding: $e');
      debugPrint('$st');
    }
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    Navigator.of(context).pushReplacement(
      fadeRoute(auth.isAuthenticated ? const MainShell() : const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;

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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 4, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        child: const Text('Lewati'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) {
                      final page = _pages[i];
                      return AnimatedBuilder(
                        // Efek parallax: ikon dan teks bergeser dengan kecepatan berbeda saat digeser.
                        animation: Listenable.merge([_controller, _float]),
                        builder: (context, _) {
                          var pos = _index.toDouble();
                          if (_controller.hasClients && _controller.position.haveDimensions) {
                            pos = _controller.page ?? pos;
                          }
                          final delta = (pos - i).clamp(-1.0, 1.0);
                          final away = delta.abs();
                          final bob = Curves.easeInOut.transform(_float.value) * 12 - 6;
                          return LayoutBuilder(
                            builder: (context, box) => SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: box.maxHeight),
                            child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Opacity(
                                  opacity: (1 - away * 1.3).clamp(0.0, 1.0),
                                  child: Transform.translate(
                                    offset: Offset(-delta * 120, bob),
                                    child: Transform.scale(
                                      scale: 1 - away * 0.25,
                                      child: PulseRings(
                                        size: 200,
                                        child: Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.18),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.12),
                                                blurRadius: 24,
                                                offset: const Offset(0, 10),
                                              ),
                                            ],
                                          ),
                                          child: Icon(page.icon, size: 52, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Opacity(
                                  opacity: (1 - away * 1.4).clamp(0.0, 1.0),
                                  child: Transform.translate(
                                    offset: Offset(-delta * 60, 0),
                                    child: Text(
                                      page.title,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 22,
                                        height: 1.3,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Opacity(
                                  opacity: (1 - away * 1.6).clamp(0.0, 1.0),
                                  child: Transform.translate(
                                    offset: Offset(-delta * 30, 0),
                                    child: Text(
                                      page.subtitle,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _index ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _index ? Colors.white : Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.splashGradientEnd,
                      ),
                      onPressed: isLast
                          ? _finish
                          : () => _controller.nextPage(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOut,
                              ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim),
                            child: child,
                          ),
                        ),
                        child: Text(isLast ? 'Mulai' : 'Lanjut', key: ValueKey(isLast)),
                      ),
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
