import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart'; // <-- BARU
import '../../../providers/records_provider.dart';
import '../../../providers/folders_provider.dart'; // <-- BARU
import '../../../data/services/storage_service.dart';
import '../../../data/services/app_prefs_service.dart'; // <-- BARU
import '../../../data/services/firebase_bootstrap_status.dart';
import '../../widgets/misc_widgets.dart';
import '../about/about_screen.dart';
import 'kelola_data_screen.dart';
import 'package:solar_icons/solar_icons.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 3,
            shadowColor: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.10),
            toolbarHeight: 84,
            titleSpacing: 20,
            title: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pengaturan',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Atur aplikasi dan kelola data',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            sliver: SliverList.list(
              children: [
                _SectionCard(
                  title: 'Tampilan',
                  children: [
                    _ThemeOption(
                      icon: SolarIconsBold.sun,
                      label: 'Terang',
                      selected: themeProvider.mode == ThemeMode.light,
                      onTap: () => themeProvider.setMode(ThemeMode.light),
                    ),
                    _ThemeOption(
                      icon: SolarIconsBold.moon,
                      label: 'Gelap',
                      selected: themeProvider.mode == ThemeMode.dark,
                      onTap: () => themeProvider.setMode(ThemeMode.dark),
                    ),
                    _ThemeOption(
                      icon: SolarIconsBold.iPhone,
                      label: 'Ikuti Sistem',
                      selected: themeProvider.mode == ThemeMode.system,
                      onTap: () => themeProvider.setMode(ThemeMode.system),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Data',
                  children: [
                    ListTile(
                      leading: SoftIconBox(
                        icon: SolarIconsBold.cloudUpload,
                        color: cs.primary,
                      ),
                      title: const Text('Backup ke Cloud'),
                      subtitle: const Text('Kirim ulang semua laporan ke Portal Orang Tua'),
                      onTap: () => _confirmSyncToCloud(context),
                    ),
                    ListTile(
                      leading: SoftIconBox(
                        icon: SolarIconsBold.cloudDownload,
                        color: cs.primary,
                      ),
                      title: const Text('Pulihkan dari Cloud'),
                      subtitle: const Text('Tarik kembali laporan yang pernah di-backup'),
                      onTap: () => _confirmRestoreFromCloud(context),
                    ),
                    ListTile(
                      leading: SoftIconBox(
                        icon: SolarIconsBold.trashBinMinimalistic_2,
                        color: cs.error,
                      ),
                      title: const Text('Hapus Semua Data'),
                      subtitle: const Text('Menghapus seluruh laporan tersimpan'),
                      onTap: () => _confirmClearAll(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (context.watch<AuthProvider>().scope?.isAdmin ?? false) ...[
                  _SectionCard(
                    title: 'Kelola Sekolah (Admin)',
                    children: [
                      ListTile(
                        leading: SoftIconBox(icon: SolarIconsBold.userId, color: cs.primary),
                        title: const Text('Halaman Kelola'),
                        subtitle: const Text('Kelola guru & murid, export/import Excel, migrasi data'),
                        trailing: const Icon(SolarIconsBold.altArrowRight),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const KelolaDataScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                _SectionCard(
                  title: 'Lainnya',
                  children: [
                    ListTile(
                      leading: SoftIconBox(
                        icon: SolarIconsBold.infoCircle,
                        color: cs.primary,
                      ),
                      title: const Text('Tentang Aplikasi'),
                      trailing: const Icon(SolarIconsBold.altArrowRight),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // <-- BARU: Konfirmasi dulu sebelum Backup ke
  // Cloud
  void _confirmSyncToCloud(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup ke Cloud?'),
        content: const Text(
          'Semua laporan yang tersimpan di HP ini akan dikirim ulang ke Portal Orang Tua. '
          'Data lama di cloud dengan laporan yang sama akan ditimpa. Butuh koneksi internet.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _syncToCloud(context);
            },
            child: const Text('Backup'),
          ),
        ],
      ),
    );
  }

  // <-- BARU: seluruh method ini. Handler tombol "Sinkronkan ke Cloud".
  Future<void> _syncToCloud(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
              SizedBox(width: 16),
              Expanded(child: Text('Menyinkronkan laporan...')),
            ],
          ),
        ),
      ),
    );

    try {
      final scope = context.read<AuthProvider>().scope;
      final count = await StorageService.instance.syncAllToFirestore(scope: scope);
      if (!context.mounted) return;
      Navigator.of(context).pop(); // tutup dialog loading
      // <-- BERUBAH: nambahin jumlah santri (bukan cuma jumlah laporan)
      // di pesannya -- guru pembimbing biasanya lebih kebayang lewat
      // "berapa anak" ketimbang "berapa baris laporan". `totalSantri`
      // sudah otomatis ke-scope ke kelas/halaqoh guru ini sendiri (lihat
      // RecordsProvider._scoped), jadi buat guru non-admin ini beneran
      // jumlah anak-anaknya dia doang, bukan seluruh sekolah.
      final totalSantri = context.read<RecordsProvider>().totalSantri;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Berhasil! $count laporan ($totalSantri santri) tersinkron ke cloud.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            FirebaseBootstrapStatus.ready
                ? 'Gagal sinkron: $e. Cek koneksi internet, lalu coba lagi.'
                : FirebaseBootstrapStatus.userMessage,
          ),
        ),
      );
    }
  }

  // <-- BARU: seluruh method ini. Konfirmasi dulu sebelum "Pulihkan dari
  // Cloud" — walau restore-nya sendiri aman (laporan yang diedit lebih
  // baru di lokal tidak akan ketiban versi cloud yang lebih lama.
  void _confirmRestoreFromCloud(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulihkan dari Cloud?'),
        content: const Text(
          'Semua laporan yang pernah ter-backup ke cloud akan ditarik kembali ke HP ini. '
          'Laporan yang sudah ada & lebih baru di HP ini tidak akan ditimpa. Butuh koneksi internet.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _restoreFromCloud(context);
            },
            child: const Text('Pulihkan'),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreFromCloud(BuildContext context) async {
    // <-- BERUBAH: sama seperti _syncToCloud — PopScope(canPop: false)
    // biar tombol back Android gak bisa dismiss dialog ini di tengah
    // proses (lihat catatan lengkap di _syncToCloud).
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
              SizedBox(width: 16),
              Expanded(child: Text('Memulihkan laporan...')),
            ],
          ),
        ),
      ),
    );

    try {
      // <-- BERUBAH: folder dipulihkan DULUAN sebelum laporan.
      final scope = context.read<AuthProvider>().scope;
      await StorageService.instance.restoreFoldersFromFirestore();
      final count =
          await StorageService.instance.restoreFromFirestore(scope: scope);

      await AppPrefsService.instance.restoreActivatedMetaFromFirestore();
      if (!context.mounted) return;
      await context.read<RecordsProvider>().load();
      if (!context.mounted) return;
      await context.read<FoldersProvider>().load();
      if (!context.mounted) return;
      Navigator.of(context).pop();
      // <-- BERUBAH: sama kayak _syncToCloud, ikut nampilin jumlah
      // santri (ter-scope ke guru pembimbing ini) di snackbar-nya.
      final totalSantri = context.read<RecordsProvider>().totalSantri;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Berhasil! $count laporan ($totalSantri santri) dipulihkan dari cloud.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            FirebaseBootstrapStatus.ready
                ? 'Gagal memulihkan: $e. Cek koneksi internet, lalu coba lagi.'
                : FirebaseBootstrapStatus.userMessage,
          ),
        ),
      );
    }
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus semua data?'),
        content: const Text(
            'Seluruh laporan yang tersimpan akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () async {
              await context.read<RecordsProvider>().clearAllData();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
  }

}

/// Kotak ikon bertinta lembut untuk leading icon list tile pengaturan —
/// pakai [SoftIconBox] bersama dari misc_widgets.dart.

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: SectionLabel(title),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1)
                    Divider(
                      height: 1,
                      indent: 60,
                      endIndent: 16,
                      color: Theme.of(context).dividerTheme.color,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: SoftIconBox(
        icon: icon,
        color: selected ? cs.primary : cs.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 14,
        ),
      ),
      trailing: selected
          ? Icon(SolarIconsBold.checkCircle, color: cs.primary)
          : Icon(Icons.circle_outlined,
          color: cs.onSurfaceVariant.withValues(alpha: 0.35)),
      onTap: onTap,
    );
  }
}