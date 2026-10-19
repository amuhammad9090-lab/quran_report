import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/access/access_scope.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/santri_record.dart';
import '../../../data/services/app_prefs_service.dart';
import '../../../data/services/quran_engine_service.dart';
import '../../../providers/records_provider.dart';
import '../../../providers/students_provider.dart';
import '../../widgets/common/motion_widgets.dart';
import '../../widgets/common/viewer_guard.dart';
import '../../widgets/forms/field_decoration.dart';
import '../../widgets/forms/form_section_card.dart';
import '../../widgets/record/keterangan_selector.dart';
import '../../widgets/record/record_draft_banner.dart';
import '../../widgets/record/record_form_header.dart';
import '../../widgets/record/record_identity_fields.dart';
import '../../widgets/record/record_optional_status_notice.dart';
import '../../widgets/record/record_status_selector.dart';
import '../../widgets/record/record_submit_button.dart';
import '../../widgets/record/segment_states.dart';
import 'record_capaian_fields.dart';
import 'record_form_actions.dart';
import 'record_form_builder.dart';
import 'record_form_draft.dart';
import 'record_form_frame.dart';
import 'record_form_options.dart';

part 'record_form_sheet_fields.dart';
part 'record_form_sheet_logic.dart';

/// Modal bottom sheet full-height untuk tambah/edit laporan. [presetKelas]/[presetHalaqoh]/
/// [presetNama]/[presetTanggal] dipakai saat dibuka dari kartu santri di tab Laporan; dengan
/// [lockIdentity] identitas dikunci agar guru tak "salah pindah" ke santri lain di tengah pengisian.
Future<void> showRecordFormSheet(
  BuildContext context, {
  SantriRecord? existing,
  String? initialFolderId,
  String? presetKelas,
  String? presetHalaqoh,
  String? presetNama,
  DateTime? presetTanggal,
  bool lockIdentity = false,
}) {
  if (blockIfViewer(context)) return Future<void>.value();
  return showModalBottomSheet(
    context: context,
    constraints: const BoxConstraints(maxWidth: 640),
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RecordFormSheet(
      existing: existing,
      initialFolderId: initialFolderId,
      presetKelas: presetKelas,
      presetHalaqoh: presetHalaqoh,
      presetNama: presetNama,
      presetTanggal: presetTanggal,
      lockIdentity: lockIdentity,
    ),
  );
}

class RecordFormSheet extends StatefulWidget {
  final SantriRecord? existing;
  // Kalau laporan ini dibuat langsung dari dalam halaman folder, laporan
  // baru otomatis masuk ke folder tersebut.
  final String? initialFolderId;
  final String? presetKelas;
  final String? presetHalaqoh;
  final String? presetNama;
  final DateTime? presetTanggal;
  final bool lockIdentity;
  const RecordFormSheet({
    super.key,
    this.existing,
    this.initialFolderId,
    this.presetKelas,
    this.presetHalaqoh,
    this.presetNama,
    this.presetTanggal,
    this.lockIdentity = false,
  });

  @override
  State<RecordFormSheet> createState() => _RecordFormSheetState();
}

class _RecordFormSheetState extends State<RecordFormSheet> with _RecordFormFields, _RecordFormLogic {
  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _tanggal = e?.tanggal ?? widget.presetTanggal ?? DateTime.now();
    _kelas = e?.kelas ?? widget.presetKelas;
    _halaqoh = e?.halaqoh ?? widget.presetHalaqoh;
    _nama = e?.namaAnak ?? widget.presetNama;
    _status = e?.status ?? HafalanStatus.tahfizh;
    _keterangan = e?.keterangan ?? Keterangan.hadir;
    if (e != null) {
      _tahfizhSegs = tahfizhSegsFromRecord(e) ?? _tahfizhSegs;
      _tilawahSegs = tilawahSegsFromRecord(e) ?? _tilawahSegs;
    }
    _wafaLevel = e?.wafaLevel;
    _halamanWafaCtrl.text = e?.halamanWafa ?? '';
    _tahsinMode = e?.tahsinMode ?? TahsinMode.wafa;
    _catatanCtrl.text = e?.catatan ?? '';
    _nilaiCtrl.text = e?.nilai ?? '';

