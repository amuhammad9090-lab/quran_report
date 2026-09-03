import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/parent_notes_provider.dart'; // <-- BARU
import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../home/main_shell.dart';

/// Login — logic-nya yang jadi fokus (bukan visual, karena layar ini
/// belum ada sebelumnya jadi belum ada yang dianggap "FIX" untuk
/// dipertahankan; kalau nanti ada desain resmi, tinggal ganti body-nya,
/// pemanggilan AuthProvider.login() di bawah ini tetap sama).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    if (success) {
      // Access scope baru terbentuk setelah login sukses — terapkan ke
      // RecordsProvider supaya seluruh data (Home/Laporan/Statistik/
      // Export) langsung ke-scope tanpa perlu restart app.
      context.read<RecordsProvider>().updateScope(auth.scope);
      // <-- BARU: sama halnya, notifikasi Catatan Orang Tua juga perlu
      // di-scope ulang begitu ada user baru login (mis. HP dipakai
      // bergantian oleh beberapa guru) — kalau tidak, badge/list bisa
      // ketinggalan scope guru SEBELUMnya sampai app di-restart manual.
      context.read<ParentNotesProvider>().updateScope(auth.scope);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Login gagal.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
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
                    'Khusus guru pembimbing & admin yang terdaftar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _usernameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: fieldDecoration(
                      context,
                      icon: Icons.person_outline_rounded,
                      label: 'Username',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: fieldDecoration(
                      context,
                      icon: Icons.lock_outline_rounded,
                      label: 'Kata Sandi',
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: auth.isLoggingIn ? null : _submit,
                    child: auth.isLoggingIn
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Masuk'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
