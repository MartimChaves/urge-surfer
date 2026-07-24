import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/drawing/glyphs/word_composer.dart';
import '../../domain/phrases.dart';
import '../ritual/widgets/drawing_canvas.dart';

/// Fast feedback loop for trying out phrases and tuning glyphs. Pick a phrase
/// → draw it → on completion bounce back to the picker. No urge naming, no
/// sliders, no logging.
class JustWriteScreen extends StatefulWidget {
  const JustWriteScreen({super.key});

  @override
  State<JustWriteScreen> createState() => _JustWriteScreenState();
}

class _JustWriteScreenState extends State<JustWriteScreen> {
  String? _phrase;
  ComposedPath? _composed;
  bool _lagEnabled = true;

  void _pick(String phrase) {
    setState(() {
      _phrase = phrase;
      _composed = composePhrase(phrase);
    });
  }

  void _backToPicker() {
    setState(() {
      _phrase = null;
      _composed = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inDrawing = _phrase != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(inDrawing ? _phrase! : 'Just write'),
        leading: inDrawing
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _backToPicker,
              )
            : null,
      ),
      body: SafeArea(
        child: inDrawing ? _drawingArea(context) : _picker(context),
      ),
    );
  }

  Widget _picker(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: selfCompassionPhrases.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final phrase = selfCompassionPhrases[i];
        return ListTile(
          title: Text(phrase, style: Theme.of(context).textTheme.titleMedium),
          onTap: () => _pick(phrase),
        );
      },
    );
  }

  Widget _drawingArea(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Spacer(),
        LayoutBuilder(
          builder: (context, constraints) {
            final canvasSize = math.min(
              maximumTracingCanvasSize,
              constraints.maxWidth,
            );
            return DrawingCanvas(
              path: _composed!,
              onLetterComplete: _backToPicker,
              width: canvasSize,
              height: canvasSize,
              lagEnabled: _lagEnabled,
            );
          },
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('pen lag', style: Theme.of(context).textTheme.bodySmall),
            Switch(
              value: _lagEnabled,
              onChanged: (v) => setState(() => _lagEnabled = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
