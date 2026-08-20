import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/enums.dart';
import '../../providers/records_provider.dart';

Future<void> showFilterSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const FilterSheet(),
  );
}

class FilterSheet extends StatelessWidget {
  const FilterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).bottomSheetTheme.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text('Filter', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ),
                TextButton(
                  onPressed: () {
                    provider.clearFilters();
                    Navigator.pop(context);
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (provider.distinctKelas.isNotEmpty) ...[
              const _Label('Kelas'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: provider.distinctKelas.map((k) {
                  final selected = provider.filterKelas == k;
                  return ChoiceChip(
                    label: Text(k),
                    selected: selected,
                    onSelected: (_) => provider.setFilterKelas(selected ? null : k),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            if (provider.distinctHalaqoh.isNotEmpty) ...[
              const _Label('Halaqoh'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: provider.distinctHalaqoh.map((h) {
                  final selected = provider.filterHalaqoh == h;
                  return ChoiceChip(
                    label: Text(h),
                    selected: selected,
                    onSelected: (_) => provider.setFilterHalaqoh(selected ? null : h),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            const _Label('Status'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: HafalanStatus.values.map((s) {
                final selected = provider.filterStatus == s;
                return ChoiceChip(
                  label: Text(s.label),
                  selected: selected,
                  onSelected: (_) => provider.setFilterStatus(selected ? null : s),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const _Label('Keterangan'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Keterangan.values.map((k) {
                final selected = provider.filterKeterangan == k;
                return ChoiceChip(
                  label: Text(k.shortLabel),
                  selected: selected,
                  onSelected: (_) => provider.setFilterKeterangan(selected ? null : k),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Terapkan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
