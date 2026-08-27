import 'package:flutter/widgets.dart';

/// Fallback aman kalau di-compile buat target yang bukan dart:io atau
/// dart:html — selalu null (pemanggil jatuh ke fallback inisial nama),
/// bukan crash.
ImageProvider? resolveAvatarImage(String? photoPath) => null;
