import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Badge kecil "Diedit" — dipakai [RecordSummaryRow] & [SantriReportCard]
/// (widget publik, dipakai lintas file). Sengaja netral (bukan warna
/// warning/error) soalnya edit itu wajar, bukan sesuatu yang "salah".
class EditedBadge extends StatelessWidget {
  final ColorScheme cs;
  const EditedBadge({super.key, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.penLine, size: 9, color: cs.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(
            'Diedit',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
