import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/services/app_prefs_service.dart';
import '../../../providers/auth_provider.dart';
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
    icon: Icons.auto_stories_rounded,
    title: 'Catat hafalan santri\nlebih rapi',
    subtitle: 'Rekap capaian tahsin & tahfizh setiap santri dalam satu aplikasi.',
  ),
  _OnboardingPage(
    icon: Icons.groups_2_rounded,
    title: 'Fokus ke halaqoh\nmasing-masing',
    subtitle: 'Setiap musyrif hanya melihat kelas & halaqoh yang menjadi tanggung jawabnya.',
  ),
  _OnboardingPage(
    icon: Icons.ios_share_rounded,
    title: 'Siap dibagikan\nkapan saja',
    subtitle: 'Ekspor laporan ke PDF, Excel, atau Word dalam beberapa ketukan.',
  ),
];

/// Onboarding — status penyelesaiannya persistent (Hive lewat
/// AppPrefsService), jadi kalau sudah pernah selesai, layar ini tidak
/// akan ditampilkan lagi (lihat SplashScreen).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  Future<void> _finish() async {
    await AppPrefsService.instance.setOnboardingComplete();
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => auth.isAuthenticated ? const MainShell() : const LoginScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLast = _index == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Lewati'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(page.icon, size: 52, color: cs.primary),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, height: 1.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, height: 1.4),
                        ),
                      ],
                    ),
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
                    color: i == _index ? cs.primary : cs.primary.withValues(alpha: 0.2),
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
                  onPressed: isLast
                      ? _finish
                      : () => _controller.nextPage(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOut,
                          ),
                  child: Text(isLast ? 'Mulai' : 'Lanjut'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
