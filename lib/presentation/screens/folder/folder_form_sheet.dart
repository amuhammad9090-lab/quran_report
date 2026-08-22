import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/folder.dart';
import '../../../providers/folders_provider.dart';
import '../../widgets/misc_widgets.dart';

/// Bottom sheet buat folder baru, atau rename folder yang sudah ada kalau
/// [existing] diisi. Muncul dengan animasi nyembul-dari-bawah bawaan
/// [showModalBottomSheet].
Future<void> showFolderFormSheet(BuildContext context, {ReportFolder? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FolderFormSheet(existing: existing),
  );
}

class FolderFormSheet extends StatefulWidget {
  final ReportFolder? existing;
  const FolderFormSheet({super.key, this.existing});

  @override
  State<FolderFormSheet> createState() => _FolderFormSheetState();
}

class _FolderFormSheetState extends State<FolderFormSheet> {
  late final _namaCtrl = TextEditingController(text: widget.existing?.nama ?? '');
  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _namaCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nama = _namaCtrl.text.trim();
    if (nama.isEmpty) {
      setState(() => _error = 'Nama folder wajib diisi');
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<FoldersProvider>();
    if (_isEdit) {
      await provider.rename(widget.existing!.id, nama);
    } else {
      await provider.create(nama);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).bottomSheetTheme.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
              Row(
                children: [
                  SoftIconBox(icon: Icons.folder_rounded, color: cs.secondary),
                  const SizedBox(width: 12),
                  Text(
                    _isEdit ? 'Ubah Nama Folder' : 'Buat Folder Baru',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _namaCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _save(),
                decoration: fieldDecoration(
                  context,
                  icon: Icons.drive_file_rename_outline_rounded,
                  label: 'Nama folder',
                  hint: 'contoh: Kelas 7 - Halaqoh A',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : Text(_isEdit ? 'Simpan' : 'Buat Folder'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
