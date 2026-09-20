import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/models/enums.dart';

// Ikon tampilan untuk enum data — dipisah dari data/models/enums.dart supaya model
// tidak bergantung pada Flutter.
extension HafalanStatusIcon on HafalanStatus {
  IconData get icon => switch (this) {
        HafalanStatus.tahsin => LucideIcons.bookOpen,
        HafalanStatus.tahfizh => LucideIcons.bookOpen,
        HafalanStatus.tahsinTahfizh => LucideIcons.library,
        HafalanStatus.murojaahTasmi => LucideIcons.repeat,
      };
}

extension KeteranganIcon on Keterangan {
  IconData get icon => switch (this) {
        Keterangan.hadir => LucideIcons.circleCheck,
        Keterangan.izinSakit => LucideIcons.hospital,
        Keterangan.izin => LucideIcons.fileText,
        Keterangan.izinLomba => LucideIcons.trophy,
        Keterangan.izinPelatihan => LucideIcons.graduationCap,
        Keterangan.alpa => LucideIcons.circleX,
        Keterangan.tidakSetoran => Icons.edit_off_rounded,
        Keterangan.tidakTahsin => LucideIcons.bookOpen,
        Keterangan.tidakMurojaah => LucideIcons.rotateCcw,
      };
}
