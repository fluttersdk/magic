import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Pins that the new Support surface (Number, Str, Cast, Arr), the two UI
/// mixins (RefetchesOnMount, SubmitsOnce), CollapsesIndexedErrorKeys,
/// Env.filled, Carbon.shortDiffForHumans, the sync skeleton (SyncFeed,
/// SyncLedger, CreateSyncCursorsTable), Str.ascii/squish, and AppLifecycle
/// all reach a consumer through `package:magic/magic.dart` alone, not only
/// through `package:magic/src/...`.
void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  test('Number, Str, Cast, Arr resolve through the public barrel', () {
    expect(Number.format(1234, locale: 'en'), '1,234');
    expect(Str.upper('istanbul', locale: 'en'), 'ISTANBUL');
    expect(Cast.intOr('3', 0), 3);
    expect(Arr.get(<String, dynamic>{'a': 1}, 'a'), 1);
  });

  test('RefetchesOnMount and SubmitsOnce mixins are exported', () {
    expect(RefetchesOnMount, isNotNull);
    expect(SubmitsOnce, isNotNull);
  });

  test('CollapsesIndexedErrorKeys is exported alongside ValidatesRequests', () {
    expect(CollapsesIndexedErrorKeys, isNotNull);
  });

  test('AuthChannelSubscription resolves through the public barrel', () {
    final subscription = AuthChannelSubscription(
      channelName: () => null,
      listeners: const {},
    );

    expect(subscription, isNotNull);
  });

  test('Env.filled resolves an absent key to the fallback', () {
    expect(Env.filled('MISSING_EXPORTS_TEST_KEY', 'fallback'), 'fallback');
  });

  test('Carbon.shortDiffForHumans measures against an explicit other', () {
    final reference = Carbon.create(year: 2024, month: 3, day: 15, hour: 10);
    final event = reference.subMinutes(14);

    expect(event.shortDiffForHumans(reference), '14m ago');
  });

  test(
    'SyncFeed, SyncLedger, CreateSyncCursorsTable resolve through the public barrel',
    () {
      expect(SyncFeed, isNotNull);
      expect(const SyncLedger(), isNotNull);
      expect(CreateSyncCursorsTable(), isNotNull);

      final report = SyncReport(pushed: 1, adopted: 2);
      expect(report.complete, isTrue);
    },
  );

  test('Str.ascii and Str.squish resolve through the public barrel', () {
    expect(Str.ascii('çalışan'), 'calisan');
    expect(Str.squish('  a   b  '), 'a b');
  });

  test('AppLifecycle.states resolves through the public barrel', () {
    expect(AppLifecycle.states(), isNotNull);
  });
}
