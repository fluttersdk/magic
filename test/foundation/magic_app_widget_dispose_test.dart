import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// A vault whose theme read waits for [gate], so a test can unmount the app
/// while its initializer is still awaiting that read.
class _HeldThemeVault extends FakeVaultService {
  _HeldThemeVault(this.gate);

  final Completer<void> gate;

  @override
  Future<String?> get(String key) async {
    await gate.future;

    return super.get(key);
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    Translator.reset();
  });

  testWidgets('an app unmounted while it initializes wires nothing after it', (
    tester,
  ) async {
    // The initializer awaits the saved theme before it calls `onInit` and
    // wires the title. An app removed from the tree in that window used to
    // carry on regardless, registering routes and listeners for a widget that
    // no longer existed.
    final gate = Completer<void>();
    Magic.app.setInstance('vault', _HeldThemeVault(gate));
    var onInitCalls = 0;

    await tester.pumpWidget(
      MagicApplication(
        title: 'App',
        onInit: () {
          onInitCalls++;
          MagicRoute.page('/', () => const SizedBox());
        },
      ),
    );

    await tester.pumpWidget(const SizedBox());
    gate.complete();
    await tester.pumpAndSettle();

    expect(onInitCalls, 0);
    expect(tester.takeException(), isNull);
  });
}
