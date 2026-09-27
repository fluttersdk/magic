import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Pins that every public type Steps 2-9 added (session scope, the data
/// layer, actions, form objects, the timing/url support seam, broadcast
/// listeners, the event breadcrumb contract, and the fuller validation
/// rules) reaches a consumer through `package:magic/magic.dart` alone, the
/// same contract `test/support/exports_test.dart` pins for the surface added
/// before this plan. Each type is referenced once; the behaviour each one
/// implements already has its own test file next to its source.
class _Row extends Model {
  @override
  String get table => 'barrel_rows';

  @override
  String get resource => 'barrel_rows';

  @override
  List<String> get fillable => const <String>['id', 'name'];
}

class _RowRepository extends Repository<_Row> {
  @override
  String get resource => 'barrel_rows';

  @override
  _Row Function(Map<String, dynamic>) get fromMap =>
      (Map<String, dynamic> map) => _Row()
        ..fill(map)
        ..exists = true;
}

class _PauseRow extends MagicAction<String, void> {
  const _PauseRow();

  @override
  Future<void> handle(String input) async {}
}

class _BarrelController extends MagicController
    with RunsActions, OwnsTimers, ListensToBroadcasts {
  @override
  Map<String, void Function(BroadcastEvent)> get listeners =>
      const <String, void Function(BroadcastEvent)>{};
}

class _NoopRequest extends FormRequest {
  const _NoopRequest();

  @override
  Map<String, List<Rule>> rules() => const <String, List<Rule>>{};
}

class _BarrelForm extends MagicFormObject {
  @override
  Map<String, dynamic> get initial => const <String, dynamic>{'name': ''};

  @override
  FormRequest get request => const _NoopRequest();

  @override
  Future<bool> persist(Map<String, dynamic> validated) async => true;
}

class _AuditedEvent extends MagicEvent implements ReportsBreadcrumb {
  @override
  String get breadcrumbCategory => 'test';

  @override
  String get breadcrumbMessage => 'test event';

  @override
  Map<String, Object?> get breadcrumbData => const <String, Object?>{};
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    if (SessionScope.isAttached) SessionScope.detach();
  });

  test('SessionScope and SessionScoped resolve through the public barrel', () {
    expect(SessionScope.isAttached, isFalse);
    expect(_RowRepository(), isA<SessionScoped>());
  });

  test('Repository and RepositoryQuery resolve through the public barrel', () {
    final _RowRepository repository = _RowRepository();
    final RepositoryQuery<_Row> query = RepositoryQuery<_Row>(
      repository: repository,
    );

    expect(query.items, isEmpty);
    query.dispose();
  });

  test('MagicAction and RunsActions resolve through the public barrel', () {
    expect(const _PauseRow(), isNotNull);
    expect(_BarrelController(), isA<RunsActions>());
  });

  test(
    'ActionOutcome and its three cases resolve through the public barrel',
    () async {
      final _BarrelController controller = _BarrelController();

      final ActionOutcome<void> outcome = await controller.runAction(
        const _PauseRow(),
        'row-1',
      );

      expect(outcome, isA<ActionSucceeded<void>>());
      expect(outcome.succeeded, isTrue);
      expect(const ActionFailed<void>('boom'), isA<ActionOutcome<void>>());
      expect(const ActionRefused<void>(), isA<ActionOutcome<void>>());
    },
  );

  test('MagicFormObject resolves through the public barrel', () {
    final _BarrelForm form = _BarrelForm();

    expect(form.data, isNotNull);
    form.dispose();
  });

  test('LatestRead, Poll, Countdown, Debouncer and OwnsTimers resolve through '
      'the public barrel', () async {
    expect(LatestRead(), isNotNull);
    expect(Countdown(), isNotNull);
    expect(Debouncer(), isNotNull);
    expect(_BarrelController(), isA<OwnsTimers>());

    final PollHandle<int> handle = Poll.until<int>(
      read: () async => 1,
      done: (int value) => true,
      every: Duration.zero,
      maxAttempts: 1,
    );
    final PollOutcome<int> outcome = await handle.result;

    expect(outcome, isA<PollSettled<int>>());
  });

  test('BroadcastListeners and ListensToBroadcasts resolve through the public '
      'barrel', () {
    expect(_BarrelController(), isA<ListensToBroadcasts>());

    BroadcastListeners.channel('barrel', () => null);
    final BroadcastListenerToken token = BroadcastListeners.add(
      'barrel',
      'event',
      (_) {},
    );
    BroadcastListeners.remove(token);
    BroadcastListeners.reset();
  });

  test('UrlGenerator and url() resolve through the public barrel', () {
    expect(UrlGenerator.originKey, 'app.url');
    expect(url('/terms'), isA<String>());
  });

  test('ReportsBreadcrumb resolves through the public barrel', () {
    expect(_AuditedEvent(), isA<ReportsBreadcrumb>());
  });

  test('the new validation rules resolve through the public barrel', () {
    final List<Rule> rules = <Rule>[
      const Uuid(),
      const Boolean(),
      const Numeric(),
      const Integer(),
      Gt(1),
      Gte(1),
      Lt(1),
      Lte(1),
      Between(1, 2),
      Regex(r'^a$'),
      const Date(),
      const Nullable(),
      RequiredIf('other', 'value'),
      const ArrayRule(),
    ];

    expect(rules, hasLength(14));
  });
}
