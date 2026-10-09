import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/services/quran_engine_service.dart';
import '../forms/field_decoration.dart';
import 'segment_states.dart';

/// Blok surah + rentang ayat TANPA generate/hitung baris — dipakai Tahsin bermode Tilawah,
/// bagian Tahsin di Tahsin+Tahfizh (mode Tilawah), dan Muroja'ah/Tasmi'. Bisa >1 segmen
/// (tombol "+") kalau setoran nyambung lintas surah.
class TilawahFields extends StatelessWidget {
  final List<TilawahSegState> segs;

  /// Dibaca saat validasi: true kalau kolom capaian wajib diisi.
  final bool Function() requireInput;
  final VoidCallback onAddSegment;
  final ValueChanged<int> onRemoveSegment;
  final void Function(TilawahSegState seg, int? surah) onSurahChanged;
  final VoidCallback onChanged;

  const TilawahFields({
    super.key,
    required this.segs,
    required this.requireInput,
    required this.onAddSegment,
    required this.onRemoveSegment,
    required this.onSurahChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.tahsinOn(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < segs.length; i++) ...[
          _TilawahSegmentField(
            seg: segs[i],
            index: i,
            accent: accent,
            requireInput: requireInput,
            onRemove: () => onRemoveSegment(i),
            onSurahChanged: (v) => onSurahChanged(segs[i], v),
            onChanged: onChanged,
          ),
          if (i != segs.length - 1) const SizedBox(height: 14),
        ],
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onAddSegment,
            icon: const Icon(LucideIcons.circlePlus, size: 18),
            label: const Text('Tambah Surah Lanjutan'),
            style: TextButton.styleFrom(
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ),
        ),
      ],
    );
  }
}

/// 1 blok surah+ayat Tilawah (dipakai berulang untuk tiap segmen).
class _TilawahSegmentField extends StatelessWidget {
  final TilawahSegState seg;
  final int index;
  final Color accent;
  final bool Function() requireInput;
  final VoidCallback onRemove;
  final ValueChanged<int?> onSurahChanged;
  final VoidCallback onChanged;

  const _TilawahSegmentField({
    required this.seg,
    required this.index,
    required this.accent,
    required this.requireInput,
    required this.onRemove,
    required this.onSurahChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (index > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Surah ke-${index + 1} (lanjutan)',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onRemove,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(LucideIcons.circleX, size: 18, color: cs.error),
                  ),
                ),
              ],
            ),
          ),
        DropdownButtonFormField<int>(
          initialValue: seg.surahNumber,
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          icon: Icon(LucideIcons.chevronDown, color: cs.onSurfaceVariant),
          decoration: fieldDecoration(
            context,
            icon: LucideIcons.bookOpen,
            label: 'Surah',
            accent: accent,
          ),
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: cs.onSurface),
          items: kSurahNames.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text('${e.key}. ${e.value}')))
              .toList(),
          onChanged: onSurahChanged,
          validator: (v) =>
              !requireInput() ? null : (v == null ? 'Pilih surah' : null),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: seg.ayatMulaiCtrl,
                keyboardType: TextInputType.number,
                decoration: fieldDecoration(
                  context,
                  icon: LucideIcons.chevronsLeft,
                  label: 'Dari Ayat',
                  accent: accent,
                ),
                onChanged: (_) => onChanged(),
                validator: (v) => !requireInput()
                    ? null
                    : ((v == null || v.trim().isEmpty) ? 'Wajib' : null),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: seg.ayatSelesaiCtrl,
                keyboardType: TextInputType.number,
                decoration: fieldDecoration(
                  context,
                  icon: LucideIcons.chevronsRight,
                  label: 'Sampai Ayat',
                  accent: accent,
                ),
                onChanged: (_) => onChanged(),
                validator: (v) => !requireInput()
                    ? null
                    : ((v == null || v.trim().isEmpty) ? 'Wajib' : null),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
