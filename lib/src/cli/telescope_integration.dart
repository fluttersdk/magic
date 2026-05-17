import 'package:flutter/foundation.dart';
import 'package:fluttersdk_telescope/telescope.dart';

import '../database/eloquent/model.dart';
import '../database/events/model_events.dart';
import '../events/event_dispatcher.dart';
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
/// Registers three units with [TelescopePlugin]:
/// 1. [MagicHttpFacadeAdapter] — wraps Magic's `network` driver with a
///    [MagicNetworkInterceptor] that feeds [TelescopeStore.recordHttp]
///    (oracle's reuse-pattern decision kept inside magic).
/// 2. [MagicModelWatcher] — subscribes to `ModelCreated`, `ModelSaved`,
///    `ModelDeleted` and feeds [TelescopeStore.recordMagicModel].
/// 3. [MagicCacheWatcher] — placeholder; magic's Cache facade does not
///    currently emit lifecycle events. V1.x will land cache events
///    upstream in magic's Cache layer; this watcher's [install] is a
///    no-op for now (kept registered so the V1.x event wiring is a
///    one-file change).
///
/// The three integration classes below are exposed for testing but are
/// NOT re-exported from `package:magic/magic.dart` — only
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
  }

  /// Whether [install] has been called at least once.
  @visibleForTesting
  static bool get isInstalled => _installed;

  /// Test-only reset. Drops the idempotency guard.
  ///
  /// Does NOT unregister the adapters/watchers — TelescopePlugin keeps
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
// HTTP adapter — wraps Magic's network driver via MagicNetworkInterceptor.
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
    // We disarm the interceptor instead — recording becomes a no-op.
    _interceptor?._disarmed = true;
    _interceptor = null;
  }
}

/// Internal interceptor — translates Magic network lifecycle into
/// [HttpRequestRecord] entries. Pairs request → response/error via a
/// per-request stopwatch keyed on identity.
///
/// FIFO attribution (`attributedHeuristically: true`) is used because
/// `MagicNetworkInterceptor` does not carry a correlation handle across
/// `onRequest` / `onResponse` calls — best-effort matching by call order.
class _TelescopeNetworkInterceptor extends MagicNetworkInterceptor {
  /// Set to true by [MagicHttpFacadeAdapter.uninstall] — drops every
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
// Model watcher — subscribes to Magic's model lifecycle events.
// ---------------------------------------------------------------------------

/// [TelescopeWatcher] that subscribes to `ModelCreated`, `ModelSaved`,
/// `ModelDeleted` and feeds [TelescopeStore.recordMagicModel].
///
/// Registers three listener factories with [EventDispatcher] — magic's
/// dispatcher invokes the factory once per dispatch and calls the
/// listener's `handle` method.
class MagicModelWatcher implements TelescopeWatcher {
  @override
  String get name => 'magic_model';

  @override
  void install() {
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
    // EventDispatcher.clear() is global — we deliberately do NOT call it
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

  /// 'created' | 'saved' | 'deleted' — matches [MagicModelRecord.event].
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
// Cache watcher — placeholder for V1.x cache event wiring.
// ---------------------------------------------------------------------------

/// [TelescopeWatcher] for Magic's cache facade.
///
/// V1.x: magic's `Cache` facade does not emit lifecycle events today
/// (no `CacheHit`/`CacheMiss`/`CacheWritten`/`CacheForgotten` event
/// classes exist in `lib/src/cache/`). This watcher is registered as
/// part of the public surface so the V1.x upgrade — once cache events
/// land upstream — is a one-file change in this package: subscribe via
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
