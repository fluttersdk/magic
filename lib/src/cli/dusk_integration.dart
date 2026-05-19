import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttersdk_dusk/dusk.dart';
import 'package:fluttersdk_telescope/telescope.dart';

import '../auth/gate_result.dart';
import '../broadcasting/broadcast_connection_state.dart';
import '../concerns/validates_requests.dart';
import '../database/eloquent/model.dart';
import '../facades/auth.dart';
import '../facades/echo.dart';
import '../facades/gate.dart';
import '../foundation/magic.dart';
import '../http/magic_controller.dart';
import '../http/middleware/magic_middleware.dart';
import '../routing/magic_router.dart';
import '../ui/magic_form.dart';
import '../ui/magic_form_data.dart';

/// Glues magic's primitives (MagicForm, MagicRouter, Gate, Auth, Echo) into
/// the fluttersdk_dusk snapshot pipeline.
///
/// Host integration (debug-only):
/// ```dart
/// if (kDebugMode) {
///   DuskPlugin.install();
///   MagicDuskIntegration.install();
/// }
/// ```
///
/// Adds fourteen enrichers to [DuskPlugin.enrichers] (in insertion order;
/// later enrichers see the same Element, first-write-wins on overlapping
/// keys per oracle finding #3 contract):
///
/// 1. [magicFormEnricher] — `magicFormField: <name>` for elements backed
///    by a [MagicFormData] text controller.
/// 2. [magicNavigationEnricher] — `magicRoute: <currentLocation>` for
///    every element when the router has resolved a route.
/// 3. [magicControllerEnricher] — `magicControllerState: <Class>.<status>`
///    for the first registered [MagicStateMixin] controller.
/// 4. [magicFormErrorsEnricher] — `magicFormErrors: <field>="<text>",...`
///    for elements under a [MagicForm] whose controller carries server-side
///    [ValidatesRequests] errors matching the form's fields. Per-field
///    error text is quoted and truncated to 80 chars (...-suffixed).
/// 5. [magicGateResultEnricher] — `magicGateResult: <ability>.<allowed|denied>`
///    for the most recently cached [GateResult] in [Gate.manager].
/// 6. [magicMiddlewareEnricher] — `magicMiddleware: <name1,name2>` for
///    the active route's middlewares via [MagicRouter.currentRoute].
/// 7. [magicAuthUserEnricher] — `magicAuthUser: <id>[:<displayName>]` for
///    the authenticated user surfaced by [Auth.user].
/// 8. [magicControllerFlagsEnricher] — `magicControllerFlags:
///    <Class>.isLoading=<bool>,isSuccess=<bool>,isError=<bool>,isEmpty=<bool>`
///    for the first registered [MagicStateMixin] controller.
/// 9. [magicRouteParamsEnricher] — `magicRouteParams: <k>=<v>,...` for the
///    active route's path + query parameters (path params first).
/// 10. [magicEchoConnectionEnricher] — `magicEchoConnection:
///     connected|reconnecting|disconnected` for the current broadcast
///     connection state. Null when the broadcasting provider is not registered.
/// 11. [magicGateResultsAllEnricher] — `magicGateResultsAll:
///     <ability>=<allowed|denied>,...` for up to 5 most recently checked
///     abilities. Null when no ability has been checked yet.
/// 12. [magicRecentHttpEnricher] — `magicRecentHttp: GET /url 200 142ms,...`
///     for up to 5 most recent HTTP records captured by telescope. URLs
///     are truncated to 40 characters. Null when the telescope buffer is
///     empty or the telescope-presence check fails.
/// 13. [magicRecentLogsEnricher] — `magicRecentLogs: [WARN] msg,[ERROR] msg`
///     for up to 3 most recent log records at or above WARNING level.
///     Messages are truncated to 50 characters. Null when the telescope
///     buffer is empty or the telescope-presence check fails.
/// 14. [magicRecentExceptionsEnricher] — `magicRecentExceptions:
///     HttpException at api.dart:142,...` for up to 3 most recent
///     exception records. Each entry surfaces the type plus the file:line
///     extracted from the first stack frame. Null when the telescope
///     buffer is empty or the telescope-presence check fails.
///
/// All fourteen enrichers are synchronous, return null on miss, and never
/// retain the [Element] across calls (oracle finding #3 contract, see
/// [DuskSnapshotEnricher]).
class MagicDuskIntegration {
  MagicDuskIntegration._();

