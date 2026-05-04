import 'package:drift/drift.dart';

import 'database.dart';
import 'tables.dart';

part 'module_dao.g.dart';

@DriftAccessor(tables: [Modules])
class ModuleDao extends DatabaseAccessor<AppDatabase> with _$ModuleDaoMixin {
  ModuleDao(super.db);

  Future<int> insertModule(ModulesCompanion m) => into(modules).insert(m);

  Future<List<Module>> getAllActive() =>
      (select(modules)..where((m) => m.archivedAt.isNull())).get();
}
