import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../forms/field_decoration.dart';

/// Toggle kecil WAFA / Tilawah — dipakai di status Tahsin & bagian Tahsin di Tahsin+Tahfizh.
class TahsinModeToggle extends StatelessWidget {
  final TahsinMode mode;
  final ValueChanged<TahsinMode> onChanged;

  const TahsinModeToggle({super.key, required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget seg(TahsinMode m) {
      final selected = mode == m;
      final color = AppColors.tahsinOn(context);
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onChanged(m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? color : cs.outlineVariant, width: 1.2),
            ),
            child: Text(
              m.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? color : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        seg(TahsinMode.wafa),
        const SizedBox(width: 10),
        seg(TahsinMode.tilawah),
      ],
    );
  }
}

/// Blok WAFA (jenjang + halaman) — dipakai ulang persis sama di status Tahsin dan di dalam
/// Tahsin+Tahfizh.
class WafaFields extends StatelessWidget {
  final WafaLevel? level;
  final TextEditingController halamanCtrl;

  /// Dibaca saat validasi: true kalau kolom capaian wajib diisi.
  final bool Function() requireInput;
  final ValueChanged<WafaLevel?> onLevelChanged;
  final VoidCallback onHalamanChanged;

  const WafaFields({
    super.key,
    required this.level,
    required this.halamanCtrl,
    required this.requireInput,
    required this.onLevelChanged,
    required this.onHalamanChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<WafaLevel>(
          initialValue: level,
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          icon: Icon(LucideIcons.chevronDown, color: cs.onSurfaceVariant),
          decoration: fieldDecoration(
            context,
            icon: LucideIcons.bookOpen,
            label: 'Jenjang WAFA',
            accent: AppColors.tahsinOn(context),
          ),
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14.5, color: cs.onSurface),
          items: WafaLevel.values
              .map((w) => DropdownMenuItem(value: w, child: Text(w.label)))
              .toList(),
          onChanged: onLevelChanged,
          validator: (v) => !requireInput()
              ? null
              : (v == null ? 'Pilih jenjang WAFA' : null),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: halamanCtrl,
          decoration: fieldDecoration(
            context,
            icon: LucideIcons.hash,
            label: 'Halaman',
            hint: 'mis. 12 atau 12-13',
            accent: AppColors.tahsinOn(context),
          ),
          onChanged: (_) => onHalamanChanged(),
          validator: (v) => !requireInput()
              ? null
              : ((v == null || v.trim().isEmpty) ? 'Wajib diisi' : null),
        ),
      ],
    );
  }
}
