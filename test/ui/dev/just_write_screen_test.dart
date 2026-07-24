import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urge_surfer/domain/phrases.dart';
import 'package:urge_surfer/ui/dev/just_write_screen.dart';
import 'package:urge_surfer/ui/ritual/widgets/drawing_canvas.dart';

void main() {
  testWidgets('tracing canvas fits a compact phone viewport', (tester) async {
    tester.view.physicalSize = const Size(300, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: JustWriteScreen()));
    await tester.tap(find.text(selfCompassionPhrases.first));
    await tester.pump();

    final canvasSize = tester.getSize(find.byType(DrawingCanvas));
    expect(canvasSize.width, 300);
    expect(canvasSize.height, 300);
    expect(tester.takeException(), isNull);
  });
}
