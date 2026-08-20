import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/santri_record.dart';
import '../../../data/services/quran_engine_service.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';

/// Menampilkan modal bottom sheet full-height untuk tambah/edit laporan.
Future<void> showRecordFormSheet(BuildContext context,
    {SantriRecord? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RecordFormSheet(existing: existing),
  );
}

class RecordFormSheet extends StatefulWidget {
  final SantriRecord? existing;
  const RecordFormSheet({super.key, this.existing});

  @override
  State<RecordFormSheet> createState() => _RecordFormSheetState();
}

class _RecordFormSheetState extends State<RecordFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _tanggal;
  final _kelasCtrl = TextEditingController();
  final _halaqohCtrl = TextEditingController();
  final _namaCtrl = TextEditingController();
  late HafalanStatus _status;
  late Keterangan _keterangan;

  // Error manual buat 3 field dropdown+ketik (di luar Form karena
  // DropdownMenu nggak otomatis nyambung ke Form.validate()).
  String? _kelasError;
  String? _halaqohError;
  String? _namaError;

  // Tahfizh
  int? _surahNumber;
  final _ayatMulaiCtrl = TextEditingController();
  final _ayatSelesaiCtrl = TextEditingController();
  GeneratedLinesResult? _generated;
  bool _generating = false;
  String? _generateError;

  // Tahsin
  WafaLevel? _wafaLevel;
  final _halamanWafaCtrl = TextEditingController();

  final _catatanCtrl = TextEditingController();

  bool get _isEdit => widget.existing != null;

  // Kalau bukan "Hadir", kolom status capaian nggak wajib diisi & bakal
  // dikosongin lagi pas disimpan (biar konsisten pas diekspor).
  bool get _wajibIsiStatusCapaian => _keterangan == Keterangan.hadir;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _tanggal = e?.tanggal ?? DateTime.now();
    _kelasCtrl.text = e?.kelas ?? '';
    _halaqohCtrl.text = e?.halaqoh ?? '';
    _namaCtrl.text = e?.namaAnak ?? '';
    _status = e?.status ?? HafalanStatus.tahfizh;
    _keterangan = e?.keterangan ?? Keterangan.hadir;
    _surahNumber = e?.surahNumber;
    _ayatMulaiCtrl.text = e?.ayatMulai?.toString() ?? '';
    _ayatSelesaiCtrl.text = e?.ayatSelesai?.toString() ?? '';
    _wafaLevel = e?.wafaLevel;
    _halamanWafaCtrl.text = e?.halamanWafa ?? '';
    _catatanCtrl.text = e?.catatan ?? '';

    _kelasCtrl.addListener(() {
      if (_kelasError != null) setState(() => _kelasError = null);
    });
    _halaqohCtrl.addListener(() {
      if (_halaqohError != null) setState(() => _halaqohError = null);
    });
    _namaCtrl.addListener(() {
      if (_namaError != null) setState(() => _namaError = null);
    });

    if (e != null &&
        e.status == HafalanStatus.tahfizh &&
        e.totalBaris != null) {
      // Re-generate biar tampilan baris konsisten saat edit.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _generateLines(silent: true));
    }
  }

  @override
  void dispose() {
    _kelasCtrl.dispose();
    _halaqohCtrl.dispose();
    _namaCtrl.dispose();
    _ayatMulaiCtrl.dispose();
    _ayatSelesaiCtrl.dispose();
    _halamanWafaCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateLines({bool silent = false}) async {
    if (_namaCtrl.text.trim().isEmpty) {
      if (!silent) {
        setState(() => _generateError =
            'Isi nama anak dulu — dipakai untuk cek riwayat baris.');
      }
      return;
    }
    if (_surahNumber == null ||
        _ayatMulaiCtrl.text.trim().isEmpty ||
        _ayatSelesaiCtrl.text.trim().isEmpty) {
      if (!silent) {
        setState(
            () => _generateError = 'Pilih surah dan isi rentang ayat dulu.');
      }
      return;
    }
    final start = int.tryParse(_ayatMulaiCtrl.text.trim());
    final end = int.tryParse(_ayatSelesaiCtrl.text.trim());
    if (start == null || end == null || start < 1 || end < start) {
      if (!silent) {
        setState(() => _generateError = 'Rentang ayat tidak valid.');
      }
      return;
    }

    setState(() {
      _generating = true;
      _generateError = null;
    });

    await QuranEngineService.instance.load();

    final history = mounted
        ? context.read<RecordsProvider>().lineHistoryFor(
              _namaCtrl.text,
              excludeRecordId: widget.existing?.id,
            )
        : <String>{};

    final result = QuranEngineService.instance.generateLines(
      surah: _surahNumber!,
      start: start,
      end: end,
      excludeLineIds: history,
    );

    setState(() {
      _generating = false;
      _generated = result;
      if (!result.available) {
        _generateError =
            'Mapping baris belum tersedia untuk surah ini pada dataset aktif (${QuranEngineService.instance.missingText()}).';
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _tanggal = picked);
  }

  void _submit() {
    setState(() {
      _kelasError = _kelasCtrl.text.trim().isEmpty ? 'Wajib diisi' : null;
      _halaqohError = _halaqohCtrl.text.trim().isEmpty ? 'Wajib diisi' : null;
      _namaError = _namaCtrl.text.trim().isEmpty ? 'Wajib diisi' : null;
    });
    final formValid = _formKey.currentState!.validate();
    if (!formValid ||
        _kelasError != null ||
        _halaqohError != null ||
        _namaError != null) {
      return;
    }

    final isiStatusCapaian = _wajibIsiStatusCapaian;

    if (isiStatusCapaian && _status == HafalanStatus.tahfizh) {
      if (_surahNumber == null ||
          _generated == null ||
          !_generated!.available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Generate baris dulu sebelum simpan (untuk tahfizh).')),
        );
        return;
      }
    }

    final isTahfizh = isiStatusCapaian && _status == HafalanStatus.tahfizh;
    final isTahsin = isiStatusCapaian && _status == HafalanStatus.tahsin;

    final record = SantriRecord(
      id: widget.existing?.id ?? const Uuid().v4(),
      tanggal: _tanggal,
      kelas: _kelasCtrl.text.trim(),
      halaqoh: _halaqohCtrl.text.trim().toUpperCase(),
      namaAnak: _namaCtrl.text.trim(),
      status: _status,
      keterangan: _keterangan,
      surahNumber: isTahfizh ? _surahNumber : null,
      surahName: isTahfizh ? kSurahNames[_surahNumber] : null,
      ayatMulai: isTahfizh ? int.tryParse(_ayatMulaiCtrl.text) : null,
      ayatSelesai: isTahfizh ? int.tryParse(_ayatSelesaiCtrl.text) : null,
      totalBaris: isTahfizh ? _generated?.totalBaris : null,
      lineIds: isTahfizh ? _generated?.newLineIds : null,
      wafaLevel: isTahsin ? _wafaLevel : null,
      halamanWafa: isTahsin ? _halamanWafaCtrl.text.trim() : null,
      catatan:
          _catatanCtrl.text.trim().isEmpty ? null : _catatanCtrl.text.trim(),
    );

    context.read<RecordsProvider>().upsert(record);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final dataset = context.read<RecordsProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).bottomSheetTheme.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEdit ? 'Edit Laporan' : 'Laporan Baru',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(
                        20, 16, 20, mq.viewInsets.bottom + 24),
                    children: [
                      const SectionLabel('TANGGAL'),
                      _buildDateField(cs),
                      const SizedBox(height: 20),
                      const SectionLabel('IDENTITAS SANTRI'),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownTypeField(
                              controller: _kelasCtrl,
                              label: 'Kelas',
                              hint: 'mis. 7, 8, 9',
                              icon: Icons.class_outlined,
                              options: dataset.distinctKelas,
                              errorText: _kelasError,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownTypeField(
                              controller: _halaqohCtrl,
                              label: 'Halaqoh',
                              hint: 'mis. A, B, C',
                              icon: Icons.groups_outlined,
                              options: dataset.distinctHalaqoh,
                              errorText: _halaqohError,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownTypeField(
                        controller: _namaCtrl,
                        label: 'Nama Anak',
                        icon: Icons.person_outline_rounded,
                        options: dataset.distinctNamaSantri,
                        errorText: _namaError,
                      ),
                      const SizedBox(height: 20),
                      const SectionLabel('STATUS CAPAIAN'),
                      _buildStatusSelector(cs),
                      if (!_wajibIsiStatusCapaian) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  size: 16, color: Color(0xFFB8860B)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Keterangan "${_keterangan.label}" — kolom status capaian nggak wajib diisi, akan dikosongkan saat disimpan.',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFFB8860B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _status == HafalanStatus.tahfizh
                            ? _buildTahfizhFields(cs)
                            : _buildTahsinFields(cs),
                      ),
                      const SizedBox(height: 20),
                      const SectionLabel('KETERANGAN'),
                      _buildKeteranganSelector(cs),
                      const SizedBox(height: 20),
                      const SectionLabel('CATATAN (OPSIONAL)'),
                      TextFormField(
                        controller: _catatanCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Catatan tambahan untuk musyrif/ortu...',
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.primary.withValues(alpha: 0.14),
                            foregroundColor: cs.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          onPressed: _submit,
                          icon: const Icon(Icons.check_rounded),
                          label: Text(
                              _isEdit ? 'Simpan Perubahan' : 'Simpan Laporan'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateField(ColorScheme cs) {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Tanggal',
          prefixIcon: Icon(Icons.calendar_today_rounded),
        ),
        child: Text(DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_tanggal)),
      ),
    );
  }

  Widget _buildStatusSelector(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: CategoryTile(
              label: HafalanStatus.tahfizh.label,
              icon: HafalanStatus.tahfizh.icon,
              color: cs.primary,
              active: _status == HafalanStatus.tahfizh,
              onTap: () => setState(() {
                _status = HafalanStatus.tahfizh;
                _generateError = null;
              }),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: CategoryTile(
              label: HafalanStatus.tahsin.label,
              icon: HafalanStatus.tahsin.icon,
              color: const Color(0xFFB8860B),
              active: _status == HafalanStatus.tahsin,
              onTap: () => setState(() {
                _status = HafalanStatus.tahsin;
                _generateError = null;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTahfizhFields(ColorScheme cs) {
    return Column(
      key: const ValueKey('tahfizh'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          initialValue: _surahNumber,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Surah',
            prefixIcon: Icon(Icons.menu_book_rounded),
          ),
          items: kSurahNames.entries
              .map((e) => DropdownMenuItem(
                  value: e.key, child: Text('${e.key}. ${e.value}')))
              .toList(),
          onChanged: (v) => setState(() {
            _surahNumber = v;
            _generated = null;
            _generateError = null;
          }),
          validator: (v) =>
              !_wajibIsiStatusCapaian ? null : (v == null ? 'Pilih surah' : null),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _ayatMulaiCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Dari Ayat'),
                onChanged: (_) => setState(() => _generated = null),
                validator: (v) => !_wajibIsiStatusCapaian
                    ? null
                    : ((v == null || v.trim().isEmpty) ? 'Wajib' : null),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _ayatSelesaiCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sampai Ayat'),
                onChanged: (_) => setState(() => _generated = null),
                validator: (v) => !_wajibIsiStatusCapaian
                    ? null
                    : ((v == null || v.trim().isEmpty) ? 'Wajib' : null),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: _generating ? null : () => _generateLines(),
            icon: _generating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_fix_high_rounded),
            label: Text(_generating ? 'Menghitung...' : 'Generate Baris'),
          ),
        ),
        if (_generateError != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: cs.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_generateError!,
                      style: TextStyle(fontSize: 12.5, color: cs.error)),
                ),
              ],
            ),
          ),
        ],
        if (_generated != null && _generated!.available) ...[
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Row(
                    children: [
                      Icon(Icons.format_list_numbered_rounded,
                          size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Kolom Baris',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: cs.primary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_generated!.totalBaris} baris baru',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_generated!.alreadyCountedLines.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.history_rounded,
                              size: 15, color: Color(0xFFB8860B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${_generated!.alreadyCountedLines.length} baris sudah pernah dihitung di laporan sebelumnya (tidak dihitung dobel)',
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFFB8860B),
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_generated!.newLines.isEmpty &&
                    _generated!.alreadyCountedLines.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Text(
                      'Semua baris di rentang ini sudah pernah dihitung sebelumnya.',
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ),
                if (_generated!.newLines.isNotEmpty) ...[
                  const Divider(height: 1),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _generated!.newLines.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 14, endIndent: 14),
                      itemBuilder: (context, i) {
                        final l = _generated!.newLines[i];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 13,
                            backgroundColor: cs.primary.withValues(alpha: 0.15),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary),
                            ),
                          ),
                          title: Text(
                              'Hal. ${l.pageNumber} — Baris ${l.lineNumber}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(l.ayatRangeText,
                              style: const TextStyle(fontSize: 12)),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTahsinFields(ColorScheme cs) {
    return Column(
      key: const ValueKey('tahsin'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<WafaLevel>(
          initialValue: _wafaLevel,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Jenjang WAFA',
            prefixIcon: Icon(Icons.auto_stories_outlined),
          ),
          items: WafaLevel.values
              .map((w) => DropdownMenuItem(value: w, child: Text(w.label)))
              .toList(),
          onChanged: (v) => setState(() => _wafaLevel = v),
          validator: (v) => !_wajibIsiStatusCapaian
              ? null
              : (v == null ? 'Pilih jenjang WAFA' : null),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _halamanWafaCtrl,
          decoration: const InputDecoration(
            labelText: 'Halaman',
            hintText: 'mis. 12 atau 12-13',
            prefixIcon: Icon(Icons.tag_rounded),
          ),
          validator: (v) => !_wajibIsiStatusCapaian
              ? null
              : ((v == null || v.trim().isEmpty) ? 'Wajib diisi' : null),
        ),
      ],
    );
  }

  Widget _buildKeteranganSelector(ColorScheme cs) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: Keterangan.values.map((k) {
        final selected = _keterangan == k;
        final color = _keteranganColor(k);
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _keterangan = k),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.14)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? color : Colors.transparent, width: 1.3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(k.icon,
                    size: 15, color: selected ? color : cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  k.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? color : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _keteranganColor(Keterangan k) {
    switch (k) {
      case Keterangan.hadir:
        return const Color(0xFF2E9E5B);
      case Keterangan.izinSakit:
        return const Color(0xFFE0724A);
      case Keterangan.izinLomba:
        return const Color(0xFF6C5CE7);
      case Keterangan.izinPelatihan:
        return const Color(0xFF2F80B4);
      case Keterangan.alpa:
        return const Color(0xFFD64545);
    }
  }
}
