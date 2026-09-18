import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  group('FakeNetworkDriver with an asynchronous stub', () {
    test('awaits a handler that returns a Future', () async {
      final driver = FakeNetworkDriver(
        stubs: (MagicRequest request) async {
          await Future<void>.delayed(Duration.zero);
          return MagicResponse(data: {'ok': true}, statusCode: 200);
        },
      );

      final response = await driver.get('/ping');

      expect(response.statusCode, 200);
      expect(response.data, {'ok': true});
    });

    test('a synchronous handler still works unchanged', () async {
      // The widening is source-compatible: every stub written against the old
      // `MagicResponse Function(MagicRequest)` keeps compiling and keeps
      // behaving, which is what makes this additive rather than breaking.
      final driver = FakeNetworkDriver(
        stubs: (MagicRequest request) =>
            MagicResponse(data: {'ok': true}, statusCode: 201),
      );

      expect((await driver.get('/ping')).statusCode, 201);
    });

    test(
      'a handler can hold a request in flight while the caller acts',
      () async {
        // This is the capability the sync-only typedef made impossible, and the
        // reason for the change. A concurrency test needs a window in which a
        // request is outstanding: "a sign-out arrives while the panel handshake
        // is still in the air" cannot be scripted at all when every stub answers
        // before returning.
        final gate = Completer<void>();
        var released = false;

        final driver = FakeNetworkDriver(
          stubs: (MagicRequest request) async {
            await gate.future;
            return MagicResponse(data: {'released': released}, statusCode: 200);
          },
        );

        final inFlight = driver.get('/slow');

        // The request is outstanding here, which is the whole point: the caller
        // gets to change the world before the response lands.
        released = true;
        gate.complete();

        expect((await inFlight).data, {'released': true});
      },
    );

    test('records the awaited response, not the Future', () async {
      final driver = FakeNetworkDriver(
        stubs: (MagicRequest request) async =>
            MagicResponse(data: {'n': 1}, statusCode: 200),
      );

      await driver.get('/ping');

      expect(driver.recorded, hasLength(1));
      expect(driver.recorded.single.$2.data, {'n': 1});
    });
  });
}
