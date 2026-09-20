import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../common/status_icons.dart';

/// Pemilih Keterangan (Hadir/Izin/Alpa/sanksi, dst) dalam baris-baris berisi 3 chip, plus
/// checkbox "Hadir tanpa capaian" yang hanya tampil saat keterangan = Hadir.
class KeteranganSelector extends StatelessWidget {
  final Keterangan selected;
  final bool tanpaCapaian;
  final ValueChanged<Keterangan> onSelected;
  final ValueChanged<bool> onTanpaCapaianChanged;

  const KeteranganSelector({
    super.key,
    required this.selected,
    required this.tanpaCapaian,
    required this.onSelected,
    required this.onTanpaCapaianChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget chip(Keterangan k) {
      final isSelected = selected == k;
      final color = AppColors.keteranganColorOn(context, k.name);
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSelected(k),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.14)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isSelected ? color : Colors.transparent, width: 1.3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(k.icon,
                    size: 17, color: isSelected ? color : cs.onSurfaceVariant),
                const SizedBox(height: 4),
                Text(
                  k.shortLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? color : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    const values = Keterangan.values;

    Widget spacedRow(List<Keterangan> row) => Row(
          children: [
            for (int i = 0; i < row.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              chip(row[i]),
            ],
          ],
        );

    // Di-chunk otomatis per 3 supaya penambahan Keterangan ke depan tidak perlu ubah kode ini
    // (baris terakhir yang tidak genap tetap dirender).
    final rows = <List<Keterangan>>[];
    for (var i = 0; i < values.length; i += 3) {
      rows.add(values.sublist(i, i + 3 > values.length ? values.length : i + 3));
    }

    return Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          spacedRow(rows[i]),
        ],
        // Toggle hanya relevan untuk "Hadir"; keterangan lain otomatis capaian opsional & dikosongkan.
        if (selected == Keterangan.hadir) ...[
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onTanpaCapaianChanged(!tanpaCapaian),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: tanpaCapaian
                    ? cs.primary.withValues(alpha: 0.10)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: tanpaCapaian ? cs.primary : Colors.transparent,
                  width: 1.3,
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: tanpaCapaian,
                    onChanged: (v) => onTanpaCapaianChanged(v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      'Hadir tanpa capaian hari ini (mis. ada arahan/kegiatan lain) — '
                      'capaian boleh dikosongkan, tapi catatan wajib diisi.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tanpaCapaian ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
