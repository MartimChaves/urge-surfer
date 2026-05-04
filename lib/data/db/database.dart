import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as raw_sqlite;

import '../secure/db_key.dart';
import 'module_dao.dart';
import 'tables.dart';
import 'wave_dao.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Modules, Waves, Intentions, WeeklyCheckins],
  daos: [ModuleDao, WaveDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.openInMemory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  static AppDatabase open() => AppDatabase(_openOnDisk());
}

LazyDatabase _openOnDisk() => LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'urge_surfer.db'));
      final key = await DbKeyStore.getOrCreate();
      return NativeDatabase.createInBackground(
        file,
        setup: (raw) {
          assert(_debugCheckHasCipher(raw));
          raw.execute("PRAGMA key = '$key';");
        },
      );
    });

bool _debugCheckHasCipher(raw_sqlite.Database raw) {
  return raw.select('PRAGMA cipher;').isNotEmpty;
}
