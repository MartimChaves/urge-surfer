import 'package:drift/drift.dart';

class Modules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  BoolColumn get moneyTracked => boolean()();
  IntColumn get defaultAmount => integer().nullable()();
  TextColumn get phraseSet => text()();
  IntColumn get goalCount => integer().nullable()();
  IntColumn get goalAmount => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
}

class Waves extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get moduleId =>
      integer().references(Modules, #id)();
  TextColumn get urgeText => text()();
  IntColumn get urgeBefore => integer()();
  IntColumn get urgeAfter => integer()();
  IntColumn get amount => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class Intentions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get moduleId =>
      integer().references(Modules, #id)();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();
}

class WeeklyCheckins extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get promptKey => text()();
  TextColumn get responseText => text()();
  DateTimeColumn get createdAt => dateTime()();
}
