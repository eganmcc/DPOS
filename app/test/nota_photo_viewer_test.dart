import 'dart:convert';

import 'package:dpos/features/nota/nota_photo_viewer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 1x1 transparent PNG — enough for Image.memory to decode.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  late TransformationController controller;

  Future<void> pumpViewer(WidgetTester tester) async {
    controller = TransformationController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: NotaPhotoViewer(
              bytes: _png,
              controller: controller,
              hint: 'hint',
              fitLabel: 'fit',
              fullscreenLabel: 'full',
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  Future<void> doubleTap(WidgetTester tester) async {
    final at = tester.getCenter(find.byKey(const ValueKey('nota-photo-gestures')));
    await tester.tapAt(at);
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(at);
    await tester.pumpAndSettle();
  }

  double scaleOf(TransformationController c) => c.value.getMaxScaleOnAxis();

  testWidgets('starts at 1x', (tester) async {
    await pumpViewer(tester);
    expect(scaleOf(controller), closeTo(1, 0.001));
  });

  testWidgets('double-tap zooms in, and double-tap again returns to 1x', (tester) async {
    await pumpViewer(tester);

    await doubleTap(tester);
    expect(scaleOf(controller), closeTo(NotaPhotoViewer.doubleTapScale, 0.001));

    await doubleTap(tester);
    expect(scaleOf(controller), closeTo(1, 0.001));
  });

  testWidgets('once zoomed, a sideways drag pans the photo', (tester) async {
    await pumpViewer(tester);
    await doubleTap(tester);
    final before = controller.value.getTranslation().x;

    await tester.drag(
      find.byKey(const ValueKey('nota-photo-gestures')),
      const Offset(-80, 0),
    );
    await tester.pumpAndSettle();

    expect(controller.value.getTranslation().x, lessThan(before));
  });

  testWidgets('the fit button resets any zoom', (tester) async {
    await pumpViewer(tester);
    await doubleTap(tester);
    expect(scaleOf(controller), greaterThan(1));

    await tester.tap(find.byIcon(Icons.fit_screen_outlined));
    await tester.pumpAndSettle();
    expect(scaleOf(controller), closeTo(1, 0.001));
  });
}
