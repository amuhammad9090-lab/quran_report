part of 'record_form_sheet.dart';

/// Draf, segmen, generate baris, pilih tanggal, dan submit untuk [_RecordFormSheetState].
mixin _RecordFormLogic on State<RecordFormSheet>, _RecordFormFields {
  // --- Draft laporan baru ---

  @override
  void _markEditedAndScheduleDraftSave() {
    if (_isEdit) return;
    // Begitu user mulai pilih/ketik sendiri, banner "lanjutkan draf lama"
    // udah nggak relevan lagi (isian yang sedang berjalan SEKARANG-lah
    // yang jadi draf terbaru).
    if (_draftBannerVisible) {
      setState(() => _draftBannerVisible = false);
    }
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 500), _persistDraftNow);
  }

  Map<String, dynamic> _draftSnapshot() => recordDraftSnapshot(
        tanggal: _tanggal,
        kelas: _kelas,
        halaqoh: _halaqoh,
        nama: _nama,
        status: _status,
        keterangan: _keterangan,
        tahfizhSegs: _tahfizhSegs,
        tahsinMode: _tahsinMode,
        wafaLevel: _wafaLevel,
        halamanWafa: _halamanWafaCtrl.text,
        tilawahSegs: _tilawahSegs,
        catatan: _catatanCtrl.text,
        nilai: _nilaiCtrl.text,
      );

  Future<void> _persistDraftNow() async {
    if (_isEdit || !mounted) return;
    await AppPrefsService.instance.saveRecordDraft(jsonEncode(_draftSnapshot()));
  }

  Future<void> _clearDraft() async {
    _draftDebounce?.cancel();
    await AppPrefsService.instance.clearRecordDraft();
  }

  void _restoreDraft() {
    final d = _restorableDraft;
    if (d == null) return;
    try {
      setState(() {
        _draftBannerVisible = false;
        final tanggalStr = d['tanggal'] as String?;
        if (tanggalStr != null) {
          _tanggal = DateTime.tryParse(tanggalStr) ?? _tanggal;
        }
        _kelas = d['kelas'] as String?;
        _halaqoh = d['halaqoh'] as String?;
        _nama = d['nama'] as String?;
        final statusName = d['status'] as String?;
        if (statusName != null) {
          _status = HafalanStatus.values.byName(statusName);
        }
        final keteranganName = d['keterangan'] as String?;
        if (keteranganName != null) {
          _keterangan = Keterangan.values.byName(keteranganName);
        }
        _tahfizhSegs = tahfizhSegsFromDraft(d['tahfizhSegs']) ?? _tahfizhSegs;
        final wafaName = d['wafaLevel'] as String?;
        _wafaLevel = wafaName != null ? WafaLevel.values.byName(wafaName) : null;
        _halamanWafaCtrl.text = (d['halamanWafa'] as String?) ?? '';
        final tahsinModeName = d['tahsinMode'] as String?;
        _tahsinMode =
            tahsinModeName != null ? TahsinMode.values.byName(tahsinModeName) : TahsinMode.wafa;
        _tilawahSegs = tilawahSegsFromDraft(d['tilawahSegs']) ?? _tilawahSegs;
        _catatanCtrl.text = (d['catatan'] as String?) ?? '';
        _nilaiCtrl.text = (d['nilai'] as String?) ?? '';
      });
    } catch (_) {
      // Draf format lama/nggak dikenal sebagian field-nya — biarkan aja
      // apa yang berhasil ke-restore, jangan crash.
    }

    if ((_status == HafalanStatus.tahfizh || _status == HafalanStatus.tahsinTahfizh) &&
        _tahfizhSegs.every((s) =>
            s.surahNumber != null &&
            s.ayatMulaiCtrl.text.trim().isNotEmpty &&
            s.ayatSelesaiCtrl.text.trim().isNotEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _generateAllLines(silent: true));
    }
    _maybeWarnOwnership();
  }

  void _discardDraft() {
    setState(() {
      _draftBannerVisible = false;
      _restorableDraft = null;
    });
    _clearDraft();
  }

  void _addTahfizhSegment() {
    setState(() => _tahfizhSegs.add(TahfizhSegState()));
    _markEditedAndScheduleDraftSave();
  }

  void _removeTahfizhSegment(int index) {
    setState(() {
      _tahfizhSegs[index].dispose();
      _tahfizhSegs.removeAt(index);
    });
    _markEditedAndScheduleDraftSave();
  }

  void _addTilawahSegment() {
    setState(() => _tilawahSegs.add(TilawahSegState()));
    _markEditedAndScheduleDraftSave();
  }

  void _removeTilawahSegment(int index) {
    setState(() {
      _tilawahSegs[index].dispose();
      _tilawahSegs.removeAt(index);
    });
    _markEditedAndScheduleDraftSave();
  }

  /// Generate baris untuk SEMUA segmen Tahfizh (bisa >1 surah): tiap segmen digenerate sendiri lewat
  /// [QuranEngineService.generateLines] (1 surah per panggilan) lalu digabung; baris dari segmen
  /// sebelumnya ikut di-exclude di segmen berikutnya (jaga-jaga overlap di batas transisi surah).
  Future<void> _generateAllLines({bool silent = false}) async {
    final check = validateTahfizhRanges(_nama, _tahfizhSegs);
    if (check.error != null) {
      if (!silent) setState(() => _generateError = check.error);
      return;
    }

    setState(() {
      _generating = true;
      _generateError = null;
    });

    await QuranEngineService.instance.load();

    final history = mounted
        ? context.read<RecordsProvider>().lineHistoryFor(
              _nama!,
              excludeRecordId: widget.existing?.id,
            )
        : <String>{};
    final anyUnavailable = generateTahfizhLines(_tahfizhSegs, check.ranges!, history);

    setState(() {
      _generating = false;
      if (anyUnavailable) {
        _generateError =
            'Data baris belum tersedia untuk salah satu surah (${QuranEngineService.instance.missingText()}).';
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
    if (picked != null) {
      setState(() => _tanggal = picked);
      _markEditedAndScheduleDraftSave();
    }
  }

  Future<void> _submit() async {
    setState(() {
      _kelasError = (_kelas == null || _kelas!.trim().isEmpty) ? 'Wajib dipilih' : null;
      _halaqohError = (_halaqoh == null || _halaqoh!.trim().isEmpty) ? 'Wajib dipilih' : null;
      _namaError = (_nama == null || _nama!.trim().isEmpty) ? 'Wajib dipilih' : null;
    });
    final formValid = _formKey.currentState!.validate();
    if (!formValid ||
        _kelasError != null ||
        _halaqohError != null ||
        _namaError != null) {
      return;
    }

    // Kalau ditandai "Hadir tanpa capaian hari ini", catatan WAJIB diisi — itu satu-satunya
    // penjelasan kenapa tak ada capaian padahal Hadir (lihat toggle _tanpaCapaian).
    if (_tanpaCapaian && _catatanCtrl.text.trim().isEmpty) {
      _localMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Isi catatan dulu: wajib jika tidak ada capaian hari ini.'),
        ),
      );
      return;
    }

    final isiStatusCapaian = _wajibIsiStatusCapaian;

    final needsTahfizhPart =
        _status == HafalanStatus.tahfizh || _status == HafalanStatus.tahsinTahfizh;

    if (isiStatusCapaian && needsTahfizhPart) {
      // Segmen siap kalau (a) generate sukses dari dataset, ATAU (b) dataset belum meng-cover surah itu
      // (mis. Juz 11-25) tapi user sudah mengisi jumlah baris manual (lihat `manualBarisCtrl`).
      final allReady = _tahfizhSegs.every((s) => s.isReady);
      if (!allReady) {
        final anyUnavailable = _tahfizhSegs.any((s) => s.datasetUnavailable);
        _localMessengerKey.currentState?.showSnackBar(
          SnackBar(
              content: Text(anyUnavailable
                  ? 'Isi jumlah baris manual untuk surah yang datanya belum ada.'
                  : 'Tekan Generate Baris dulu sebelum menyimpan.')),
        );
        return;
      }
    }

    final record = buildRecordFromForm(
      existing: widget.existing,
      initialFolderId: widget.initialFolderId,
      // Dicatat untuk audit "siapa yang input laporan ini" (terutama admin di luar kelas/halaqoh-nya,
      // lihat _maybeWarnOwnership).
      ownerId: _scope?.user.id,
      studentId: findStudentId(context.read<StudentsProvider>().all, _nama!, _kelas!, _halaqoh!),
      tanggal: _tanggal,
      kelas: _kelas!,
      halaqoh: _halaqoh!,
      nama: _nama!,
      status: _status,
      keterangan: _keterangan,
      isiStatusCapaian: isiStatusCapaian,
      tahfizhSegs: _tahfizhSegs,
      tahsinMode: _tahsinMode,
      wafaLevel: _wafaLevel,
      halamanWafa: _halamanWafaCtrl.text,
      tilawahSegs: _tilawahSegs,
      catatan: _catatanCtrl.text,
      nilai: _nilaiCtrl.text,
    );

    // context dipakai lagi setelah await -> WAJIB cek `mounted` tiap kali agar lint "don't use
    // BuildContext across async gaps" bersih (pola .then()/.catchError() tak terbaca aman analyzer).
    final recordsProvider = context.read<RecordsProvider>();
    try {
      await recordsProvider.upsert(record);
      // Laporan berhasil disimpan -> draf yang sempat kesimpen (kalau
      // ada) udah nggak relevan lagi, bersihkan.
      if (!_isEdit) await _clearDraft();
      if (!mounted) return;
      // Centang "berhasil" tampil di overlay root, jadi tetap terlihat walau sheet ini ditutup.
      SaveSuccessCheck.show(context, label: _isEdit ? 'Perubahan tersimpan' : 'Laporan tersimpan');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _localMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            e is ScopeViolationException ? e.message : 'Gagal menyimpan laporan.',
          ),
        ),
      );
    }
  }
}