  /// Idempotent install. Safe to call multiple times within the same
  /// isolate lifetime (matches [DuskPlugin.install] semantics).
  ///
  /// Insertion order is load-bearing: the two original enrichers keep
  /// their slot, the five Plan-Step-17 enrichers are appended after
  /// them, the two Step-1.1 enrichers (controllerFlags, routeParams)
  /// land at slots 7 and 8, the two Step-1.2 enrichers
  /// (echoConnection, gateResultsAll) land at slots 9 and 10, and the
  /// three Step-1.3 telescope-bridge enrichers (recentHttp, recentLogs,
  /// recentExceptions) land at slots 11, 12, 13 so any first-write-wins
  /// overlap stays deterministic across versions.
  static void install() {
    if (_installed) return;
    _installed = true;

    // 1. Original enrichers (insertion slots 0 and 1 — stable).
    DuskPlugin.enrichers.add(magicFormEnricher);
    DuskPlugin.enrichers.add(magicNavigationEnricher);

    // 2. Plan-Step-17 enrichers (slots 2..6, added in declaration order).
    DuskPlugin.enrichers.add(magicControllerEnricher);
    DuskPlugin.enrichers.add(magicFormErrorsEnricher);
    DuskPlugin.enrichers.add(magicGateResultEnricher);
    DuskPlugin.enrichers.add(magicMiddlewareEnricher);
    DuskPlugin.enrichers.add(magicAuthUserEnricher);

    // 3. Step-1.1 enrichers (slots 7..8, added in declaration order).
    DuskPlugin.enrichers.add(magicControllerFlagsEnricher);
    DuskPlugin.enrichers.add(magicRouteParamsEnricher);

    // 4. Step-1.2 enrichers (slots 9..10, added in declaration order).
    DuskPlugin.enrichers.add(magicEchoConnectionEnricher);
    DuskPlugin.enrichers.add(magicGateResultsAllEnricher);

    // 5. Step-1.3 telescope-bridge enrichers (slots 11..13). Each enricher
    //    wraps its [TelescopeStore] read in try/catch so a missing-telescope
    //    classpath collapses to a graceful null without bubbling up.
    DuskPlugin.enrichers.add(magicRecentHttpEnricher);
    DuskPlugin.enrichers.add(magicRecentLogsEnricher);
    DuskPlugin.enrichers.add(magicRecentExceptionsEnricher);

    // 6. Subscribe to the Echo connection-state stream when broadcasting is
    //    registered; keep the last emitted value in the module-private cache
    //    so [magicEchoConnectionEnricher] can read it synchronously.
    if (Magic.bound('broadcasting')) {
      _echoSubscription = Echo.manager.connection().connectionState.listen(
        (state) => _lastEchoState = _connectionStateName(state),
      );
    }
  }

  /// Test-only reset. Drops all fourteen enrichers from
  /// [DuskPlugin.enrichers], cancels the Echo connection-state
  /// subscription, and clears the idempotency guard.
  @visibleForTesting
  static void resetForTesting() {
    DuskPlugin.enrichers.remove(magicFormEnricher);
    DuskPlugin.enrichers.remove(magicNavigationEnricher);
    DuskPlugin.enrichers.remove(magicControllerEnricher);
    DuskPlugin.enrichers.remove(magicFormErrorsEnricher);
    DuskPlugin.enrichers.remove(magicGateResultEnricher);
    DuskPlugin.enrichers.remove(magicMiddlewareEnricher);
    DuskPlugin.enrichers.remove(magicAuthUserEnricher);
    DuskPlugin.enrichers.remove(magicControllerFlagsEnricher);
    DuskPlugin.enrichers.remove(magicRouteParamsEnricher);
    DuskPlugin.enrichers.remove(magicEchoConnectionEnricher);
    DuskPlugin.enrichers.remove(magicGateResultsAllEnricher);
    DuskPlugin.enrichers.remove(magicRecentHttpEnricher);
    DuskPlugin.enrichers.remove(magicRecentLogsEnricher);
    DuskPlugin.enrichers.remove(magicRecentExceptionsEnricher);
    _echoSubscription?.cancel();
    _echoSubscription = null;
    _lastEchoState = null;
    _installed = false;
  }

