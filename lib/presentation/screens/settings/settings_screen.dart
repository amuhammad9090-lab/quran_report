import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/theme_provider.dart';
import '../../../providers/records_provider.dart';
import '../about/about_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _SectionCard(
            title: 'Tampilan',
            children: [
              _ThemeOption(
                icon: Icons.light_mode_rounded,
                label: 'Terang',
                selected: themeProvider.mode == ThemeMode.light,
                onTap: () => themeProvider.setMode(ThemeMode.light),
              ),
              _ThemeOption(
                icon: Icons.dark_mode_rounded,
                label: 'Gelap',
                selected: themeProvider.mode == ThemeMode.dark,
                onTap: () => themeProvider.setMode(ThemeMode.dark),
              ),
              _ThemeOption(
                icon: Icons.smartphone_rounded,
                label: 'Ikuti Sistem',
                selected: themeProvider.mode == ThemeMode.system,
                onTap: () => themeProvider.setMode(ThemeMode.system),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Data',
            children: [
              ListTile(
                leading: Icon(Icons.delete_sweep_outlined, color: cs.error),
                title: const Text('Hapus Semua Data'),
                subtitle: const Text('Menghapus seluruh laporan tersimpan'),
                onTap: () => _confirmClearAll(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Lainnya',
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Tentang Aplikasi'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus semua data?'),
        content: const Text('Seluruh laporan yang tersimpan akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.'),
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
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: children),
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
      leading: Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
      title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      trailing: selected ? Icon(Icons.check_circle_rounded, color: cs.primary) : null,
      onTap: onTap,
    );
  }
}
