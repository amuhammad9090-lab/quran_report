import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';

/// Catatan kuning di bawah pemilih status: kolom status capaian tidak wajib (dan dikosongkan saat
/// disimpan) karena keterangan bukan Hadir, atau ditandai "tanpa capaian".
class RecordOptionalStatusNotice extends StatelessWidget {
  final bool tanpaCapaian;
  final String keteranganLabel;

  const RecordOptionalStatusNotice({
    super.key,
    required this.tanpaCapaian,
    required this.keteranganLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.info,
                size: 16, color: AppColors.tahsinOn(context)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tanpaCapaian
                    ? 'Tanpa capaian: status capaian tidak wajib dan akan dikosongkan. Catatan wajib diisi.'
                    : 'Keterangan "$keteranganLabel": status capaian tidak wajib dan akan dikosongkan.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.tahsinOn(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
