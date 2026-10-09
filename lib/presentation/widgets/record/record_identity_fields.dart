import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../forms/select_field.dart';

/// Tiga pilihan identitas santri: Kelas, Halaqoh, dan Nama Anak. Daftar opsi dan penanganan
/// perubahan dilakukan pemanggil; widget ini hanya menampilkan.
class RecordIdentityFields extends StatelessWidget {
  final String? kelas;
  final String? halaqoh;
  final String? nama;
  final List<String> kelasOptions;
  final List<String> halaqohOptions;
  final List<String> namaOptions;
  final String? kelasError;
  final String? halaqohError;
  final String? namaError;

  /// True bila kelas atau halaqoh belum dipilih (Nama Anak menampilkan petunjuk).
  final bool comboBelumLengkap;
  final bool lockIdentity;
  final ValueChanged<String?> onKelasChanged;
  final ValueChanged<String?> onHalaqohChanged;
  final ValueChanged<String?> onNamaChanged;

  const RecordIdentityFields({
    super.key,
    required this.kelas,
    required this.halaqoh,
    required this.nama,
    required this.kelasOptions,
    required this.halaqohOptions,
    required this.namaOptions,
    required this.kelasError,
    required this.halaqohError,
    required this.namaError,
    required this.comboBelumLengkap,
    required this.lockIdentity,
    required this.onKelasChanged,
    required this.onHalaqohChanged,
    required this.onNamaChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SelectField(
                key: ValueKey('kelas_$kelas'),
                value: kelas,
                label: 'Kelas',
                icon: LucideIcons.graduationCap,
                options: kelasOptions,
                errorText: kelasError,
                accent: cs.primary,
                enabled: !lockIdentity,
                onChanged: onKelasChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SelectField(
                key: ValueKey('halaqoh_$halaqoh'),
                value: halaqoh,
                label: 'Halaqoh',
                icon: LucideIcons.usersRound,
                options: halaqohOptions,
                errorText: halaqohError,
                accent: cs.primary,
                enabled: !lockIdentity,
                onChanged: onHalaqohChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SelectField(
          key: ValueKey('nama_$nama'),
          value: nama,
          label: 'Nama Siswa',
          hint: comboBelumLengkap
              ? 'Pilih kelas & halaqoh dulu'
              : null,
          icon: LucideIcons.user,
          options: namaOptions,
          errorText: namaError,
          accent: cs.primary,
          enabled: !lockIdentity,
          onChanged: onNamaChanged,
        ),
      ],
    );
  }
}
