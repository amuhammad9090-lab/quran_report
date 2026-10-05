import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../home/category_tile.dart';

/// Dua tombol Tuntas / Tidak Tuntas. Opsional: tap tombol yang sedang
/// aktif sekali lagi untuk membatalkan pilihan (kembali ke belum ditandai).
class TuntasSelector extends StatelessWidget {
  final bool? selected;
  final ValueChanged<bool?> onChanged;

  const TuntasSelector({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CategoryTile(
            label: 'Tuntas',
            icon: LucideIcons.circleCheck,
            color: AppColors.greenOn(context),
            active: selected == true,
            onTap: () => onChanged(selected == true ? null : true),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CategoryTile(
            label: 'Tidak Tuntas',
            icon: LucideIcons.circleX,
            color: AppColors.redOn(context),
            active: selected == false,
            onTap: () => onChanged(selected == false ? null : false),
          ),
        ),
      ],
    );
  }
}
