import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../common/status_icons.dart';
import '../home/category_tile.dart';

/// Pemilih status capaian (Tahfizh / Tahsin / Tahsin+Tahfizh / Muroja'ah-Tasmi') dalam grid 2x2,
/// supaya label panjang ("Tahsin+Tahfizh", "Muroja'ah/Tasmi'") tetap muat.
class RecordStatusSelector extends StatelessWidget {
  final HafalanStatus selected;
  final ValueChanged<HafalanStatus> onChanged;

  const RecordStatusSelector({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget tile(HafalanStatus s) {
      return Expanded(
        child: CategoryTile(
          label: s.label,
          icon: s.icon,
          color: AppColors.statusOn(context, s),
          active: selected == s,
          onTap: () => onChanged(s),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            tile(HafalanStatus.tahfizh),
            const SizedBox(width: 10),
            tile(HafalanStatus.tahsin),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            tile(HafalanStatus.tahsinTahfizh),
            const SizedBox(width: 10),
            tile(HafalanStatus.murojaahTasmi),
          ],
        ),
      ],
    );
  }
}
