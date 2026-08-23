import 'package:flutter/material.dart';

import '../../providers/records_provider.dart';
import 'status_badge.dart';

/// Kartu rekap 1 kelompok Kelas+Halaqoh dalam suatu periode (pekan/bulan) —
/// dipakai di Rekap Pekanan & Rekap Bulanan, section "Rekap per Kelas &
/// Halaqoh". Header nampilin "Kelas X — Halaqoh Y" + tombol ekspor khusus
/// kelompok ini (biar guru pembimbing bisa ekspor rekap kelasnya sendiri),
/// di bawahnya daftar santri dengan cuma label status (Tahfizh/Tahsin/dst)
/// & jumlah baris — detail lengkap tetap ada di section "Semua Laporan".
class KelasHalaqohGroupCard extends StatelessWidget {
  final KelasHalaqohGroup group;
  final VoidCallback onExport;
  const KelasHalaqohGroupCard({super.key, required this.group, required this.onExport});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Kelas ${group.kelas} — Halaqoh ${group.halaqoh}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Ekspor rekap kelompok ini',
                  onPressed: onExport,
                  icon: const Icon(Icons.ios_share_rounded, size: 20),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerTheme.color),
          for (int i = 0; i < group.records.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 14, endIndent: 14, color: Theme.of(context).dividerTheme.color),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      group.records[i].namaAnak,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: group.records[i].status),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 58,
                    child: Text(
                      group.records[i].totalBaris != null
                          ? '${group.records[i].totalBaris} baris'
                          : '-',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