    if (e == null) {
      // Laporan baru & user hanya punya 1 assignment -> pre-fill kelas+halaqoh (tetap bisa diganti).
      // Dilewati kalau identitas dikunci dari kartu santri (lockIdentity): presetKelas/Halaqoh
      // sudah pasti benar dan tidak boleh ditimpa.
      if (!widget.lockIdentity) {
        final scope = _scope;
        if (scope != null && scope.user.assignments.length == 1) {
          final only = scope.user.assignments.first;
          _kelas = only.kelas;
          _halaqoh = only.halaqoh;
        }
      }

      // Cek draf laporan yang belum sempat disimpan (mis. sheet tertutup tak sengaja): kalau ada dan
      // tidak kosong, tawarkan lewat banner (jangan langsung menimpa pre-fill). Dilewati saat identitas
      // dikunci karena draf lama bisa milik santri LAIN dan bertentangan dengan kartu yang dibuka.
      if (!widget.lockIdentity) {
        final draft = parseRestorableDraft(AppPrefsService.instance.recordDraftJson);
        if (draft != null) {
          _restorableDraft = draft;
          _draftBannerVisible = true;
        }
      }
    }

    if (e != null &&
        (e.status == HafalanStatus.tahfizh || e.status == HafalanStatus.tahsinTahfizh) &&
        e.totalBaris != null) {
      // Re-generate biar tampilan baris konsisten saat edit.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _generateAllLines(silent: true));
    }
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    for (final s in _tahfizhSegs) {
      s.dispose();
    }
    for (final s in _tilawahSegs) {
      s.dispose();
    }
    _halamanWafaCtrl.dispose();
    _catatanCtrl.dispose();
    _nilaiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // context.watch di sini membuat build() rebuild tiap RecordsProvider/StudentsProvider berubah;
    // helper _kelasOptions dkk boleh memakai context.read karena elemen ini sudah "berlangganan".
    context.watch<RecordsProvider>();
    context.watch<StudentsProvider>();

    final comboBelumLengkap =
        _kelas == null || _kelas!.trim().isEmpty || _halaqoh == null || _halaqoh!.trim().isEmpty;

