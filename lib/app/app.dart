import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/dev/just_write_screen.dart';
import '../ui/ledger/ledger_screen.dart';
import '../ui/ritual/ritual_flow_screen.dart';

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LedgerScreen(),
    ),
    GoRoute(
      path: '/ritual',
      builder: (context, state) => const RitualFlowScreen(),
    ),
    GoRoute(
      path: '/just-write',
      builder: (context, state) => const JustWriteScreen(),
    ),
  ],
);

class UrgeSurferApp extends StatelessWidget {
  const UrgeSurferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Urge Surfer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
