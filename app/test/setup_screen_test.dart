import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote_core/tv_remote_core.dart';
import 'package:tv_voice_remote/controller.dart';
import 'package:tv_voice_remote/setup_screen.dart';
import 'package:tv_voice_remote/store.dart';

class _EmptyStore extends Store {
  @override
  Future<Identity?> loadIdentity() async => null;
  @override
  Future<String?> loadHost() async => null;
  @override
  Future<String?> loadTvName() async => null;
  @override
  Future<List<AppEntry>> loadApps() async => const [];
  @override
  Future<List<AppEntry>> loadCatalog() async => const [];
}

void main() {
  testWidgets('the TV address box has a dot key (decimal pad) and turns a comma into a dot', (tester) async {
    // On iPhone the plain number pad has no dot, so an IP address could not be typed (found in TestFlight).
    final c = TvController(_EmptyStore());
    await tester.pumpWidget(MaterialApp(home: SetupScreen(controller: c)));

    final field = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == '192.168.1.20');
    expect(field, findsOneWidget);
    expect(tester.widget<TextField>(field).keyboardType, const TextInputType.numberWithOptions(decimal: true));

    await tester.enterText(field, '192,168,1,12');
    expect(tester.widget<TextField>(field).controller!.text, '192.168.1.12');
    c.dispose();
  });
}
