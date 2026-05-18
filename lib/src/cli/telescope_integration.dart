import 'package:flutter/foundation.dart';
import 'package:fluttersdk_telescope/telescope.dart';

import '../auth/events/auth_events.dart';
import '../auth/events/gate_events.dart';
import '../database/eloquent/model.dart';
import '../database/events/db_events.dart';
import '../database/events/model_events.dart';
import '../events/event_dispatcher.dart';
import '../events/magic_event.dart';
import '../events/magic_listener.dart';
import '../foundation/magic.dart';
import '../network/contracts/magic_network_interceptor.dart';
import '../network/contracts/network_driver.dart';
import '../network/magic_response.dart';

/// Glues magic's Http / Model / Cache facades into the fluttersdk_telescope
/// store.
///
/// Host integration (debug-only):
/// ```dart
/// if (kDebugMode) {
///   TelescopePlugin.install();
///   MagicTelescopeIntegration.install();
/// }
/// ```
///
/// Registers five units with [TelescopePlugin]:
/// 1. [MagicHttpFacadeAdapter] ; wraps Magic's `network` driver with a
///    [MagicNetworkInterceptor] that feeds [TelescopeStore.recordHttp]
///    (oracle's reuse-pattern decision kept inside magic).
/// 2. [MagicModelWatcher] ; subscribes to `ModelCreated`, `ModelSaved`,
///    `ModelDeleted` and feeds [TelescopeStore.recordMagicModel].
/// 3. [MagicCacheWatcher] ; placeholder; magic's Cache facade does not
///    currently emit lifecycle events. V1.x will land cache events
///    upstream in magic's Cache layer; this watcher's [install] is a
///    no-op for now (kept registered so the V1.x event wiring is a
///    one-file change).
/// 4. [MagicEventWatcher] ; subscribes to the curated set of magic auth /
///    db / gate-definition events (alpha-2 scope) and feeds
///    [TelescopeStore.recordEvent] with an empty payload. Per-event field
///    extraction is deferred to a follow-up alpha.
/// 5. [MagicGateWatcher] ; subscribes to `GateAccessChecked` and feeds
///    [TelescopeStore.recordGate] with the canonical gate result shape
///    (single dynamic `arguments` wrapped into `List<Object?>`, user id
///    stringified).
///
/// The five integration classes below are exposed for testing but are
/// NOT re-exported from `package:magic/magic.dart` ; only
/// [MagicTelescopeIntegration.install] is the documented public entry.
class MagicTelescopeIntegration {
  MagicTelescopeIntegration._();

  /// Idempotent install. Safe to call multiple times within the same
  /// isolate lifetime.
  static void install() {
    if (_installed) return;
    _installed = true;
    TelescopePlugin.registerHttpAdapter(MagicHttpFacadeAdapter());
    TelescopePlugin.registerWatcher(MagicModelWatcher());
    TelescopePlugin.registerWatcher(MagicCacheWatcher());
    TelescopePlugin.registerWatcher(MagicEventWatcher());
    TelescopePlugin.registerWatcher(MagicGateWatcher());
  }

  /// Whether [install] has been called at least once.
  @visibleForTesting
  static bool get isInstalled => _installed;

  /// Test-only reset. Drops the idempotency guard.
  ///
  /// Does NOT unregister the adapters/watchers ; TelescopePlugin keeps
  /// them in its internal lists; tests should call
  /// [TelescopeStore.resetForTesting] to clear the buffers and rely on
  /// per-test setUp to construct fresh integration instances.
  @visibleForTesting
  static void resetForTesting() {
    _installed = false;
  }

  static bool _installed = false;
}

// ---------------------------------------------------------------------------
// HTTP adapter ; wraps Magic's network driver via MagicNetworkInterceptor.
// ---------------------------------------------------------------------------

/// [TelescopeHttpAdapter] that captures every request flowing through
/// Magic's `network` driver and feeds [TelescopeStore.recordHttp].
///
/// Implementation: registers a [_TelescopeNetworkInterceptor] on the
/// driver resolved via `Magic.make<NetworkDriver>('network')`. The
/// interceptor sees every request/response/error and translates them to
/// [HttpRequestRecord] entries.
class MagicHttpFacadeAdapter implements TelescopeHttpAdapter {
  @override
  String get name => 'magic_http_facade';

  /// The interceptor instance bound at [install]. Held for [uninstall]
  /// reference symmetry; the actual `NetworkDriver` contract has no
  /// `removeInterceptor` hook (V1 limitation).
  _TelescopeNetworkInterceptor? _interceptor;