  /// Whether [install] has been called at least once.
  @visibleForTesting
  static bool get isInstalled => _installed;

  static bool _installed = false;

  // Module-private Echo stream state — updated by the subscription installed
  // in [install] and cleared by [resetForTesting].
  static StreamSubscription<BroadcastConnectionState>? _echoSubscription;
  static String? _lastEchoState;
}

/// Enricher: emits `magicFormField: <name>` when [element] is backed by a
/// [TextEditingController] owned by a [MagicFormData] in an ancestor
/// [MagicForm].
///
/// Steps:
/// 1. Walk descendants for an [EditableText] and capture its controller.
/// 2. Walk ancestors for a [MagicForm] and read its [MagicFormData].
/// 3. Linear-scan [MagicFormData.fieldNames] for a text controller whose
///    identity matches the captured controller; emit `magicFormField: $name`.
///
/// Returns null when any step fails (no EditableText, no MagicForm
/// ancestor, no matching field). Never throws, never retains [element].
String? magicFormEnricher(Element element, RefRegistry refs) {
  // 1. Find the EditableText controller this element backs (or descends to).
  final TextEditingController? controller = _findEditableController(element);
  if (controller == null) return null;

  // 2. Walk ancestors for the nearest MagicForm.
  final MagicFormData? formData = _findAncestorFormData(element);
  if (formData == null) return null;

  // 3. Identity-compare against each text field's controller.
  for (final String name in formData.fieldNames) {
    final TextEditingController fieldController = _tryReadText(formData, name);
    if (identical(fieldController, controller)) {
      return 'magicFormField: $name';
    }
  }

  return null;
}

/// Enricher: emits `magicRoute: <currentLocation>` when the router has a
/// resolved location.
///
/// Element-independent (every snapshot row gets the same annotation when
/// the router is built), but kept as a per-element enricher so the YAML
/// emitter consistently surfaces the active route next to each ref.
///
/// Returns null when [MagicRouter.currentLocation] is null (router not
/// built yet, or no route has resolved).
String? magicNavigationEnricher(Element element, RefRegistry refs) {
  final String? location = MagicRouter.instance.currentLocation;
  if (location == null || location.isEmpty) return null;
  return 'magicRoute: $location';
}

/// Enricher: emits `magicControllerState: <ControllerClass>.<rxStatus>`
/// for the first [MagicStateMixin]-bearing controller registered via
/// [Magic.put].
///
/// Element-independent (the controller is a global singleton in the
/// `Magic` registry), but kept as a per-element enricher so the YAML
/// emitter consistently surfaces controller state next to each ref.
///
/// Returns null when no `MagicStateMixin` controller is registered.
String? magicControllerEnricher(Element element, RefRegistry refs) {
  for (final Object controller in Magic.controllers) {
    if (controller is! MagicController) continue;
    final String? status = _readRxStatusName(controller);
    if (status == null) continue;
    final String className = controller.runtimeType.toString();
    return 'magicControllerState: $className.$status';
  }
  return null;
}

/// Enricher: emits `magicFormErrors: <field>="<text>",...` for elements
/// under a [MagicForm] whose controller carries server-side
/// [ValidatesRequests] errors matching the form's own field set.
///
/// Cross-form leak guard: the emitted list is the intersection of the
/// controller's `validationErrors.keys` and the form's `fieldNames`. A
/// controller with no `ValidatesRequests` mixin, no errors, or no errors
/// matching the form's fields yields null.
///
/// Per-field error text is quoted and truncated to 80 characters; longer
/// messages collapse to their first 77 characters followed by `...`.
/// Insertion order from `validationErrors` is preserved.
String? magicFormErrorsEnricher(Element element, RefRegistry refs) {
  // 1. Walk ancestors for a MagicForm — same pattern as magicFormEnricher.
  final _MagicFormBinding? binding = _findAncestorMagicFormBinding(element);
  if (binding == null) return null;

  final MagicController? controller = binding.controller;
  if (controller is! ValidatesRequests) return null;

  final Map<String, String> errors = controller.validationErrors;
  if (errors.isEmpty) return null;

  // 2. Intersect with the form's fieldNames when available; otherwise
  //    surface every error key (legacy MagicForm has no fieldNames).
  final Set<String>? scope = binding.fieldNames;
  final Iterable<MapEntry<String, String>> kept = scope == null
      ? errors.entries
      : errors.entries.where((e) => scope.contains(e.key));

  // 3. Emit quoted per-field text. Truncate long messages to 80 chars.
  final List<String> parts = kept
      .map((e) => '${e.key}="${_truncateErrorText(e.value)}"')
      .toList(growable: false);
  if (parts.isEmpty) return null;

  return 'magicFormErrors: ${parts.join(',')}';
}

