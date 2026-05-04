import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';

class LedgerScreen extends ConsumerWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Force the seed to run at startup so the ritual flow has a module ready.
    ref.watch(seedModuleIdProvider);
    final totalAsync = ref.watch(waveTotalCountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Urge Surfer')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            totalAsync.when(
              data: (count) => Column(
                children: [
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    count == 1 ? 'wave surfed' : 'waves surfed',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () async {
                await context.push('/ritual');
                ref.invalidate(waveTotalCountProvider);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text('Start a wave'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
