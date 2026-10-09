import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/nilai_average.dart';
import '../../../core/utils/week_utils.dart';
import '../../../data/models/santri_record.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/pushed_page_header.dart';

/// Rata-rata nilai per siswa: semua nilai angka dijumlah (total), lalu dibagi jumlah nilai.
/// Dihitung langsung dari semua laporan yang ada, jadi laporan lama tetap ikut; laporan tanpa
/// nilai angka dilewati dan dihitung sebagai "tanpa nilai".
class RataNilaiScreen extends StatefulWidget {
  const RataNilaiScreen({super.key});

  @override
  State<RataNilaiScreen> createState() => _RataNilaiScreenState();
}

class _RataNilaiScreenState extends State<RataNilaiScreen> {
  DateTime? _month; // null = semua bulan
  bool _monthInit = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.read<RecordsProvider>();
    final all = context.select<RecordsProvider, List<SantriRecord>>((p) => p.allSortedByDateDesc);
    final cs = Theme.of(context).colorScheme;

    final months = {for (final r in all) WeekUtils.ownerMonth(r.tanggal)}.toList()
      ..sort((a, b) => b.compareTo(a));
    if (!_monthInit) {
      _monthInit = true;
      final now = WeekUtils.ownerMonth(DateTime.now());
      _month = months.contains(now) ? now : (months.isEmpty ? null : months.first);
    }

    final q = _query.trim().toLowerCase();
    final records = all.where((r) {
      if (_month != null && WeekUtils.ownerMonth(r.tanggal) != _month) return false;
      return q.isEmpty || r.namaAnak.toLowerCase().contains(q);
    }).toList();
    final groups = provider.groupByKelasHalaqoh(records);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const PushedPageHeader(
              title: 'Rata-rata Nilai',
              subtitle: 'Total nilai dibagi jumlah nilai, per siswa',
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ChoiceChip(
                            label: const Text('Semua bulan'),
                            selected: _month == null,
                            onSelected: (_) => setState(() => _month = null),
                          ),
                          for (final m in months) ...[
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: Text(DateFormat('MMM yyyy', 'id_ID').format(m)),
                              selected: _month == m,
                              onSelected: (_) => setState(() => _month = m),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                        hintText: 'Cari nama siswa',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ],
                ),
              ),
            ),
            if (groups.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: LucideIcons.hash,
                  title: 'Belum ada nilai',
                  subtitle: 'Rata-rata muncul setelah ada laporan.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                sliver: SliverList.separated(
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, i) {
                    final g = groups[i];
                    final rows = _aggregate(g.records);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${g.kelas} • ${g.halaqoh}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            const SizedBox(height: 6),
                            for (final r in rows) _SiswaRow(row: r, cs: cs),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<_SiswaNilai> _aggregate(List<SantriRecord> recs) {
    final byKey = <String, _SiswaNilai>{};
    for (final r in recs) {
      final key = r.namaAnak.trim().toLowerCase();
      final s = byKey.putIfAbsent(key, () => _SiswaNilai(r.namaAnak.trim()));
      s.laporan++;
      final v = NilaiAverage.parse(r.nilai);
      if (v != null) {
        s.total += v;
        s.jumlah++;
      }
    }
    return byKey.values.toList()..sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
  }
}

class _SiswaNilai {
  final String nama;
  double total = 0;
  int jumlah = 0;
  int laporan = 0;
  _SiswaNilai(this.nama);

  double? get rata => jumlah == 0 ? null : total / jumlah;
}

class _SiswaRow extends StatelessWidget {
  final _SiswaNilai row;
  final ColorScheme cs;
  const _SiswaRow({required this.row, required this.cs});

  @override
  Widget build(BuildContext context) {
    final tanpa = row.laporan - row.jumlah;
    final detail = row.jumlah == 0
        ? '${row.laporan} laporan, belum ada nilai'
        : 'Total ${NilaiAverage.format(row.total)} • ${row.jumlah} nilai'
            '${tanpa > 0 ? ' • $tanpa laporan tanpa nilai' : ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.nama, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(detail, style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            row.rata == null ? '-' : NilaiAverage.format(row.rata!),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: cs.primary),
          ),
        ],
      ),
    );
  }
}
