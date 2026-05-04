import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:urge_surfer/data/db/database.dart';

void main() {
  late AppDatabase db;
  late int bettingId;
  late int scrollingId;

  final t0 = DateTime(2026, 1, 1, 12, 0);

  setUp(() async {
    db = AppDatabase.openInMemory();
    bettingId = await db.moduleDao.insertModule(
      ModulesCompanion.insert(
        name: 'betting',
        moneyTracked: true,
        phraseSet: 'betting',
        createdAt: t0,
      ),
    );
    scrollingId = await db.moduleDao.insertModule(
      ModulesCompanion.insert(
        name: 'Instagram',
        moneyTracked: false,
        phraseSet: 'scrolling',
        createdAt: t0,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('WaveDao', () {
    test('insert + getAllByModule returns the inserted wave', () async {
      await db.waveDao.insertWave(
        WavesCompanion.insert(
          moduleId: bettingId,
          urgeText: r'place a $200 bet',
          urgeBefore: 8,
          urgeAfter: 4,
          amount: const Value(20000),
          createdAt: t0,
        ),
      );
      final waves = await db.waveDao.getAllByModule(bettingId);
      expect(waves, hasLength(1));
      expect(waves.first.urgeText, r'place a $200 bet');
      expect(waves.first.amount, 20000);
      expect(waves.first.urgeBefore, 8);
      expect(waves.first.urgeAfter, 4);
    });

    test('totalCount counts across all modules', () async {
      await _insertWave(db, bettingId, at: t0);
      await _insertWave(db, bettingId, at: t0);
      await _insertWave(db, scrollingId, at: t0);
      expect(await db.waveDao.totalCount(), 3);
    });

    test('totalCount is zero on an empty DB', () async {
      expect(await db.waveDao.totalCount(), 0);
    });

    test('totalCountByModule isolates per module', () async {
      await _insertWave(db, bettingId, at: t0);
      await _insertWave(db, bettingId, at: t0);
      await _insertWave(db, scrollingId, at: t0);
      expect(await db.waveDao.totalCountByModule(bettingId), 2);
      expect(await db.waveDao.totalCountByModule(scrollingId), 1);
    });

    test('sumAmountByModule ignores null amounts', () async {
      await _insertWave(db, bettingId, at: t0, amount: 5000);
      await _insertWave(db, bettingId, at: t0, amount: 3000);
      await _insertWave(db, bettingId, at: t0, amount: null);
      expect(await db.waveDao.sumAmountByModule(bettingId), 8000);
    });

    test('sumAmountByModule returns 0 when no waves', () async {
      expect(await db.waveDao.sumAmountByModule(bettingId), 0);
    });

    test('cross-module query isolation', () async {
      await _insertWave(db, bettingId, at: t0);
      final scrollingWaves = await db.waveDao.getAllByModule(scrollingId);
      expect(scrollingWaves, isEmpty);
    });

    test('getAllByModule returns newest first', () async {
      await _insertWave(
        db,
        bettingId,
        at: t0,
        urgeText: 'first',
      );
      await _insertWave(
        db,
        bettingId,
        at: t0.add(const Duration(minutes: 5)),
        urgeText: 'second',
      );
      await _insertWave(
        db,
        bettingId,
        at: t0.add(const Duration(minutes: 1)),
        urgeText: 'middle',
      );
      final waves = await db.waveDao.getAllByModule(bettingId);
      expect(waves.map((w) => w.urgeText).toList(), [
        'second',
        'middle',
        'first',
      ]);
    });
  });
}

Future<int> _insertWave(
  AppDatabase db,
  int moduleId, {
  required DateTime at,
  int? amount,
  String urgeText = 'test urge',
}) {
  return db.waveDao.insertWave(
    WavesCompanion.insert(
      moduleId: moduleId,
      urgeText: urgeText,
      urgeBefore: 7,
      urgeAfter: 3,
      amount: amount != null ? Value(amount) : const Value.absent(),
      createdAt: at,
    ),
  );
}
