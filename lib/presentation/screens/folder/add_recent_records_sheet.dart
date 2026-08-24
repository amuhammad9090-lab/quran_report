import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/records_provider.dart';
import '../../widgets/status_badge.dart';

/// Bottom sheet "Tambah Laporan (Recent)" di halaman folder — pilih dari
/// kartu santri yang sudah ada (belum ada di folder ini) buat dimasukkan
/// ke folder ini, tanpa perlu bikin laporan baru. Satu pilihan = satu
/// kartu santri (SEMUA laporannya ikut pindah kalau sudah ada, atau
/// identitasnya "diparkir" ke folder ini kalau masih kosong) — konsisten
/// dengan [RecordsProvider.moveIdentityToFolder] yang dipakai di seluruh
/// alur pindah-folder lainnya sekarang.
Future<void> showAddRecentRecordsSheet(BuildContext context, {required String folderId}) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddRecentRecordsSheet(folderId: folderId),
  );
}

class _AddRecentRecordsSheet extends StatefulWidget {
  final String folderId;
  const _AddRecentRecordsSheet({required this.folderId});

  @override
  State<_AddRecentRecordsSheet> createState() => _AddRecentRecordsSheetState();
}

class _AddRecentRecordsSheetState extends State<_AddRecentRecordsSheet> {
  final Set<String> _picked = {};
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<RecordsProvider>();

    final candidates = provider.laporanCards
        .where((c) => c.currentFolderId != widget.folderId)
        .where((c) => c.nama.toLowerCase().contains(_searchCtrl.text.trim().toLowerCase()))
        .toList();

    return Padding(
      // WAJIB biar sheet ini kegeser naik ngikutin tinggi keyboard —
      // tanpa ini, begitu keyboard muncul dia numpuk di belakang/ketiban
      // keyboard (TextField pencarian jadi nggak keliatan pas diketik).
      // Sheet-sheet lain di app ini (folder_form_sheet.dart dkk) sudah
      // pakai pola yang sama.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          // Container ini SEKARANG cuma buat `constraints` (nggak ada
          // decoration lagi di sini) — background+rounded corner dipindah
          // ke Material di dalamnya, biar CheckboxListTile di list bawah
          // punya Material terdekat yang benar (nggak ketutup DecoratedBox
          // — lihat assertion "ListTile background color or ink splashes
          // may be invisible").
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Material(
            color: Theme.of(context).bottomSheetTheme.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text('Tambah Laporan',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Pilih dari kartu santri yang sudah ada ke folder ini',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Cari nama santri...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: candidates.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text('Tidak ada kartu santri yang bisa ditambahkan.',
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: candidates.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final c = candidates[i];
                          final checked = _picked.contains(c.identityKey);
                          return CheckboxListTile(
                            value: checked,
                            onChanged: (_) => setState(() {
                              checked ? _picked.remove(c.identityKey) : _picked.add(c.identityKey);
                            }),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(c.nama, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              c.hasAnyReport
                                  ? '${c.weeksWithReportThisMonth.length}/${c.totalWeeksThisMonth} pekan bulan ini • ${c.latestRecord!.capaianText}'
                                  : 'Belum ada laporan',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            secondary: c.hasAnyReport ? StatusBadge(status: c.latestRecord!.status) : null,
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _picked.isEmpty
                      ? null
                      : () async {
                          final provider = context.read<RecordsProvider>();
                          for (final key in _picked) {
                            final c = provider.cardByIdentityKey(key);
                            if (c != null) {
                              await provider.moveIdentityToFolder(c, widget.folderId);
                            }
                          }
                          if (context.mounted) Navigator.pop(context);
                        },
                  child: Text(_picked.isEmpty ? 'Pilih kartu dulu' : 'Tambahkan ${_picked.length} Kartu'),
                ),
              ),
            ],
          ),
              ),
            ),
          ),
        ),
    );
  }
}