  @override
  void install() {
    if (!Magic.bound('network')) {
      // Network not yet bound (host called install too early). No-op;
      // host should call after Magic.init() completes.
      return;
    }
    final NetworkDriver driver = Magic.make<NetworkDriver>('network');
    final _TelescopeNetworkInterceptor interceptor =
        _TelescopeNetworkInterceptor();
    driver.addInterceptor(interceptor);
    _interceptor = interceptor;
  }

  @override
  void uninstall() {
    // The MagicNetworkInterceptor contract has no removal path in V1.
    // We disarm the interceptor instead ; recording becomes a no-op.
    _interceptor?._disarmed = true;
    _interceptor = null;
  }
}

/// Internal interceptor ; translates Magic network lifecycle into
/// [HttpRequestRecord] entries. Pairs request → response/error via a
/// per-request stopwatch keyed on identity.
///
/// FIFO attribution (`attributedHeuristically: true`) is used because
/// `MagicNetworkInterceptor` does not carry a correlation handle across
/// `onRequest` / `onResponse` calls ; best-effort matching by call order.
class _TelescopeNetworkInterceptor extends MagicNetworkInterceptor {
  /// Set to true by [MagicHttpFacadeAdapter.uninstall] ; drops every
  /// subsequent record.
  bool _disarmed = false;

  /// In-flight requests, FIFO. We pair onResponse/onError with the
  /// oldest pending request.
  final List<_InFlight> _pending = <_InFlight>[];

  @override
  dynamic onRequest(MagicRequest request) {
    if (_disarmed) return request;
    _pending.add(
      _InFlight(
        url: request.url,
        method: request.method,
        startedAt: DateTime.now(),
        requestHeaders: _stringHeaders(request.headers),
        requestBody: _truncate(request.data),
      ),
    );
    return request;
  }

  @override
  dynamic onResponse(MagicResponse response) {
    if (_disarmed) return response;
    _record(
      statusCode: response.statusCode,
      isError: response.failed,
      responseBody: _truncate(response.data),
    );
    return response;
  }

  @override
  dynamic onError(MagicError error) {
    if (_disarmed) return error;
    _record(
      statusCode: error.statusCode,
      isError: true,
      responseBody: error.message ?? _truncate(error.response?.data),
    );
    return error;
  }

  /// 1. Pull the oldest in-flight (FIFO best-effort).
  /// 2. Compute duration from the captured timestamp.
  /// 3. Push a HttpRequestRecord into the store.
  void _record({
    required int statusCode,
    required bool isError,
    required String? responseBody,
  }) {
    if (_pending.isEmpty) return;
    final _InFlight pending = _pending.removeAt(0);
    final int durationMs = DateTime.now()
        .difference(pending.startedAt)
        .inMilliseconds;
    TelescopeStore.recordHttp(
      HttpRequestRecord(
        url: pending.url,
        method: pending.method,
        statusCode: statusCode,
        durationMs: durationMs,
        isError: isError,
        timestamp: pending.startedAt,
        requestHeaders: pending.requestHeaders,
        requestBody: pending.requestBody,
        responseBody: responseBody,
        attributedHeuristically: true,
      ),
    );
  }
}

/// Per-request capture state, held by [_TelescopeNetworkInterceptor]
/// between `onRequest` and `onResponse`/`onError`.
class _InFlight {
  _InFlight({
    required this.url,
    required this.method,
    required this.startedAt,
    required this.requestHeaders,
    required this.requestBody,
  });

  final String url;
  final String method;
  final DateTime startedAt;
  final Map<String, String>? requestHeaders;
  final String? requestBody;
}

/// Coerce a `Map<String, dynamic>` headers map into the
/// `Map<String, String>` shape that [HttpRequestRecord] requires.
Map<String, String>? _stringHeaders(Map<String, dynamic> raw) {
  if (raw.isEmpty) return null;
  final Map<String, String> out = <String, String>{};
  for (final MapEntry<String, dynamic> entry in raw.entries) {
    out[entry.key] = entry.value?.toString() ?? '';
  }
  return out;
}

/// Render an arbitrary request/response body into the bounded string
/// [HttpRequestRecord] expects. Truncates at 8 KB to keep the ring
/// buffer affordable.
String? _truncate(Object? body) {
  if (body == null) return null;
  final String s = body is String ? body : body.toString();
  const int max = 8 * 1024;
  if (s.length <= max) return s;
  return '${s.substring(0, max)}... [truncated ${s.length - max} chars]';
}

// ---------------------------------------------------------------------------
// Model watcher ; subscribes to Magic's model lifecycle events.
// ---------------------------------------------------------------------------