    return RecordFormFrame(
      messengerKey: _localMessengerKey,
      formKey: _formKey,
      header: RecordFormHeader(
        isEdit: _isEdit,
        nama: _nama,
        kelas: _kelas,
        halaqoh: _halaqoh,
        onDelete: () {
          final e = widget.existing;
          if (e != null) confirmDeleteRecord(context, e, _nama);
        },
      ),
      children: [
        if (_draftBannerVisible) ...[
          RecordDraftBanner(onDiscard: _discardDraft, onRestore: _restoreDraft),
          const SizedBox(height: 16),
        ],
        FormSectionCard(
          title: 'Tanggal',
          icon: LucideIcons.calendarDays,
          child: RecordDateField(tanggal: _tanggal, onTap: _pickDate),
        ),
        // Identitas santri (Kelas/Halaqoh/Nama) SENGAJA disembunyikan total saat dibuka dari kartu santri
        // (lockIdentity): identitasnya sudah jelas dari kartu, form cukup tanggal + status capaian +
        // keterangan + catatan.
        if (!widget.lockIdentity) ...[
          const SizedBox(height: 16),
          FormSectionCard(
            title: 'Identitas Siswa',
            icon: LucideIcons.medal,
            child: RecordIdentityFields(
              kelas: _kelas,
              halaqoh: _halaqoh,
              nama: _nama,
              kelasOptions: _kelasOptions(),
              halaqohOptions: _halaqohOptions(),
              namaOptions: _namaOptions(),
              kelasError: _kelasError,
              halaqohError: _halaqohError,
              namaError: _namaError,
              comboBelumLengkap: comboBelumLengkap,
              lockIdentity: widget.lockIdentity,
              onKelasChanged: _onKelasChanged,
              onHalaqohChanged: _onHalaqohChanged,
              onNamaChanged: _onNamaChanged,
            ),
          ),
        ],
        const SizedBox(height: 16),
        FormSectionCard(
          title: 'Status Capaian',
          icon: LucideIcons.trendingUp,
          child: Column(
            children: [
              RecordStatusSelector(
                selected: _status,
                onChanged: (s) {
                  setState(() {
                    _status = s;
                    _generateError = null;
                  });
                  _markEditedAndScheduleDraftSave();
                },
              ),
              if (!_wajibIsiStatusCapaian)
                RecordOptionalStatusNotice(
                  tanpaCapaian: _tanpaCapaian,
                  keteranganLabel: _keterangan.label,
                ),
              const SizedBox(height: 16),
              _capaianFields(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FormSectionCard(
          title: 'Nilai',
          icon: LucideIcons.hash,
          child: TextFormField(
            controller: _nilaiCtrl,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            decoration: fieldDecoration(
              context,
              icon: LucideIcons.hash,
              label: 'Nilai',
              hint: 'ketik nilai',
              accent: cs.primary,
            ),
            onChanged: (_) => _markEditedAndScheduleDraftSave(),
          ),
        ),
        const SizedBox(height: 16),
        FormSectionCard(
          title: 'Keterangan',
          icon: LucideIcons.clipboardCheck,
          child: KeteranganSelector(
            selected: _keterangan,
            tanpaCapaian: _tanpaCapaian,
            onSelected: (k) {
              setState(() {
                _keterangan = k;
                // Toggle "tanpa capaian" hanya relevan untuk Hadir; reset
                // saat keterangan dipindah agar nilainya tidak nyangkut.
                if (k != Keterangan.hadir) _tanpaCapaian = false;
              });
              _markEditedAndScheduleDraftSave();
            },
            onTanpaCapaianChanged: (v) {
              setState(() => _tanpaCapaian = v);
              _markEditedAndScheduleDraftSave();
            },
          ),
        ),
        const SizedBox(height: 16),
        FormSectionCard(
          title: _tanpaCapaian ? 'Catatan (Wajib)' : 'Catatan (Opsional)',
          icon: LucideIcons.penLine,
          child: TextFormField(
            controller: _catatanCtrl,
            maxLines: 3,
            decoration: fieldDecoration(
              context,
              icon: LucideIcons.fileText,
              label: _tanpaCapaian ? 'Catatan (wajib diisi)' : 'Catatan',
              hint: _tanpaCapaian
                  ? 'Alasan tidak ada capaian hari ini...'
                  : 'Catatan tambahan untuk guru atau orang tua...',
              accent: cs.primary,
            ),
            onChanged: (_) => _markEditedAndScheduleDraftSave(),
          ),
        ),
        const SizedBox(height: 28),
        RecordSubmitButton(isEdit: _isEdit, onPressed: _submit),
      ],
    );
  }

  /// Isian sesuai status capaian: state tetap di sini, widgetnya hanya menerima nilai + callback.
  Widget _capaianFields() => RecordCapaianFields(
        status: _status,
        tahfizhSegs: _tahfizhSegs,
        tilawahSegs: _tilawahSegs,
        tahsinMode: _tahsinMode,
        wafaLevel: _wafaLevel,
        halamanWafaCtrl: _halamanWafaCtrl,
        generating: _generating,
        generateError: _generateError,
        requireInput: () => _wajibIsiStatusCapaian,
        onAddTahfizhSegment: _addTahfizhSegment,
        onRemoveTahfizhSegment: _removeTahfizhSegment,
        onTahfizhSurahChanged: (seg, v) {
          setState(() {
            seg.surahNumber = v;
            seg.generated = null;
            _generateError = null;
          });
          _markEditedAndScheduleDraftSave();
        },
        onTahfizhAyatChanged: (seg) {
          setState(() => seg.generated = null);
          _markEditedAndScheduleDraftSave();
        },
        onGenerate: () => _generateAllLines(),
        onAddTilawahSegment: _addTilawahSegment,
        onRemoveTilawahSegment: _removeTilawahSegment,
        onTilawahSurahChanged: (seg, v) {
          setState(() => seg.surahNumber = v);
          _markEditedAndScheduleDraftSave();
        },
        onTahsinModeChanged: (m) {
          setState(() => _tahsinMode = m);
          _markEditedAndScheduleDraftSave();
        },
        onWafaLevelChanged: (v) {
          setState(() => _wafaLevel = v);
          _markEditedAndScheduleDraftSave();
        },
        onChanged: _markEditedAndScheduleDraftSave,
      );
}
