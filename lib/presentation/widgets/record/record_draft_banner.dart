import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Banner "Ada draf laporan yang belum sempat disimpan" di atas form laporan: [onDiscard]
/// membuang draf, [onRestore] melanjutkan isiannya.
class RecordDraftBanner extends StatelessWidget {
  final VoidCallback onDiscard;
  final VoidCallback onRestore;

  const RecordDraftBanner({super.key, required this.onDiscard, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.history, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ada draf laporan yang belum sempat disimpan.',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Kelihatannya form sebelumnya sempat tertutup sebelum disimpan. Lanjutkan isian tadi?',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDiscard,
                  child: const Text('Buang'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onRestore,
                  child: const Text('Lanjutkan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