/// [TelescopeWatcher] that subscribes to `ModelCreated`, `ModelSaved`,
/// `ModelDeleted` and feeds [TelescopeStore.recordMagicModel].
///
/// Registers three listener factories with [EventDispatcher] ; magic's
/// dispatcher invokes the factory once per dispatch and calls the
/// listener's `handle` method.
class MagicModelWatcher implements TelescopeWatcher {
  @override
  String get name => 'magic_model';

  bool _installed = false;

  @override
  void install() {
    if (_installed) return;
    _installed = true;
    EventDispatcher.instance.register(ModelCreated, <MagicListener Function()>[
      () => _ModelLifecycleListener('created'),
    ]);
    EventDispatcher.instance.register(ModelSaved, <MagicListener Function()>[
      () => _ModelLifecycleListener('saved'),
    ]);
    EventDispatcher.instance.register(ModelDeleted, <MagicListener Function()>[
      () => _ModelLifecycleListener('deleted'),
    ]);
  }

  @override
  void uninstall() {
    // EventDispatcher.clear() is global ; we deliberately do NOT call it
    // here to avoid wiping host-registered listeners. Tests that need a
    // clean dispatcher should call EventDispatcher.instance.clear()
    // explicitly in their setUp.
  }
}

/// Translates a [ModelEvent] into a [MagicModelRecord] and pushes it to
/// the store. Bound to a single event tag ('created'/'saved'/'deleted')
/// at construction.
class _ModelLifecycleListener extends MagicListener<ModelEvent> {
  _ModelLifecycleListener(this.eventTag);

  /// 'created' | 'saved' | 'deleted' ; matches [MagicModelRecord.event].
  final String eventTag;

