import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../data/models/student.dart';
import '../../../data/models/user_account.dart';
import '../../../data/services/school_data_excel_service.dart';
import '../../widgets/common/empty_state.dart';

/// Hasil pilihan admin di [ImportPreviewScreen] -- baris mana yang jadi
/// beneran diterapkan (student & account bisa jalan independen, admin
/// boleh cuma terapkan salah satu sheet doang).
class ImportSelection {
  final List<Student> students;
  final List<UserAccount> accounts;
  const ImportSelection({required this.students, required this.accounts});
}

/// Preview perubahan hasil parsing file Excel (sheet Murid & Guru)
/// SEBELUM ditulis ke Firestore -- admin bisa uncheck baris tertentu per
/// sheet, atau batal semua kalau salah file.
class ImportPreviewScreen extends StatefulWidget {
  final SchoolDataImportResult result;
  const ImportPreviewScreen({super.key, required this.result});

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> {
  late final Set<String> _excludedStudents = {};
  late final Set<String> _excludedAccounts = {};

  @override
  Widget build(BuildContext context) {
    final studentChanges = widget.result.students.changedRows;
    final accountChanges = widget.result.accounts.changedRows;
    final includedCount = (studentChanges.length - _excludedStudents.length) +
        (accountChanges.length - _excludedAccounts.length);

    return Scaffold(
      appBar: AppBar(title: Text('Preview ($includedCount perubahan)')),
      body: Column(
        children: [
          if (widget.result.students.unknownIds.isNotEmpty || widget.result.accounts.unknownIds.isNotEmpty)
            UnknownIdsBanner(
              studentUnknownIds: widget.result.students.unknownIds,
              accountUnknownIds: widget.result.accounts.unknownIds,
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (accountChanges.isNotEmpty) ...[
                  const PreviewSectionLabel('Guru'),
                  for (final row in accountChanges)
                    CheckboxListTile(
                      value: !_excludedAccounts.contains(row.current.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _excludedAccounts.remove(row.current.id);
                        } else {
                          _excludedAccounts.add(row.current.id);
                        }
                      }),
                      title: Text(row.current.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${row.current.displayName} (${row.current.assignments.length} kelas/halaqoh)  →  '
                        '${row.newDisplayName} (${row.newAssignments.length} kelas/halaqoh)',
                      ),
                    ),
                ],
                if (studentChanges.isNotEmpty) ...[
                  const PreviewSectionLabel('Siswa'),
                  for (final row in studentChanges)
                    CheckboxListTile(
                      value: !_excludedStudents.contains(row.current.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _excludedStudents.remove(row.current.id);
                        } else {
                          _excludedStudents.add(row.current.id);
                        }
                      }),
                      title: Text(row.current.nama, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${row.current.kelas} • ${row.current.halaqoh}  →  ${row.newKelas} • ${row.newHalaqoh}',
                      ),
                    ),
                ],
                if (studentChanges.isEmpty && accountChanges.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: LucideIcons.folderLock,
                      title: 'Tidak ada perubahan',
                      subtitle: 'Semua baris di file sama persis dengan data sekarang.',
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: includedCount == 0
                    ? null
                    : () => Navigator.of(context).pop(
                          ImportSelection(
                            students: [
                              for (final row in studentChanges)
                                if (!_excludedStudents.contains(row.current.id)) row.toUpdatedStudent(),
                            ],
                            accounts: [
                              for (final row in accountChanges)
                                if (!_excludedAccounts.contains(row.current.id)) row.toUpdatedAccount(),
                            ],
                          ),
                        ),
                icon: const Icon(LucideIcons.circleCheck),
                label: Text('Terapkan $includedCount Perubahan'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PreviewSectionLabel extends StatelessWidget {
  final String title;
  const PreviewSectionLabel(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          letterSpacing: 0.3,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class UnknownIdsBanner extends StatelessWidget {
  final List<String> studentUnknownIds;
  final List<String> accountUnknownIds;
  const UnknownIdsBanner({super.key, required this.studentUnknownIds, required this.accountUnknownIds});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (studentUnknownIds.isNotEmpty)
        '${studentUnknownIds.length} baris siswa dengan ID tidak dikenali: '
            '${studentUnknownIds.take(5).join(', ')}${studentUnknownIds.length > 5 ? ', ...' : ''}',
      if (accountUnknownIds.isNotEmpty)
        '${accountUnknownIds.length} baris guru dengan ID tidak dikenali: '
            '${accountUnknownIds.take(5).join(', ')}${accountUnknownIds.length > 5 ? ', ...' : ''}',
    ];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.triangleAlert, size: 18, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              parts.join('\n'),
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
