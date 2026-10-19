import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../widgets/common/section_label.dart';

/// Nampilin kode Dart hasil generate (kSeedAccountsJson + kSeedStudentsJson)
/// buat di-copy manual sama developer ke local_seed_data.dart. Cuma
/// preview + copy -- gak ada tombol "simpan otomatis ke project" karena
/// app yang jalan di HP emang gak punya akses ke source code-nya sendiri.
class SeedCodeScreen extends StatelessWidget {
  final String code;
  const SeedCodeScreen({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kode Seed (.dart)'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.copy),
            tooltip: 'Salin semua',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kode disalin.')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
            child: const Text(
              'Salin kode di bawah ke local_seed_data.dart (ganti isi kSeedAccountsJson '
              'dan kSeedStudentsJson yang lama), lalu build ulang APK. Ini hanya '
              'cadangan darurat; data yang dipakai sehari-hari tetap dari cloud.',
              style: TextStyle(fontSize: 12.5),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                code,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu section -- salinan kecil dari `KelolaSectionCard` di settings_screen.dart.
class KelolaSectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const KelolaSectionCard({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: SectionLabel(title),
        ),
        // BUG FIX: sama persis kayak KelolaSectionCard di settings_screen.dart
        // -- lihat catatan lengkap di sana. Card ini juga perlu clip
        // biar ripple ListTile di dalamnya gak nembus keluar sudut
        // rounded-nya.
        Card(
          clipBehavior: Clip.antiAlias,
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
