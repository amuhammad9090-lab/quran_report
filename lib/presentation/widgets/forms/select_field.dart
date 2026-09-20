import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'field_decoration.dart';

/// Field pilih-SAJA (tanpa ketik bebas): nilai HARUS salah satu dari [options].
/// Memakai [DropdownButtonFormField] + `initialValue`, jadi pemanggil WAJIB memberi
/// `key: ValueKey(value)` agar nilainya ikut refresh saat berubah dari luar.
class SelectField extends StatelessWidget {
  final String? value;
  final String label;
  final String? hint;
  final IconData icon;
  final List<String> options;
  final String? errorText;
  final Color? accent;
  final bool enabled;
  final ValueChanged<String?>? onChanged;

  const SelectField({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.options,
    required this.onChanged,
    this.hint,
    this.errorText,
    this.accent,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = accent ?? cs.primary;
    final safeValue = (value != null && options.contains(value)) ? value : null;
    final isUsable = enabled && options.isNotEmpty;
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      borderRadius: BorderRadius.circular(16),
      icon: Icon(LucideIcons.chevronDown,
          color: isUsable ? cs.onSurfaceVariant : cs.onSurfaceVariant.withValues(alpha: 0.4)),
      decoration: fieldDecoration(
        context,
        icon: icon,
        label: label,
        hint: hint,
        errorText: errorText,
        accent: color,
      ),
      disabledHint: hint != null
          ? Text(hint!,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5),
              overflow: TextOverflow.ellipsis)
          : null,
      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: cs.onSurface),
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: isUsable ? onChanged : null,
    );
  }
}
