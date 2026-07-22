import 'package:drift/native.dart';
import 'package:koma/core/database/database.dart';

Future<AppDatabase> createTestDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  await db.customSelect('SELECT 1').get();
  return db;
}
