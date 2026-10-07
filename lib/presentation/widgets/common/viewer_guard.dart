import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';

/// Akun Pengawas (read-only) tidak boleh membuka form tambah/ubah. Mengembalikan true (dan
/// menampilkan pesan singkat) kalau akun yang login adalah Pengawas, sehingga pemanggil harus
/// berhenti. Server (Firestore Rules) dan provider tetap menolak tulis sebagai lapis berikutnya.
bool blockIfViewer(BuildContext context) {
  final scope = context.read<AuthProvider>().scope;
  if (scope?.isViewer ?? false) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Akun Pengawas hanya bisa melihat data.')),
    );
    return true;
  }
  return false;
}
