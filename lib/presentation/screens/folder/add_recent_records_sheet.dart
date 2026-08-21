import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/records_provider.dart';

/// Bottom sheet "Tambah Laporan (Recent)" di halaman folder — pilih dari
/// laporan yang sudah ada (belum ada di folder ini) buat dimasukkan ke
/// folder ini, tanpa perlu bikin laporan baru.
Future<void> showAddRecentRecordsSheet(BuildContext context, {required String folderId}) {
  return showModalBottomSheet(
    context: context,
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

    final candidates = provider.allSortedByDateDesc
        .where((r) => r.folderId != widget.folderId)
        .where((r) => r.namaAnak.toLowerCase().contains(_searchCtrl.text.trim().toLowerCase()))
        .toList();

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: Theme.of(context).bottomSheetTheme.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
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
            Text('Pilih dari laporan yang sudah ada ke folder ini',
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
                      child: Text('Tidak ada laporan yang bisa ditambahkan.',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: candidates.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = candidates[i];
                        final checked = _picked.contains(r.id);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (_) => setState(() {
                            checked ? _picked.remove(r.id) : _picked.add(r.id);
                          }),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(r.namaAnak, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${DateFormat('d MMM yyyy', 'id_ID').format(r.tanggal)} • ${r.capaianText}',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
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
                        await context.read<RecordsProvider>().moveManyToFolder(_picked, widget.folderId);
                        if (context.mounted) Navigator.pop(context);
                      },
                child: Text(_picked.isEmpty ? 'Pilih laporan dulu' : 'Tambahkan ${_picked.length} Laporan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
