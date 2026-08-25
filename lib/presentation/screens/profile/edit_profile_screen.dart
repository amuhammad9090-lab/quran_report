import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../data/services/profile_photo_service.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/misc_widgets.dart';

/// Edit Profil — lebih dari sekadar ganti nama: ada juga ganti foto
/// avatar (kamera/galeri) dan ganti kata sandi. Sebelumnya cuma dialog
/// kecil edit nama; sekarang jadi screen sendiri biar muat semuanya
/// tanpa sesak.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  bool _savingPhoto = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _nameCtrl = TextEditingController(text: user?.displayName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _savingPhoto = true);
    try {
      final path = await ProfilePhotoService.instance.pickAndSave(
        userId: user.id,
        source: source,
      );
      if (path != null) {
        auth.updatePhotoPath(path);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengambil foto, coba lagi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  Future<void> _removePhoto() async {
    final auth = context.read<AuthProvider>();
    final oldPath = auth.currentUser?.photoPath;
    auth.updatePhotoPath(null);
    await ProfilePhotoService.instance.delete(oldPath);
  }

  void _showPhotoOptions() {
    final hasPhoto = context.read<AuthProvider>().currentUser?.photoPath != null;
    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil dari Kamera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: Theme.of(ctx).colorScheme.error),
                title: Text('Hapus Foto', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _removePhoto();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _saveName() {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama tampilan tidak boleh kosong.')),
      );
      return;
    }
    context.read<AuthProvider>().updateDisplayName(newName);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil berhasil disimpan.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = context.watch<AuthProvider>().currentUser;

    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const PushedPageHeader(title: 'Edit Profil'),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              sliver: SliverList.list(
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _savingPhoto ? null : _showPhotoOptions,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: cs.primaryContainer,
                            backgroundImage:
                                user.photoPath != null ? FileImage(File(user.photoPath!)) : null,
                            child: _savingPhoto
                                ? const CircularProgressIndicator(strokeWidth: 2.4)
                                : (user.photoPath == null
                                    ? Text(
                                        user.displayName.isNotEmpty
                                            ? user.displayName[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontSize: 34,
                                          fontWeight: FontWeight.w800,
                                          color: cs.onPrimaryContainer,
                                        ),
                                      )
                                    : null),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: cs.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  width: 2.5,
                                ),
                              ),
                              child: Icon(Icons.camera_alt_rounded, size: 15, color: cs.onPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Ketuk foto untuk mengganti',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FormSectionCard(
                    title: 'Informasi Profil',
                    icon: Icons.badge_outlined,
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama Tampilan',
                        hintText: 'Masukkan nama tampilan',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saveName,
                      child: const Text('Simpan Perubahan'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SectionLabel('Keamanan'),
                  const SizedBox(height: 10),
                  Material(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => showChangePasswordDialog(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        child: Row(
                          children: [
                            SoftIconBox(icon: Icons.lock_outline_rounded, color: cs.primary),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Ganti Kata Sandi',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog ganti kata sandi: minta kata sandi lama + baru + konfirmasi,
/// verifikasi lewat [AuthProvider.changePassword]. Dipisah jadi fungsi
/// top-level (bukan method di State) supaya bisa juga dipanggil dari
/// tempat lain kalau nanti dibutuhkan (mis. dari Settings).
Future<void> showChangePasswordDialog(BuildContext context) {
  final oldCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  return showDialog(
    context: context,
    builder: (ctx) => _ChangePasswordDialog(
      oldCtrl: oldCtrl,
      newCtrl: newCtrl,
      confirmCtrl: confirmCtrl,
    ),
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  final TextEditingController oldCtrl;
  final TextEditingController newCtrl;
  final TextEditingController confirmCtrl;

  const _ChangePasswordDialog({
    required this.oldCtrl,
    required this.newCtrl,
    required this.confirmCtrl,
  });

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    final oldPass = widget.oldCtrl.text;
    final newPass = widget.newCtrl.text;
    final confirmPass = widget.confirmCtrl.text;

    if (newPass != confirmPass) {
      setState(() => _error = 'Konfirmasi kata sandi baru tidak cocok.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await context.read<AuthProvider>().changePassword(
          oldPassword: oldPass,
          newPassword: newPass,
        );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _submitting = false;
        _error = result;
      });
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kata sandi berhasil diubah.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ganti Kata Sandi'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PasswordField(
              controller: widget.oldCtrl,
              label: 'Kata Sandi Lama',
              obscure: _obscureOld,
              onToggleObscure: () => setState(() => _obscureOld = !_obscureOld),
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: widget.newCtrl,
              label: 'Kata Sandi Baru',
              obscure: _obscureNew,
              onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: widget.confirmCtrl,
              label: 'Konfirmasi Kata Sandi Baru',
              obscure: _obscureConfirm,
              onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12.5),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggleObscure;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggleObscure,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
          onPressed: onToggleObscure,
        ),
      ),
    );
  }
}
