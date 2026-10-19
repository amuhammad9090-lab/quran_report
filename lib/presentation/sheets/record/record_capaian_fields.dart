import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../../../data/services/quran_engine_service.dart';
import '../../widgets/common/status_icons.dart';
import '../../widgets/record/segment_states.dart';
import '../../widgets/record/tahfizh_fields.dart';
import '../../widgets/record/tahsin_fields.dart';
import '../../widgets/record/tilawah_fields.dart';

/// Bagian "Status Capaian" pada form laporan: memilih widget isian (Tahfizh / Tahsin /
/// Tahsin+Tahfizh / Muroja'ah-Tasmi') menurut [status]. Tanpa state sendiri — state dan seluruh
/// logic tetap di [RecordFormSheet]; widget ini hanya menerima nilai + callback.
class RecordCapaianFields extends StatelessWidget {
  final HafalanStatus status;
  final List<TahfizhSegState> tahfizhSegs;
  final List<TilawahSegState> tilawahSegs;
  final TahsinMode tahsinMode;
  final WafaLevel? wafaLevel;
  final TextEditingController halamanWafaCtrl;
  final bool generating;
  final String? generateError;
  final bool Function() requireInput;

  final VoidCallback onAddTahfizhSegment;
  final void Function(int index) onRemoveTahfizhSegment;
  final void Function(TahfizhSegState seg, int? surah) onTahfizhSurahChanged;
  final void Function(TahfizhSegState seg) onTahfizhAyatChanged;
  final VoidCallback onGenerate;

  final VoidCallback onAddTilawahSegment;
  final void Function(int index) onRemoveTilawahSegment;
  final void Function(TilawahSegState seg, int? surah) onTilawahSurahChanged;

  final ValueChanged<TahsinMode> onTahsinModeChanged;
  final ValueChanged<WafaLevel?> onWafaLevelChanged;

  /// Dipanggil tiap ada ketikan (jumlah baris manual, halaman Wafa, ayat Tilawah) — penjadwal draf.
  final VoidCallback onChanged;

  const RecordCapaianFields({
    super.key,
    required this.status,
    required this.tahfizhSegs,
    required this.tilawahSegs,
    required this.tahsinMode,
    required this.wafaLevel,
    required this.halamanWafaCtrl,
    required this.generating,
    required this.generateError,
    required this.requireInput,
    required this.onAddTahfizhSegment,
    required this.onRemoveTahfizhSegment,
    required this.onTahfizhSurahChanged,
    required this.onTahfizhAyatChanged,
    required this.onGenerate,
    required this.onAddTilawahSegment,
    required this.onRemoveTilawahSegment,
    required this.onTilawahSurahChanged,
    required this.onTahsinModeChanged,
    required this.onWafaLevelChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: switch (status) {
        HafalanStatus.tahfizh => _tahfizh(),
        HafalanStatus.tahsin => _tahsin(),
        HafalanStatus.tahsinTahfizh => _tahsinTahfizh(context, cs),
        HafalanStatus.murojaahTasmi => _tilawah(key: const ValueKey('murojaah')),
      },
    );
  }

  Widget _tahfizh() => TahfizhFields(
        key: const ValueKey('tahfizh'),
        segs: tahfizhSegs,
        generating: generating,
        generateError: generateError,
        requireInput: requireInput,
        onAddSegment: onAddTahfizhSegment,
        onRemoveSegment: onRemoveTahfizhSegment,
        onSurahChanged: onTahfizhSurahChanged,
        onAyatChanged: onTahfizhAyatChanged,
        onManualBarisChanged: onChanged,
        onGenerate: onGenerate,
        missingText: () => QuranEngineService.instance.missingText(),
      );

  Widget _tilawah({Key? key}) => TilawahFields(
        key: key,
        segs: tilawahSegs,
        requireInput: requireInput,
        onAddSegment: onAddTilawahSegment,
        onRemoveSegment: onRemoveTilawahSegment,
        onSurahChanged: onTilawahSurahChanged,
        onChanged: onChanged,
      );

  Widget _modeToggle() => TahsinModeToggle(mode: tahsinMode, onChanged: onTahsinModeChanged);

  Widget _wafa({Key? key}) => WafaFields(
        key: key,
        level: wafaLevel,
        halamanCtrl: halamanWafaCtrl,
        requireInput: requireInput,
        onLevelChanged: onWafaLevelChanged,
        onHalamanChanged: onChanged,
      );

  Widget _tahsin() {
    return Column(
      key: const ValueKey('tahsin'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _modeToggle(),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: tahsinMode == TahsinMode.wafa
              ? _wafa(key: const ValueKey('wafa'))
              : _tilawah(key: const ValueKey('tilawah_in_tahsin')),
        ),
      ],
    );
  }

  /// Label kecil berwarna buat memisahkan "Bagian Tahsin" / "Bagian Tahfizh" di form gabungan.
  Widget _partLabel(String text, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }

  /// Tahsin+Tahfizh = bagian Tahsin (toggle WAFA/Tilawah) + bagian Tahfizh (surah+ayat+generate
  /// baris) sekaligus dalam satu laporan.
  Widget _tahsinTahfizh(BuildContext context, ColorScheme cs) {
    return Column(
      key: const ValueKey('tahsin_tahfizh'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _partLabel('Bagian Tahsin', AppColors.tahsinOn(context), HafalanStatus.tahsin.icon),
        const SizedBox(height: 10),
        _modeToggle(),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: tahsinMode == TahsinMode.wafa
              ? _wafa(key: const ValueKey('wafa_in_combo'))
              : _tilawah(key: const ValueKey('tilawah_in_combo')),
        ),
        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 16),
        _partLabel('Bagian Tahfizh (Hafalan Baru)', cs.primary, HafalanStatus.tahfizh.icon),
        const SizedBox(height: 10),
        _tahfizh(),
      ],
    );
  }
}