/// Truncate a validation-error message to 80 characters, suffixing `...`
/// when the source exceeds that length so the snapshot stays bounded.
String _truncateErrorText(String text) {
  const int maxLength = 80;
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength - 3)}...';
}

/// Enricher: emits `magicGateResult: <ability>.<allowed|denied>` for the
/// most recently cached [GateResult] in [Gate.manager].
///
/// Reads the cache via `Gate.manager.lastResult(...)`; the cache itself
/// is populated transparently by every `Gate.allows`/`denies` call.
/// Returns null when the cache is empty (no checks yet, or
/// `flush()` was called).
String? magicGateResultEnricher(Element element, RefRegistry refs) {
  final result = _mostRecentGateResult();
  if (result == null) return null;
  final outcome = result.allowed ? 'allowed' : 'denied';
  return 'magicGateResult: ${result.ability}.$outcome';
}

/// Enricher: emits `magicMiddleware: <name1,name2>` for the active
/// route's resolved middleware names.
///
/// Uses [MagicRouter.currentRoute] (added in Plan Step 17 sub-change a)
/// to reach the [RouteDefinition.middlewares] list without depending on
/// any private router state. Middleware names come from the
/// instance's `toString()` for [MagicMiddleware] objects (subclasses
/// typically use the class name) and the raw string for string aliases.
///
/// Returns null when no route is active or the route has zero
/// middlewares.
String? magicMiddlewareEnricher(Element element, RefRegistry refs) {
  final route = MagicRouter.instance.currentRoute;
  if (route == null) return null;

  final List<dynamic> middlewares = route.middlewares;
  if (middlewares.isEmpty) return null;

  final List<String> names = middlewares
      .map(_middlewareLabel)
      .toList(growable: false);
  return 'magicMiddleware: ${names.join(',')}';
}

/// Enricher: emits `magicAuthUser: <id>[:<displayName>]` for the
/// authenticated user.
///
/// - Returns null when `Auth.user()` returns null (guest session).
/// - Emits `magicAuthUser: <id>:<displayName>` when the user model
///   carries a non-empty `display_name` attribute.
/// - Falls back to `magicAuthUser: <id>` (id only, no trailing colon)
///   when `display_name` is null, missing, or the empty string.
String? magicAuthUserEnricher(Element element, RefRegistry refs) {
  final Model? user = Auth.user<Model>();
  if (user == null) return null;

  final dynamic id = user.getAttribute('id');
  final dynamic raw = user.getAttribute('display_name');
  final String? displayName = (raw is String && raw.isNotEmpty) ? raw : null;

  if (displayName == null) {
    return 'magicAuthUser: $id';
  }
  return 'magicAuthUser: $id:$displayName';
}

/// Enricher: emits `magicControllerFlags:
/// <Class>.isLoading=<bool>,isSuccess=<bool>,isError=<bool>,isEmpty=<bool>`
/// for the first registered [MagicStateMixin] controller in
/// [Magic.controllers].
///
/// Sibling to [magicControllerEnricher]: that enricher surfaces the
/// active `rxStatus` enum name (`success`, `loading`, `error`, `empty`);
/// this one surfaces the four built-in boolean projections in a stable
/// declaration order so an agent does not need to derive them from the
/// status string.
///
/// Returns null when no `MagicStateMixin` controller is registered.
String? magicControllerFlagsEnricher(Element element, RefRegistry refs) {
  for (final Object controller in Magic.controllers) {
    if (controller is! MagicController) continue;
    final _ControllerFlags? flags = _readControllerFlags(controller);
    if (flags == null) continue;
    final String className = controller.runtimeType.toString();
    return 'magicControllerFlags: $className.'
        'isLoading=${flags.isLoading},'
        'isSuccess=${flags.isSuccess},'
        'isError=${flags.isError},'
        'isEmpty=${flags.isEmpty}';
  }
  return null;
}

