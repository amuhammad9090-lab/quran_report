import '../local_seed/local_seed_data.dart';
import '../models/school.dart';

/// Abstraction sumber data sekolah. [LocalSchoolRepository] baca dari
/// seed lokal; nanti tinggal diganti `ApiSchoolRepository`.
abstract class SchoolRepository {
  Future<School?> findById(String id);
  Future<List<School>> getAll();
}

class LocalSchoolRepository implements SchoolRepository {
  List<School>? _cache;

  List<School> _schools() => _cache ??= kSeedSchoolsJson.map(School.fromJson).toList();

  @override
  Future<School?> findById(String id) async {
    for (final s in _schools()) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Future<List<School>> getAll() async => _schools();
}
