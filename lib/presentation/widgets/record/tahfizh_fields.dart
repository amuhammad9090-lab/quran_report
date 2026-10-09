import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/services/quran_engine_service.dart';
import '../forms/field_decoration.dart';
import 'generated_lines_panel.dart';
import 'segment_states.dart';

/// Blok input Tahfizh: satu atau lebih segmen surah+ayat, tombol generate baris, pesan error,
/// dan total baris. Tanpa state sendiri — semua perubahan dilaporkan lewat callback ke form.
class TahfizhFields extends StatelessWidget {
  final List<TahfizhSegState> segs;
  final bool generating;
  final String? generateError;

  /// Dibaca saat validasi: true kalau kolom capaian wajib diisi.
  final bool Function() requireInput;
  final VoidCallback onAddSegment;
  final ValueChanged<int> onRemoveSegment;
  final void Function(TahfizhSegState seg, int? surah) onSurahChanged;
  final ValueChanged<TahfizhSegState> onAyatChanged;
  final VoidCallback onManualBarisChanged;
  final VoidCallback onGenerate;
  final String Function() missingText;

  const TahfizhFields({
    super.key,
    required this.segs,
    required this.generating,
    required this.generateError,
    required this.requireInput,
    required this.onAddSegment,
    required this.onRemoveSegment,
    required this.onSurahChanged,
    required this.onAyatChanged,
    required this.onManualBarisChanged,
    required this.onGenerate,
    required this.missingText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalBarisAll = segs.fold<int>(0, (a, s) {
      if (s.generated != null && !s.generated!.available) {
        return a + (int.tryParse(s.manualBarisCtrl.text.trim()) ?? 0);
      }
      return a + (s.generated?.totalBaris ?? 0);
    });
    final anyGenerated = segs.any((s) =>
        (s.generated != null && s.generated!.available) ||
        (s.generated != null &&
            !s.generated!.available &&
            (int.tryParse(s.manualBarisCtrl.text.trim()) ?? 0) > 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < segs.length; i++) ...[
          _TahfizhSegmentField(
            seg: segs[i],
            index: i,
            requireInput: requireInput,
            onRemove: () => onRemoveSegment(i),
            onSurahChanged: (v) => onSurahChanged(segs[i], v),
            onAyatChanged: () => onAyatChanged(segs[i]),
            onManualBarisChanged: onManualBarisChanged,
            missingText: missingText,
          ),
          if (i != segs.length - 1) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
          ],
        ],
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onAddSegment,
            icon: const Icon(LucideIcons.circlePlus, size: 18),
            label: const Text('Tambah Surah Lanjutan'),
            style: TextButton.styleFrom(
              foregroundColor: cs.primary,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800),
            ),
            onPressed: generating ? null : onGenerate,
            icon: generating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(LucideIcons.wand, size: 19),
            label: Text(generating
                ? 'Menghitung...'
                : (segs.length > 1 ? 'Generate Semua Baris' : 'Generate Baris')),
          ),
        ),
        if (generateError != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.info, size: 18, color: cs.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(generateError!,
                      style: TextStyle(fontSize: 12.5, color: cs.error)),
                ),
              ],
            ),
          ),
        ],
        if (segs.length > 1 && anyGenerated) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.calculator, size: 17, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Total ${segs.length} surah',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700, color: cs.primary)),
                ),
                Text('$totalBarisAll baris baru',
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w800, color: cs.primary)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 1 blok surah+ayat Tahfizh (dipakai berulang untuk tiap segmen);
/// segmen ke-2 dst punya label "Surah ke-N" + tombol hapus.
class _TahfizhSegmentField extends StatelessWidget {
  final TahfizhSegState seg;
  final int index;
  final bool Function() requireInput;
  final VoidCallback onRemove;
  final ValueChanged<int?> onSurahChanged;
  final VoidCallback onAyatChanged;
  final VoidCallback onManualBarisChanged;
  final String Function() missingText;

  const _TahfizhSegmentField({
    required this.seg,
    required this.index,
    required this.requireInput,
    required this.onRemove,
    required this.onSurahChanged,
    required this.onAyatChanged,
    required this.onManualBarisChanged,
    required this.missingText,
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
            accent: cs.primary,
          ),
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14.5, color: cs.onSurface),
          items: kSurahNames.entries
              .map((e) => DropdownMenuItem(
                  value: e.key, child: Text('${e.key}. ${e.value}')))
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
                  accent: cs.primary,
                ),
                onChanged: (_) => onAyatChanged(),
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
                  accent: cs.primary,
                ),
                onChanged: (_) => onAyatChanged(),
                validator: (v) => !requireInput()
                    ? null
                    : ((v == null || v.trim().isEmpty) ? 'Wajib' : null),
              ),
            ),
          ],
        ),
        if (seg.generated != null && seg.generated!.available) ...[
          const SizedBox(height: 14),
          GeneratedLinesPanel(result: seg.generated!),
        ],
        if (seg.generated != null && !seg.generated!.available) ...[
          const SizedBox(height: 14),
          _ManualBarisFallback(
            seg: seg,
            missingText: missingText,
            onChanged: onManualBarisChanged,
          ),
        ],
      ],
    );
  }
}

/// Panel fallback saat surah ada di juz yang datasetnya belum tersedia (Juz 11-25): generate
/// otomatis tidak bisa jalan, jadi user mengisi sendiri jumlah baris hafalannya.
class _ManualBarisFallback extends StatelessWidget {
  final TahfizhSegState seg;
  final String Function() missingText;
  final VoidCallback onChanged;

  const _ManualBarisFallback({
    required this.seg,
    required this.missingText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.info, size: 16, color: cs.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Data baris belum tersedia untuk surah ini '
                  '(${missingText()}). '
                  'Isi jumlah baris manual.',
                  style: TextStyle(fontSize: 12, color: cs.onErrorContainer),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: seg.manualBarisCtrl,
            keyboardType: TextInputType.number,
            decoration: fieldDecoration(
              context,
              icon: LucideIcons.list,
              label: 'Jumlah Baris (manual)',
              accent: cs.error,
            ),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}
