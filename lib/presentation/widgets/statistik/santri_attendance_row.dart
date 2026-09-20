import 'package:flutter/material.dart';

/// Baris ringkas 1 santri di dalam [DateGroupCard] — dipakai di halaman
/// Kehadiran (siapa hadir/izin/alpa per tanggal).
class SantriAttendanceRow extends StatelessWidget {
  final String nama;
  final String kelas;
  final String halaqoh;
  final Widget keteranganChip;
  final VoidCallback? onTap;

  const SantriAttendanceRow({
    super.key,
    required this.nama,
    required this.kelas,
    required this.halaqoh,
    required this.keteranganChip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: cs.primaryContainer,
              child: Text(
                nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nama,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Kelas $kelas • Halaqoh $halaqoh',
                    style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            keteranganChip,
          ],
        ),
      ),
    );
  }
}