  @override
  Future<void> handle(ModelEvent event) async {
    final Model model = event.model;
    final dynamic key = model.id;
    TelescopeStore.recordMagicModel(
      MagicModelRecord(
        modelClass: model.runtimeType.toString(),
        event: eventTag,
        modelKey: key == null ? '' : key.toString(),
        time: DateTime.now(),
        attributes: Map<String, dynamic>.from(model.attributes),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cache watcher ; placeholder for V1.x cache event wiring.
// ---------------------------------------------------------------------------

/// [TelescopeWatcher] for Magic's cache facade.
///
/// V1.x: magic's `Cache` facade does not emit lifecycle events today
/// (no `CacheHit`/`CacheMiss`/`CacheWritten`/`CacheForgotten` event
/// classes exist in `lib/src/cache/`). This watcher is registered as
/// part of the public surface so the V1.x upgrade ; once cache events
/// land upstream ; is a one-file change in this package: subscribe via
/// [EventDispatcher.instance.register] inside [install], identical to
/// [MagicModelWatcher].
///
/// Until then, [install] is a no-op and [TelescopeStore.recentCaches]
/// will be empty for magic cache traffic.
class MagicCacheWatcher implements TelescopeWatcher {
  @override
  String get name => 'magic_cache';

  @override
  void install() {
    // V1.x: subscribe to CacheHit/CacheMiss/CacheWritten/CacheForgotten
    // once those events ship in magic's cache layer.
  }

  @override
  void uninstall() {
    // No-op until install() wires real subscriptions.
  }
}

// ---------------------------------------------------------------------------
// Event watcher ; subscribes to the curated alpha-2 magic event set.
// ---------------------------------------------------------------------------

/// [TelescopeWatcher] for magic's app-event surface (auth, db, gate
/// definitions). Excludes model lifecycle events (owned by
/// [MagicModelWatcher]) and the gate-result event (owned by
/// [MagicGateWatcher]) to keep each record on a single channel.
///
/// ALPHA-2 SCOPE: payload is the empty map for every event type. Per-event
/// field-map extraction is deferred to a follow-up alpha so the wire
/// shape of [EventRecord] can stabilise first.
class MagicEventWatcher implements TelescopeWatcher {
  /// Per-instance guard. Second [install] call on the same watcher is a
  /// no-op ; [EventDispatcher.register] is additive (it append-and-runs
  /// every factory on every dispatch), so without the guard a single
  /// dispatch would double-record.
  bool _installed = false;

  @override
  String get name => 'magic_event';

  @override
  void install() {
    if (_installed) return;
    _installed = true;
    // 1. Auth lifecycle.
    EventDispatcher.instance.register(AuthLogin, <MagicListener Function()>[
      () => _EventToRecord<AuthLogin>('AuthLogin'),
    ]);
    EventDispatcher.instance.register(AuthLogout, <MagicListener Function()>[
      () => _EventToRecord<AuthLogout>('AuthLogout'),
    ]);
    EventDispatcher.instance.register(AuthFailed, <MagicListener Function()>[
      () => _EventToRecord<AuthFailed>('AuthFailed'),
    ]);
    EventDispatcher.instance.register(AuthRestored, <MagicListener Function()>[
      () => _EventToRecord<AuthRestored>('AuthRestored'),
    ]);

    // 2. Database lifecycle (connection only; QueryExecuted is omitted
    //    until alpha-3 ships a dedicated query channel).
    EventDispatcher.instance.register(
      DatabaseConnected,
      <MagicListener Function()>[
        () => _EventToRecord<DatabaseConnected>('DatabaseConnected'),
      ],
    );

    // 3. Gate definitions (the gate RESULT event lives on
    //    MagicGateWatcher to avoid a double-record on the event channel).
    EventDispatcher.instance.register(
      GateAbilityDefined,
      <MagicListener Function()>[
        () => _EventToRecord<GateAbilityDefined>('GateAbilityDefined'),
      ],
    );
    EventDispatcher.instance.register(
      GateBeforeRegistered,
      <MagicListener Function()>[
        () => _EventToRecord<GateBeforeRegistered>('GateBeforeRegistered'),
      ],
    );
  }

  @override
  void uninstall() {
    // EventDispatcher.clear() is global ; we deliberately do NOT call it
    // here to avoid wiping host-registered listeners. Mirrors
    // MagicModelWatcher.uninstall().
  }
}

/// Generic event-to-record adapter for [MagicEventWatcher]. Captured at
/// construction with the wire-name of the event type; payload is the
/// empty map (alpha-2 scope).
class _EventToRecord<T extends MagicEvent> extends MagicListener<T> {
  _EventToRecord(this.eventTypeName);

  /// Stable wire identifier (e.g. 'AuthLogin'). We snapshot it at
  /// construction so the record name stays in lock-step with the magic
  /// class name even when listeners are factory-rebuilt per dispatch.
  final String eventTypeName;

  @override
  Future<void> handle(T event) async {
    TelescopeStore.recordEvent(
      EventRecord(
        eventType: eventTypeName,
        payload: const <String, dynamic>{},
        time: DateTime.now(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gate watcher ; subscribes to GateAccessChecked (both allowed and denied).
// ---------------------------------------------------------------------------

/// [TelescopeWatcher] for magic's gate-result event. Subscribes to the
/// canonical [GateAccessChecked] (covers both allow and deny outcomes via
/// `allowed: bool`); the convenience [GateAccessDenied] event is NOT
/// subscribed to because it would double-record every denial.
class MagicGateWatcher implements TelescopeWatcher {
  /// Per-instance guard ; see [MagicEventWatcher._installed] for the
  /// rationale (avoids double-record on a second install).
  bool _installed = false;

  @override
  String get name => 'magic_gate';

  @override
  void install() {
    if (_installed) return;
    _installed = true;
    EventDispatcher.instance.register(
      GateAccessChecked,
      <MagicListener Function()>[() => _GateAccessCheckedListener()],
    );
  }

  @override
  void uninstall() {
    // EventDispatcher has no per-listener removal API ; see
    // MagicModelWatcher.uninstall() for the same trade-off.
  }
}

/// Translates a [GateAccessChecked] into a [GateRecord]. Applies the two
/// shape coercions GateRecord requires:
/// - `arguments` (single dynamic on the event) → `List<Object?>` (always
///   length 1, even when the dynamic is null).
/// - `user.id` (dynamic primary key) → `String?` via `.toString()`; a
///   null user OR a null id both collapse to `userId: null`.
class _GateAccessCheckedListener extends MagicListener<GateAccessChecked> {
  @override
  Future<void> handle(GateAccessChecked event) async {
    final Model? user = event.user;
    final dynamic userId = user?.id;
    TelescopeStore.recordGate(
      GateRecord(
        ability: event.ability,
        result: event.allowed,
        arguments: <Object?>[_coerceArg(event.arguments)],
        userId: userId?.toString(),
        time: DateTime.now(),
      ),
    );
  }

  /// Coerces a single dynamic `GateAccessChecked.arguments` value to a JSON
  /// shape so `GateRecord.toJson()` can stay a dumb DTO. Magic Models are
  /// converted via `toMap()`; anything else passes through if already
  /// JSON-encodable, otherwise falls back to `toString()`.
  static Object? _coerceArg(dynamic value) {
    if (value == null) return null;
    if (value is String || value is num || value is bool) return value;
    if (value is List || value is Map) return value;
    if (value is Model) return value.toMap();
    return value.toString();
  }
}
