import 'package:koma/core/isar/isar.dart';
import 'package:koma/core/repositories/repositories.dart';

Future<Repositories> createTestRepositories() async {
  final isar = await openIsarInMemory();
  return Repositories(isar);
}
