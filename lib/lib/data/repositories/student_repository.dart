import '../models/student.dart';

/// Abstraction sumber data master santri. [LocalStudentRepository] saat
/// ini baca dari seed lokal; nanti tinggal diganti `ApiStudentRepository`.
abstract class StudentRepository {
  Future<List<Student>> getAll();
}
