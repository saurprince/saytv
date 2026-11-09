import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_voice_remote/layout.dart';

Future<double> _padding(WidgetTester tester, Size size, {double min = 16}) async {
  late double result;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Builder(builder: (context) {
      result = sidePadding(context, min: min);
      return const SizedBox();
    }),
  ));
  return result;
}

void main() {
  testWidgets('a phone uses the whole width (just the minimum padding)', (tester) async {
    expect(await _padding(tester, const Size(390, 844)), 16);
    expect(await _padding(tester, const Size(390, 844), min: 8), 8);
    expect(await _padding(tester, const Size(615, 900)), 16); // still narrower than the column plus padding
  });

  testWidgets('a tablet keeps the content in a centred column no wider than the maximum', (tester) async {
    // iPad 13" in portrait is 1032 points wide: 600 of content, the rest split to both sides
    final p = await _padding(tester, const Size(1032, 1376));
    expect(p, (1032 - maxContentWidth) / 2);
    expect(1032 - 2 * p, maxContentWidth);
    // landscape iPad / large Android tablet
    expect(1366 - 2 * await _padding(tester, const Size(1366, 1024)), maxContentWidth);
  });
}
