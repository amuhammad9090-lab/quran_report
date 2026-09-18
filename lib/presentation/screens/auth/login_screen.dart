import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/parent_notes_provider.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../home/main_shell.dart';

/// Login — SATU-SATUNYA cara masuk sekarang adalah "Masuk dengan Google"
/// (lihat AuthProvider.signInWithGoogle).
///
/// <-- BERUBAH (migrasi auth: Anonymous -> Google Sign-In): dulu ada
/// form Username + Kata Sandi (dicek lewat AuthProvider.login ke
/// Firestore `accounts`). SESUAI flow migrasi (Splash -> cek
/// currentUser -> "Masuk dengan Google" -> ...), form itu diganti SATU
/// tombol Google -- desain header (logo app + logo sekolah, teks
/// pembuka) SENGAJA dipertahankan APA ADANYA (bukan redesign), cuma
/// bagian form-nya yang diganti.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Future<void> _submitGoogle() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithGoogle();
    if (!mounted) return;
    if (success) {
      context.read<RecordsProvider>().updateScope(auth.scope);
      context.read<ParentNotesProvider>().updateScope(auth.scope);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } else if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const AppIconMark(size: 68, borderRadius: 18),
                            const SizedBox(width: 14),
                            Container(height: 40, width: 1, color: cs.outlineVariant),
                            const SizedBox(width: 14),
                            const SmpitLogoBadge(size: 64, borderRadius: 14),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Masuk ke Quran Report',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Khusus Guru Pembimbing & Admin yang terdaftar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                      ),
                      const SizedBox(height: 36),
                      // <-- BERUBAH: warna tombol disamain sama gradient
                      // WelcomeHeroCard di Beranda (lihat misc_widgets.dart)
                      // -- SENGAJA pakai warna fixed yang sama persis (bukan
                      // dari Theme/ColorScheme), soalnya hero itu sendiri
                      // juga fixed dark-green baik di light maupun dark mode
                      // -- jadi tombol ini ikut konsisten otomatis di kedua
                      // mode tanpa perlu dibedain per-theme.
                      SizedBox(
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: auth.isLoggingIn
                                  ? const [Color(0xFF0B3B2E), Color(0xFF0E5C46)]
                                      .map((c) => c.withValues(alpha: 0.5))
                                      .toList()
                                  : const [Color(0xFF0B3B2E), Color(0xFF0E5C46)],
                            ),
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: auth.isLoggingIn ? null : _submitGoogle,
                              child: Center(
                                child: auth.isLoggingIn
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(Colors.white),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 22,
                                            height: 22,
                                            alignment: Alignment.center,
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Text(
                                              'G',
                                              style: TextStyle(
                                                color: Color(0xFF0E5C46),
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'Masuk dengan Google',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
