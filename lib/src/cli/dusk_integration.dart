import 'package:flutter/material.dart';
import 'package:fluttersdk_dusk/dusk.dart';

import '../auth/gate_result.dart';
import '../concerns/validates_requests.dart';
import '../database/eloquent/model.dart';
import '../facades/auth.dart';
import '../facades/gate.dart';
import '../foundation/magic.dart';
import '../http/magic_controller.dart';
import '../http/middleware/magic_middleware.dart';
import '../routing/magic_router.dart';
import '../ui/magic_form.dart';
import '../ui/magic_form_data.dart';

/// Glues magic's primitives (MagicForm, MagicRouter, Gate, Auth) into
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
/// Adds seven enrichers to [DuskPlugin.enrichers] (in insertion order;
/// later enrichers see the same Element, first-write-wins on overlapping
/// keys per oracle finding #3 contract):
///
/// 1. [magicFormEnricher] — `magicFormField: <name>` for elements backed
///    by a [MagicFormData] text controller.
/// 2. [magicNavigationEnricher] — `magicRoute: <currentLocation>` for
///    every element when the router has resolved a route.
/// 3. [magicControllerEnricher] — `magicControllerState: <Class>.<status>`
///    for the first registered [MagicStateMixin] controller.
/// 4. [magicFormErrorsEnricher] — `magicFormErrors: <field1,field2>` for
///    elements under a [MagicForm] whose controller carries server-side
///    [ValidatesRequests] errors matching the form's fields.
/// 5. [magicGateResultEnricher] — `magicGateResult: <ability>.<allowed|denied>`
///    for the most recently cached [GateResult] in [Gate.manager].
/// 6. [magicMiddlewareEnricher] — `magicMiddleware: <name1,name2>` for
///    the active route's middlewares via [MagicRouter.currentRoute].
/// 7. [magicAuthUserEnricher] — `magicAuthUser: <id>[:<displayName>]` for
///    the authenticated user surfaced by [Auth.user].
///
/// All seven enrichers are synchronous, return null on miss, and never
/// retain the [Element] across calls (oracle finding #3 contract, see
/// [DuskSnapshotEnricher]).
class MagicDuskIntegration {
  MagicDuskIntegration._();

  /// Idempotent install. Safe to call multiple times within the same
  /// isolate lifetime (matches [DuskPlugin.install] semantics).
  ///
  /// Insertion order is load-bearing: the two original enrichers keep
  /// their slot, and the five new enrichers are appended after them so
  /// any first-write-wins overlap stays deterministic across versions.
  static void install() {
    if (_installed) return;
    _installed = true;

    // 1. Original enrichers (insertion slots 0 and 1 — stable).
    DuskPlugin.enrichers.add(magicFormEnricher);
    DuskPlugin.enrichers.add(magicNavigationEnricher);

    // 2. New enrichers (slots 2..6, added in declaration order).
    DuskPlugin.enrichers.add(magicControllerEnricher);
    DuskPlugin.enrichers.add(magicFormErrorsEnricher);
    DuskPlugin.enrichers.add(magicGateResultEnricher);
    DuskPlugin.enrichers.add(magicMiddlewareEnricher);
    DuskPlugin.enrichers.add(magicAuthUserEnricher);
  }

  /// Test-only reset. Drops all seven enrichers from [DuskPlugin.enrichers]
  /// and clears the idempotency guard.
  @visibleForTesting
  static void resetForTesting() {
    DuskPlugin.enrichers.remove(magicFormEnricher);
    DuskPlugin.enrichers.remove(magicNavigationEnricher);
    DuskPlugin.enrichers.remove(magicControllerEnricher);
    DuskPlugin.enrichers.remove(magicFormErrorsEnricher);
    DuskPlugin.enrichers.remove(magicGateResultEnricher);
    DuskPlugin.enrichers.remove(magicMiddlewareEnricher);
    DuskPlugin.enrichers.remove(magicAuthUserEnricher);
    _installed = false;
  }

  /// Whether [install] has been called at least once.
  @visibleForTesting
  static bool get isInstalled => _installed;

  static bool _installed = false;
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

/// Enricher: emits `magicFormErrors: <field1,field2>` for elements under
/// a [MagicForm] whose controller carries server-side
/// [ValidatesRequests] errors matching the form's own field set.
///
/// Cross-form leak guard: the emitted list is the intersection of the
/// controller's `validationErrors.keys` and the form's `fieldNames`. A
/// controller with no `ValidatesRequests` mixin, no errors, or no errors
/// matching the form's fields yields null.
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
  final Iterable<String> fields = scope == null
      ? errors.keys
      : errors.keys.where(scope.contains);

  final List<String> list = fields.toList(growable: false);
  if (list.isEmpty) return null;

  return 'magicFormErrors: ${list.join(',')}';
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
