import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/db/database.dart';
import '../../domain/drawing/glyphs/word_composer.dart';
import 'widgets/drawing_canvas.dart';

const String _phrase = 'I can be gentle.';

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
  int _wordIndex = 0;

  late final List<String> _words = _phrase
      .split(' ')
      .where((w) => w.isNotEmpty)
      .toList();

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

  void _onWordComplete() {
    if (_wordIndex < _words.length - 1) {
      setState(() => _wordIndex++);
    } else {
      _advance();
    }
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
                wordIndex: _wordIndex,
                words: _words,
                onWordComplete: _onWordComplete,
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
  final int wordIndex;
  final List<String> words;
  final VoidCallback onWordComplete;
  const _DrawingStep({
    required this.phrase,
    required this.wordIndex,
    required this.words,
    required this.onWordComplete,
  });

  @override
  Widget build(BuildContext context) {
    final word = words[wordIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(phrase, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Word ${wordIndex + 1} of ${words.length}: "$word"',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const Spacer(),
        DrawingCanvas(
          key: ValueKey(wordIndex),
          word: composeWord(word),
          onLetterComplete: onWordComplete,
        ),
        const Spacer(),
      ],
    );
  }
}
