import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../data/models/ketuntasan_config.dart';
import '../../../data/services/ketuntasan_settings_service.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/common/pushed_page_header.dart';

/// Standar ketuntasan: target baris Tahfizh per pekan dan KKM nilai Tahsin. Admin (Mode Admin
/// aktif) yang bisa mengubah; yang lain hanya melihat. Dipakai kolom Status di rekap pekanan/bulanan.
class StandarKetuntasanScreen extends StatefulWidget {
  const StandarKetuntasanScreen({super.key});

  @override
  State<StandarKetuntasanScreen> createState() => _StandarKetuntasanScreenState();
}

class _StandarKetuntasanScreenState extends State<StandarKetuntasanScreen> {
  final _baris = <String, TextEditingController>{};
  late final TextEditingController _kkm;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final cfg = KetuntasanSettingsService.instance.config;
    for (final f in KetuntasanConfig.barisFields) {
      _baris[f.key] = TextEditingController(text: '${cfg.barisFor(f.key) ?? f.def}');
    }
    _kkm = TextEditingController(text: _fmt(cfg.kkmTahsin));
  }

  @override
  void dispose() {
    for (final c in _baris.values) {
      c.dispose();
    }
    _kkm.dispose();
    super.dispose();
  }

  String _fmt(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  Future<void> _save() async {
    final baris = <String, int>{};
    for (final f in KetuntasanConfig.barisFields) {
      final v = int.tryParse(_baris[f.key]!.text.trim());
      if (v == null || v <= 0) return _snack('Isi ${f.label} dengan angka lebih dari 0.');
      baris[f.key] = v;
    }
    final k = double.tryParse(_kkm.text.trim().replaceAll(',', '.'));
    if (k == null || k <= 0) {
      return _snack('Isi KKM Tahsin dengan angka lebih dari 0.');
    }
    setState(() => _saving = true);
    try {
      await KetuntasanSettingsService.instance.save(
        KetuntasanConfig(baris: baris, kkmTahsin: k),
      );
      _snack('Standar tersimpan.');
    } catch (_) {
      _snack('Gagal menyimpan. Cek koneksi internet, lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _step(TextEditingController c, num delta, {bool decimal = false}) {
    final cur = double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;
    final next = (cur + delta).clamp(1, 999).toDouble();
    setState(() => c.text = decimal ? _fmt(next) : '${next.toInt()}');
  }

  /// Satu baris: label di kiri, stepper (-  angka  +) di kanan. Angka juga bisa diketik langsung.
  Widget _row(String label, TextEditingController c, String suffix, bool editable, {bool decimal = false}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600))),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons.minus, size: 16),
                  onPressed: editable ? () => _step(c, -1, decimal: decimal) : null,
                ),
                SizedBox(
                  width: 48,
                  child: TextField(
                    controller: c,
                    enabled: editable,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons.plus, size: 16),
                  onPressed: editable ? () => _step(c, 1, decimal: decimal) : null,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              suffix,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  /// Satu kelompok: judul kecil di atas, lalu kartu berisi baris-baris yang dipisah garis tipis.
  Widget _group(String title, List<Widget> rows) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
          child: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: cs.primary),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
                rows[i],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _barisRow(String key, String label, bool editable) => _row(label, _baris[key]!, 'baris', editable);

  @override
  Widget build(BuildContext context) {
    final editable = context.watch<AuthProvider>().scope?.isAdmin ?? false;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const PushedPageHeader(
              title: 'Standar Ketuntasan',
              subtitle: 'Dipakai kolom Status di rekap pekanan & bulanan',
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              sliver: SliverList.list(
                children: [
                  if (!editable) ...[
                    Row(
                      children: [
                        Icon(LucideIcons.lock, size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Hanya admin (Mode Admin aktif) yang bisa mengubah.',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Target baris Tahfizh per pekan',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ),
                  _group('KELAS 7', [
                    _barisRow('k7', 'Halaqoh Tahfizh', editable),
                  ]),
                  const SizedBox(height: 12),
                  _group('KELAS 8', [
                    _barisRow('k8_Tahfizh', 'Halaqoh Tahfizh', editable),
                  ]),
                  const SizedBox(height: 12),
                  _group('KELAS 9', [
                    _barisRow('k9_A', 'Halaqoh A', editable),
                    _barisRow('k9_B', 'Halaqoh B', editable),
                    _barisRow('k9_C', 'Halaqoh C', editable),
                    _barisRow('k9_D', 'Halaqoh D', editable),
                  ]),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'KKM Tahsin (rata-rata nilai sepekan)',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ),
                  _group('TAHSIN', [
                    _row('Halaqoh Tahsin', _kkm, 'nilai', editable, decimal: true),
                  ]),
                  if (editable) ...[
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(LucideIcons.save, size: 18),
                      label: const Text('Simpan'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
