import '../local_seed/local_seed_data.dart';
import '../models/student.dart';
import 'student_repository.dart';

class LocalStudentRepository implements StudentRepository {
  List<Student>? _cache;

  @override
  Future<List<Student>> getAll() async {
    return _cache ??= kSeedStudentsJson.map(Student.fromJson).toList();
  }
}