/// Enricher: emits `magicRouteParams: <k>=<v>,...` for the active
/// route's path parameters followed by its query parameters.
///
/// Path parameters appear first (declaration order from
/// [MagicRouter.pathParameters]); query parameters follow (in
/// `Uri.queryParameters` declaration order). When both maps are empty
/// the enricher returns null so the YAML output stays uncluttered for
/// parameterless routes.
String? magicRouteParamsEnricher(Element element, RefRegistry refs) {
  final Map<String, String> pathParams = MagicRouter.instance.pathParameters;
  final Map<String, String> queryParams = MagicRouter.instance.queryParameters;
  if (pathParams.isEmpty && queryParams.isEmpty) return null;

  final List<String> parts = <String>[
    for (final entry in pathParams.entries) '${entry.key}=${entry.value}',
    for (final entry in queryParams.entries) '${entry.key}=${entry.value}',
  ];
  return 'magicRouteParams: ${parts.join(',')}';
}

/// Enricher: emits `magicEchoConnection: connected|reconnecting|disconnected`
/// for the current broadcast connection state.
///
/// The state is read from a module-private cache ([MagicDuskIntegration]
/// static field `_lastEchoState`) that is updated by a [StreamSubscription]
/// installed in [MagicDuskIntegration.install]. When no stream event has
/// fired yet, falls back to [BroadcastDriver.isConnected] to derive the
/// initial state without spinning up a new subscription.
///
/// Returns null when the `'broadcasting'` binding is not present in the
/// Magic container (i.e. [BroadcastServiceProvider] was not registered).
String? magicEchoConnectionEnricher(Element element, RefRegistry refs) {
  if (!Magic.bound('broadcasting')) return null;

  // 1. Prefer the stream-cached state (updated in install()).
  final String? cached = MagicDuskIntegration._lastEchoState;
  if (cached != null) return 'magicEchoConnection: $cached';

  // 2. Fall back to the sync isConnected heuristic when no stream event
  //    has fired yet (driver starts up or subscription not yet installed).
  final bool connected = Echo.manager.connection().isConnected;
  final String state = connected ? 'connected' : 'disconnected';
  return 'magicEchoConnection: $state';
}

/// Enricher: emits `magicGateResultsAll: <ability>=<allowed|denied>,...`
/// for up to 5 of the most recently checked Gate abilities.
///
/// Reads [Gate.manager.abilities] to obtain the set of defined abilities,
/// then calls [GateManager.lastResult] per ability — a read-only cache
/// lookup that never calls the ability callback. Abilities with no cached
/// result (never checked) are skipped. The emitted list is ordered by
/// [GateResult.checkedAt] descending so the most recent decisions appear
/// first, truncated to 5 entries.
///
/// Returns null when no ability has a cached result (no gate checks have
/// run since the last [Gate.manager.flush]).
///
/// Contract: NO new [Gate.allows] calls are made — this enricher is
/// read-only with zero side-effects.
String? magicGateResultsAllEnricher(Element element, RefRegistry refs) {
  // 1. Collect all abilities that have a cached result.
  final List<GateResult> results = Gate.manager.abilities
      .map((ability) => Gate.manager.lastResult(ability))
      .whereType<GateResult>()
      .toList(growable: false);

  if (results.isEmpty) return null;

  // 2. Sort by checkedAt descending (most recent first) and take up to 5.
  results.sort((a, b) => b.checkedAt.compareTo(a.checkedAt));
  final List<GateResult> recent = results.length > 5
      ? results.sublist(0, 5)
      : results;

  // 3. Format as `ability=allowed|denied` entries joined by comma.
  final String payload = recent
      .map((r) => '${r.ability}=${r.allowed ? "allowed" : "denied"}')
      .join(',');
  return 'magicGateResultsAll: $payload';
}

