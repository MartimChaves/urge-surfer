import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/db/database.dart';
import '../../domain/drawing/glyphs/word_composer.dart';
import 'widgets/drawing_canvas.dart';

const String _phrase = 'i can be gentle.';

enum _Step { nameUrge, preSlider, drawing, postSlider }

class RitualFlowScreen extends ConsumerStatefulWidget {
  const RitualFlowScreen({super.key});

  @override
  ConsumerState<RitualFlowScreen> createState() => _RitualFlowScreenState();
}

class _RitualFlowScreenState extends ConsumerState<RitualFlowScreen> {
  _Step _step = _Step.nameUrge;
  final _urgeController = TextEditingController();
  int _urgeBefore = 5;
  int _urgeAfter = 5;

  late final ComposedPath _composedPhrase = composePhrase(_phrase);

  @override
  void dispose() {
    _urgeController.dispose();
    super.dispose();
  }

  void _advance() {
    setState(() {
      _step = _Step.values[_step.index + 1];
    });
  }

  Future<void> _logAndExit() async {
    final db = ref.read(appDatabaseProvider);
    final moduleId = await ref.read(seedModuleIdProvider.future);
    await db.waveDao.insertWave(
      WavesCompanion.insert(
        moduleId: moduleId,
        urgeText: _urgeController.text.trim(),
        urgeBefore: _urgeBefore,
        urgeAfter: _urgeAfter,
        createdAt: DateTime.now(),
      ),
    );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (_step) {
            _Step.nameUrge => _NameUrgeStep(
                controller: _urgeController,
                onNext: () {
                  if (_urgeController.text.trim().isNotEmpty) _advance();
                },
              ),
            _Step.preSlider => _SliderStep(
                question: 'How strong is the urge right now?',
                value: _urgeBefore,
                onChanged: (v) => setState(() => _urgeBefore = v),
                onNext: _advance,
              ),
            _Step.drawing => _DrawingStep(
                phrase: _phrase,
                composedPhrase: _composedPhrase,
                onComplete: _advance,
              ),
            _Step.postSlider => _SliderStep(
                question: 'How strong is the urge now?',
                value: _urgeAfter,
                onChanged: (v) => setState(() => _urgeAfter = v),
                onNext: _logAndExit,
                nextLabel: 'Log wave',
              ),
          },
        ),
      ),
    );
  }
}

class _NameUrgeStep extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onNext;
  const _NameUrgeStep({required this.controller, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'What do you want to do right now?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          maxLines: 3,
        ),
        const Spacer(),
        FilledButton(
          onPressed: onNext,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Next'),
          ),
        ),
      ],
    );
  }
}

class _SliderStep extends StatelessWidget {
  final String question;
  final int value;
  final ValueChanged<int> onChanged;
  final VoidCallback onNext;
  final String nextLabel;
  const _SliderStep({
    required this.question,
    required this.value,
    required this.onChanged,
    required this.onNext,
    this.nextLabel = 'Next',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(question, style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        Center(
          child: Text(
            '$value',
            style: Theme.of(context).textTheme.displayLarge,
          ),
        ),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          label: value.toString(),
          onChanged: (v) => onChanged(v.round()),
        ),
        const Spacer(),
        FilledButton(
          onPressed: onNext,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(nextLabel),
          ),
        ),
      ],
    );
  }
}

class _DrawingStep extends StatelessWidget {
  final String phrase;
  final ComposedPath composedPhrase;
  final VoidCallback onComplete;
  const _DrawingStep({
    required this.phrase,
    required this.composedPhrase,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(phrase, style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        DrawingCanvas(
          path: composedPhrase,
          onLetterComplete: onComplete,
        ),
        const Spacer(),
      ],
    );
  }
}
