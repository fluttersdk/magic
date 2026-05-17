import 'package:flutter/material.dart';
import 'package:fluttersdk_dusk/dusk.dart';

import '../routing/magic_router.dart';
import '../ui/magic_form.dart';
import '../ui/magic_form_data.dart';

/// Glues magic's UI primitives (MagicForm, MagicRouter) into the
/// fluttersdk_dusk snapshot pipeline.
///
/// Host integration (debug-only):
/// ```dart
/// if (kDebugMode) {
///   DuskPlugin.install();
///   MagicDuskIntegration.install();
/// }
/// ```
///
/// Adds two enrichers to [DuskPlugin.enrichers] (in insertion order):
/// 1. [magicFormEnricher] — emits `magicFormField: <name>` for elements
///    backed by a TextEditingController owned by a [MagicFormData] in an
///    ancestor [MagicForm].
/// 2. [magicNavigationEnricher] — emits `magicRoute: <currentLocation>`
///    for elements that resolve through the current GoRouter state, so
///    the V3 snapshot YAML records the active route alongside each ref.
///
/// Both enrichers are synchronous and never retain the [Element] across
/// calls (oracle finding #3 contract, see [DuskSnapshotEnricher]).
class MagicDuskIntegration {
  MagicDuskIntegration._();

  /// Idempotent install. Safe to call multiple times within the same
  /// isolate lifetime (matches [DuskPlugin.install] semantics).
  static void install() {
    if (_installed) return;
    _installed = true;
    DuskPlugin.enrichers.add(magicFormEnricher);
    DuskPlugin.enrichers.add(magicNavigationEnricher);
  }

  /// Test-only reset. Drops both enrichers from [DuskPlugin.enrichers]
  /// and clears the idempotency guard.
  @visibleForTesting
  static void resetForTesting() {
    DuskPlugin.enrichers.remove(magicFormEnricher);
    DuskPlugin.enrichers.remove(magicNavigationEnricher);
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