/// Enricher: emits `magicRecentHttp: <METHOD> <url> <status> <durationMs>ms,...`
/// for up to 5 most recent records in [TelescopeStore.recentHttp].
///
/// Each entry surfaces `method`, the (optionally truncated) `url`,
/// `statusCode`, and `durationMs`. URLs longer than 40 characters are
/// truncated to a 37-character prefix followed by `...` so the snapshot
/// stays bounded.
///
/// Returns null when the telescope buffer is empty or the telescope
/// classpath is not present — the [TelescopeStore.recentHttp] call is
/// wrapped in try/catch so a missing-dep classpath collapses to a
/// graceful null instead of bubbling up.
String? magicRecentHttpEnricher(Element element, RefRegistry refs) {
  final List<HttpRequestRecord>? records = _safeReadRecentHttp();
  if (records == null || records.isEmpty) return null;

  final List<String> parts = records
      .map(
        (r) =>
            '${r.method} ${_truncateUrl(r.url)} '
            '${r.statusCode} ${r.durationMs}ms',
      )
      .toList(growable: false);
  return 'magicRecentHttp: ${parts.join(',')}';
}

/// Enricher: emits `magicRecentLogs: [<shortLevel>] <message>,...` for up
/// to 3 most recent log records at or above WARNING level in
/// [TelescopeStore.recentLogs].
///
/// Level names are mapped to short labels for compactness:
/// WARNING → WARN, SEVERE → ERROR, everything else surfaces its
/// upper-cased level name as-is. Messages longer than 50 characters are
/// truncated to a 47-character prefix followed by `...`.
///
/// Returns null when the telescope buffer is empty (or no entries meet
/// the WARNING threshold) or the telescope classpath is not present.
String? magicRecentLogsEnricher(Element element, RefRegistry refs) {
  final List<LogRecordEntry>? records = _safeReadRecentLogs();
  if (records == null || records.isEmpty) return null;

  final List<String> parts = records
      .map(
        (r) =>
            '[${_shortLevelLabel(r.level)}] ${_truncateLogMessage(r.message)}',
      )
      .toList(growable: false);
  return 'magicRecentLogs: ${parts.join(',')}';
}

