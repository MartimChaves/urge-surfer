import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'appDatabaseProvider must be overridden in main() (or in tests).',
  );
});

final seedModuleIdProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final existing = await db.moduleDao.getAllActive();
  if (existing.isNotEmpty) return existing.first.id;
  return db.moduleDao.insertModule(
    ModulesCompanion.insert(
      name: 'betting',
      moneyTracked: false,
      phraseSet: 'general',
      createdAt: DateTime.now(),
    ),
  );
});

final waveTotalCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  return db.waveDao.totalCount();
});
