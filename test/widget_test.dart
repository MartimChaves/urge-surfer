import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:urge_surfer/app/providers.dart';
import 'package:urge_surfer/data/db/database.dart';
import 'package:urge_surfer/ui/ledger/ledger_screen.dart';

Widget _harness(AppDatabase db) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const LedgerScreen(),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('LedgerScreen shows zero waves on a fresh in-memory DB',
      (tester) async {
    final db = AppDatabase.openInMemory();
    addTearDown(db.close);

    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();

    expect(find.text('0'), findsOneWidget);
    expect(find.text('waves surfed'), findsOneWidget);
  });

  testWidgets('LedgerScreen pluralizes correctly with one wave', (tester) async {
    final db = AppDatabase.openInMemory();
    addTearDown(db.close);

    final moduleId = await db.moduleDao.insertModule(
      ModulesCompanion.insert(
        name: 'betting',
        moneyTracked: false,
        phraseSet: 'general',
        createdAt: DateTime.now(),
      ),
    );
    await db.waveDao.insertWave(
      WavesCompanion.insert(
        moduleId: moduleId,
        urgeText: 'test',
        urgeBefore: 7,
        urgeAfter: 3,
        createdAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('wave surfed'), findsOneWidget);
  });
}
