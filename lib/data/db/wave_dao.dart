import 'package:drift/drift.dart';

import 'database.dart';
import 'tables.dart';

part 'wave_dao.g.dart';

@DriftAccessor(tables: [Waves])
class WaveDao extends DatabaseAccessor<AppDatabase> with _$WaveDaoMixin {
  WaveDao(super.db);

  Future<int> insertWave(WavesCompanion w) => into(waves).insert(w);

  Future<List<Wave>> getAllByModule(int moduleId) =>
      (select(waves)
            ..where((w) => w.moduleId.equals(moduleId))
            ..orderBy([
              (w) => OrderingTerm(
                    expression: w.createdAt,
                    mode: OrderingMode.desc,
                  ),
            ]))
          .get();

  Future<int> totalCount() async {
    final count = countAll();
    final query = selectOnly(waves)..addColumns([count]);
    return (await query.map((row) => row.read(count)).getSingle()) ?? 0;
  }

  Future<int> totalCountByModule(int moduleId) async {
    final count = countAll();
    final query = selectOnly(waves)
      ..addColumns([count])
      ..where(waves.moduleId.equals(moduleId));
    return (await query.map((row) => row.read(count)).getSingle()) ?? 0;
  }

  Future<int> sumAmountByModule(int moduleId) async {
    final sum = waves.amount.sum();
    final query = selectOnly(waves)
      ..addColumns([sum])
      ..where(waves.moduleId.equals(moduleId));
    final result =
        await query.map((row) => row.read(sum)).getSingleOrNull();
    return result ?? 0;
  }
}
