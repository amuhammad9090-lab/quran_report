import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/week_utils.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/parent_notes_provider.dart'; // <-- BARU
import '../../../providers/records_provider.dart';
import '../../../providers/students_provider.dart';
import '../../widgets/avatar_image_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../auth/login_screen.dart';
import '../settings/settings_screen.dart';
import 'edit_profile_screen.dart';

/// Profile — identitas user yang login + statistik ringkas SCOPED ke
/// assignment-nya (bukan angka global), sesuai spesifikasi bagian L/N.
/// Statistik personal SENGAJA tidak ditaruh di Home — cuma di sini.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar akun?'),
        content: const Text('Anda perlu login lagi untuk mengakses laporan.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    // Bersihkan scope DULU baru logout, biar nggak ada frame di mana
    // RecordsProvider masih megang scope dari user yang sudah keluar.
    context.read<RecordsProvider>().updateScope(null);
    // <-- BARU: sama alasannya — badge notifikasi Catatan Orang Tua
    // jangan sempat kelihatan bawa data guru sebelumnya di layar Login.
    context.read<ParentNotesProvider>().updateScope(null);
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openEditProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final records = context.watch<RecordsProvider>();
    final studentsProvider = context.watch<StudentsProvider>();
    final user = auth.currentUser;

    if (user == null) {
      // Seharusnya nggak kejadian (Profile cuma reachable pas sudah
      // login), tapi dijaga biar nggak crash kalau ke-pop aneh.
      return const Scaffold(body: SizedBox.shrink());
    }

    final accessibleStudents = studentsProvider.accessibleFor(auth.scope);
    // Kalau data master santri untuk assignment ini kosong (belum
    // diimpor), fallback ke jumlah santri unik dari riwayat laporan biar
    // angkanya tetap masuk akal, bukan 0 yang menyesatkan.
    final santriDiampu =
        accessibleStudents.isNotEmpty ? accessibleStudents.length : records.totalSantri;
    final pekanLabel = WeekUtils.weekLabel(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const PushedPageHeader(title: 'Profil'),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              sliver: SliverList.list(
                children: [
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => _openEditProfile(context),
                          child: CircleAvatar(
                            radius: 44,
                            backgroundColor: cs.primaryContainer,
                            backgroundImage: resolveAvatarImage(user.photoPath),
                            child: user.photoPath == null
                                ? Text(
                                    user.displayName.isNotEmpty
                                        ? user.displayName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: cs.onPrimaryContainer,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          user.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
                        ),
                        const SizedBox(height: 2),
                        Text('@${user.username}',
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            user.role.label,
                            style: TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.w700, color: cs.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoRow(
                            icon: Icons.school_rounded,
                            label: auth.currentSchool?.name ?? '-',
                            sub: auth.currentSchool?.city,
                          ),
                          if (!user.isAdmin) ...[
                            if (user.assignments.isEmpty)
                              const Column(
                                children: [
                                  Divider(height: 22),
                                  _InfoRow(
                                    icon: Icons.groups_outlined,
                                    label: '-',
                                    sub: null,
                                  ),
                                ],
                              )
                            else
                              for (final a in user.assignments) ...[
                                const Divider(height: 22),
                                _InfoRow(
                                  icon: Icons.groups_outlined,
                                  label: 'Kelas ${a.kelas} • ${a.halaqoh}',
                                  sub: null,
                                ),
                              ],
                          ] else ...[
                            const Divider(height: 22),
                            const _InfoRow(
                              icon: Icons.public_rounded,
                              label: 'Akses semua kelas & halaqoh',
                              sub: null,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SectionLabel(user.isAdmin ? 'Ringkasan Global' : 'Ringkasan Assignment Saya'),
                  Row(
                    children: [
                      Expanded(
                        child: StatPill(
                          label: 'Santri Diampu',
                          value: '$santriDiampu',
                          icon: Icons.groups_2_rounded,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatPill(
                          label: 'Laporan Hari Ini',
                          value: '${records.laporanBaruHariIni}',
                          icon: Icons.post_add_rounded,
                          color: AppColors.purpleOn(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: StatPill(
                          label: pekanLabel,
                          value: 'Aktif',
                          icon: Icons.calendar_view_week_rounded,
                          color: AppColors.blueOn(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatPill(
                          label: 'Baris Setoran',
                          value: '${records.totalBarisSetoran}',
                          icon: Icons.format_list_numbered_rounded,
                          color: AppColors.tahsinOn(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _ProfileActionTile(
                    icon: Icons.edit_outlined,
                    label: 'Edit Profil',
                    onTap: () => _openEditProfile(context),
                  ),
                  _ProfileActionTile(
                    icon: Icons.settings_outlined,
                    label: 'Pengaturan',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                  _ProfileActionTile(
                    icon: Icons.logout_rounded,
                    label: 'Keluar',
                    destructive: true,
                    onTap: () => _logout(context),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  const _InfoRow({required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        SoftIconBox(icon: icon, color: cs.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              if (sub != null)
                Text(sub!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  const _ProfileActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = destructive ? cs.error : cs.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 19, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: color)),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
