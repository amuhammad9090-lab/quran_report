import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';
import 'santri_detail_screen.dart';

/// Daftar semua santri unik yang sudah tercatat di laporan — cukup nama,
/// kelas, halaqoh (bukan detail laporan seperti tab Laporan). Tap satu
/// santri untuk lihat riwayat lengkapnya per tanggal.
class SantriListScreen extends StatefulWidget {
  const SantriListScreen({super.key});

  @override
  State<SantriListScreen> createState() => _SantriListScreenState();
}

class _SantriListScreenState extends State<SantriListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final all = provider.santriList;
    final list = _query.trim().isEmpty
        ? all
        : all.where((s) => s.nama.toLowerCase().contains(_query.trim().toLowerCase())).toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            PushedPageHeader(
              title: 'Daftar Santri',
              subtitle: '${all.length} santri tercatat',
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              sliver: SliverToBoxAdapter(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Cari nama santri...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),
            if (list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: _query.isNotEmpty ? Icons.search_off_rounded : Icons.groups_2_rounded,
                  title: _query.isNotEmpty ? 'Santri tidak ditemukan' : 'Belum ada santri',
                  subtitle: _query.isNotEmpty
                      ? 'Coba kata kunci lain.'
                      : 'Santri akan muncul di sini setelah ada laporan pertama.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                sliver: SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final s = list[i];
                    return _SantriListCard(
                      summary: s,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SantriDetailScreen(namaAnak: s.nama),
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
}

class _SantriListCard extends StatelessWidget {
  final SantriSummary summary;
  final VoidCallback onTap;
  const _SantriListCard({required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  summary.nama.isNotEmpty ? summary.nama[0].toUpperCase() : '?',
                  style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.nama,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kelas ${summary.kelas} • Halaqoh ${summary.halaqoh}',
                      style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