/// Enricher: emits `magicRecentExceptions: <Type> at <file.dart>:<line>,...`
/// for up to 3 most recent records in [TelescopeStore.recentExceptions].
///
/// Each entry is the [ExceptionRecord.exceptionType] followed by the
/// file:line extracted from the first stack-trace frame. When the
/// `stackTrace` is null or no `file.dart:line` token can be parsed from
/// it, the entry collapses to the type alone (no trailing ` at ...`
/// suffix).
///
/// Returns null when the telescope buffer is empty or the telescope
/// classpath is not present.
String? magicRecentExceptionsEnricher(Element element, RefRegistry refs) {
  final List<ExceptionRecord>? records = _safeReadRecentExceptions();
  if (records == null || records.isEmpty) return null;

  final List<String> parts = records
      .map((r) {
        final String? location = _firstStackLocation(r.stackTrace);
        return location == null
            ? r.exceptionType
            : '${r.exceptionType} at $location';
      })
      .toList(growable: false);
  return 'magicRecentExceptions: ${parts.join(',')}';
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// Walk [element] and its descendants looking for an [EditableText] widget.
///
/// Returns the controller of the first one found, or null. Walks at most
/// one Element subtree per call — caller-bound scope, no retention.
TextEditingController? _findEditableController(Element element) {
  TextEditingController? found;

  void visit(Element e) {
    if (found != null) return;
    final widget = e.widget;
    if (widget is EditableText) {
      found = widget.controller;
      return;
    }
    e.visitChildren(visit);
  }

  // Check this element first, then descendants.
  visit(element);
  return found;
}

/// Walk [element].visitAncestorElements looking for a [MagicForm] with a
/// non-null [MagicFormData].
///
/// Returns the first matching [MagicFormData], or null when no MagicForm
/// ancestor exists (or its `formData` was not provided).
MagicFormData? _findAncestorFormData(Element element) {
  MagicFormData? found;

  element.visitAncestorElements((Element ancestor) {
    final widget = ancestor.widget;
    if (widget is MagicForm && widget.formData != null) {
      found = widget.formData;
      return false; // stop walking
    }
    return true; // keep walking
  });

  return found;
}

/// Read [MagicFormData]'s text controller for [name].
///
/// Returns a fresh sentinel controller when the field is not a text field,
/// so the identity comparison in [magicFormEnricher] cleanly fails. We do
/// not catch the AssertionError that MagicFormData would throw in debug:
/// the `fieldNames` set is the union of text and value fields, so we
/// explicitly guard the lookup with a `try`/`catch` that returns the
/// sentinel — identity-compare in the caller will be false.
TextEditingController _tryReadText(MagicFormData formData, String name) {
  try {
    return formData[name];
  } on Object {
    // Non-text field — return a per-call sentinel so identical() returns
    // false in the caller's compare loop.
    return _sentinel;
  }
}

/// Stable sentinel — distinct from any controller a host app could pass
/// to MagicFormData (TextEditingController.new constructs a fresh one).
final TextEditingController _sentinel = TextEditingController();

/// Read the `rxStatus.type` name from [controller] when it carries the
/// [MagicStateMixin], or null otherwise.
///
/// Uses dynamic dispatch instead of a typed `is MagicStateMixin<T>` check
/// because `T` is unknown at the enricher's call site. The mixin's
/// `rxStatus` getter is generic over `T` but its result type is not, so
/// the dynamic path is type-safe at runtime.
///
/// `enum.name` is not visible via the dynamic dispatch path on some
/// Dart configurations (the getter is statically resolved through the
/// enum type), so we read `toString()` and strip the `RxStatusType.`
/// prefix instead.
String? _readRxStatusName(MagicController controller) {
  try {
    final dynamic dyn = controller;
    final dynamic status = dyn.rxStatus;
    final String typeStr = status.type.toString();
    final int dot = typeStr.lastIndexOf('.');
    return dot < 0 ? typeStr : typeStr.substring(dot + 1);
  } on NoSuchMethodError {
    return null;
  } on TypeError {
    return null;
  }
}

/// Snapshot of the four [MagicStateMixin] boolean projections.
///
/// Held as an immutable value type so [magicControllerFlagsEnricher]
/// can format the emit string without re-reading the controller.
class _ControllerFlags {
  const _ControllerFlags({
    required this.isLoading,
    required this.isSuccess,
    required this.isError,
    required this.isEmpty,
  });

  final bool isLoading;
  final bool isSuccess;
  final bool isError;
  final bool isEmpty;
}

/// Read the four `MagicStateMixin` boolean getters from [controller],
/// or null when the controller does not carry the mixin.
///
/// Uses the same dynamic-dispatch pattern as [_readRxStatusName] because
/// `T` on `MagicStateMixin<T>` is unknown at the enricher's call site.
_ControllerFlags? _readControllerFlags(MagicController controller) {
  try {
    final dynamic dyn = controller;
    return _ControllerFlags(
      isLoading: dyn.isLoading as bool,
      isSuccess: dyn.isSuccess as bool,
      isError: dyn.isError as bool,
      isEmpty: dyn.isEmpty as bool,
    );
  } on NoSuchMethodError {
    return null;
  } on TypeError {
    return null;
  }
}

/// A flattened view of a [MagicForm] ancestor's controller and
/// (optional) field name scope.
class _MagicFormBinding {
  _MagicFormBinding({required this.controller, required this.fieldNames});

  final MagicController? controller;
  final Set<String>? fieldNames;
}

/// Walk [element].visitAncestorElements for a [MagicForm] and return a
/// [_MagicFormBinding] surfacing its controller and (when available)
/// `formData.fieldNames`.
///
/// Returns null when no [MagicForm] is found.
_MagicFormBinding? _findAncestorMagicFormBinding(Element element) {
  _MagicFormBinding? found;

  element.visitAncestorElements((Element ancestor) {
    final widget = ancestor.widget;
    if (widget is MagicForm) {
      final MagicFormData? data = widget.formData;
      found = _MagicFormBinding(
        controller: data?.controller ?? widget.controller,
        fieldNames: data?.fieldNames,
      );
      return false; // stop walking
    }
    return true; // keep walking
  });

  return found;
}

/// Return the most recently recorded [GateResult] across all abilities,
/// or null when the cache is empty.
GateResult? _mostRecentGateResult() => Gate.manager.mostRecentResult;

/// Surface a stable label for [entry] in the [magicMiddlewareEnricher]
/// output.
///
/// - Strings are returned verbatim (Kernel-alias case).
/// - [MagicMiddleware] instances use `toString()` so subclasses can
///   override the surface name; the default identity-style toString is
///   still informative because it includes the runtime type.
/// - Anything else falls back to `runtimeType.toString()`.
String _middlewareLabel(dynamic entry) {
  if (entry is String) return entry;
  if (entry is MagicMiddleware) return entry.toString();
  return entry.runtimeType.toString();
}

/// Map a [BroadcastConnectionState] enum value to the wire string emitted
/// by [magicEchoConnectionEnricher].
///
/// - [BroadcastConnectionState.connected] → `'connected'`
/// - [BroadcastConnectionState.reconnecting] → `'reconnecting'`
/// - [BroadcastConnectionState.disconnected] → `'disconnected'`
/// - [BroadcastConnectionState.connecting] → `'connecting'`
String _connectionStateName(BroadcastConnectionState state) {
  return switch (state) {
    BroadcastConnectionState.connected => 'connected',
    BroadcastConnectionState.reconnecting => 'reconnecting',
    BroadcastConnectionState.disconnected => 'disconnected',
    BroadcastConnectionState.connecting => 'connecting',
  };
}

/// Wrap [TelescopeStore.recentHttp] in a presence-safe try/catch.
///
/// Returns null when the telescope classpath is missing or the static
/// call throws for any reason — the enricher then coalesces to a
/// graceful null instead of bubbling the error up into Dusk's enricher
/// loop.
List<HttpRequestRecord>? _safeReadRecentHttp() {
  try {
    return TelescopeStore.recentHttp(limit: 5);
  } on Object {
    return null;
  }
}

/// Wrap [TelescopeStore.recentLogs] in a presence-safe try/catch.
///
/// Filters at the WARNING threshold so info/fine noise is dropped before
/// it reaches the snapshot. See [_safeReadRecentHttp] for the null-on-miss
/// contract.
List<LogRecordEntry>? _safeReadRecentLogs() {
  try {
    // 'WARNING' matches the `package:logging` Level.WARNING.name verbatim;
    // TelescopeStore._meetsLevel lowercases both sides before comparing.
    return TelescopeStore.recentLogs(limit: 3, minLevel: 'WARNING');
  } on Object {
    return null;
  }
}

/// Wrap [TelescopeStore.recentExceptions] in a presence-safe try/catch.
///
/// See [_safeReadRecentHttp] for the null-on-miss contract.
List<ExceptionRecord>? _safeReadRecentExceptions() {
  try {
    return TelescopeStore.recentExceptions(limit: 3);
  } on Object {
    return null;
  }
}

/// Truncate [url] to 40 characters, suffixing `...` when the source
/// exceeds that length so the snapshot stays bounded.
String _truncateUrl(String url) {
  const int maxLength = 40;
  if (url.length <= maxLength) return url;
  return '${url.substring(0, maxLength - 3)}...';
}

/// Truncate a log [message] to 50 characters, suffixing `...` when the
/// source exceeds that length.
String _truncateLogMessage(String message) {
  const int maxLength = 50;
  if (message.length <= maxLength) return message;
  return '${message.substring(0, maxLength - 3)}...';
}

/// Map a [logging.Level] name onto a compact bracket label used by
/// [magicRecentLogsEnricher].
///
/// - `WARNING` → `WARN`
/// - `SEVERE`  → `ERROR`
/// - Anything else surfaces its upper-cased level name verbatim.
String _shortLevelLabel(String level) {
  final String upper = level.toUpperCase();
  return switch (upper) {
    'WARNING' => 'WARN',
    'SEVERE' => 'ERROR',
    _ => upper,
  };
}

/// Extract the first `file.dart:line` token from [stackTrace], or null
/// when the stack is null/empty or no matching token can be parsed.
///
/// Stack frames look like `#0 Fn (package:app/api.dart:142:5)`; we want
/// just the `api.dart:142` segment so the snapshot stays tight. Pattern:
/// the last `/`-separated segment followed by `:<line>` from the first
/// non-empty line.
String? _firstStackLocation(String? stackTrace) {
  if (stackTrace == null) return null;
  final String trimmed = stackTrace.trim();
  if (trimmed.isEmpty) return null;

  // 1. Take the first non-empty line.
  final String firstLine = trimmed.split('\n').first;

  // 2. Match `<basename>.dart:<line>` anywhere in that line.
  final RegExp pattern = RegExp(r'([A-Za-z0-9_]+\.dart):(\d+)');
  final RegExpMatch? match = pattern.firstMatch(firstLine);
  if (match == null) return null;

  return '${match.group(1)}:${match.group(2)}';
}
