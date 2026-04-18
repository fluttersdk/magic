import 'package:flutter/widgets.dart';

/// Contract for controllers that expose Laravel-style resource routes.
///
/// A resource controller declares up to four view-building methods that
/// `MagicRoute.resource()` wires into canonical routes:
///
/// | Method          | Path                |
/// | --------------- | ------------------- |
/// | `index()`       | `GET /{resource}`        |
/// | `create()`      | `GET /{resource}/create` |
/// | `show(id)`      | `GET /{resource}/:id`    |
/// | `edit(id)`      | `GET /{resource}/:id/edit` |
///
/// Controllers may override [resourceMethods] to expose only a subset.
/// Non-exposed methods stay as `UnimplementedError` fallbacks.
///
/// ```dart
/// class MonitorController extends MagicController with ResourceController {
///   @override
///   Widget index() => const MonitorsIndexView();
///
///   @override
///   Widget show(String id) => MonitorShowView(id: id);
///
///   @override
///   Set<String> get resourceMethods => const {'index', 'show'};
/// }
/// ```
mixin ResourceController {
  /// The set of resource methods this controller exposes. Defaults to all
  /// four (`index`, `create`, `show`, `edit`). Override to limit registration.
  Set<String> get resourceMethods => const {'index', 'create', 'show', 'edit'};

  /// Render the collection view (`GET /{resource}`).
  Widget index() =>
      throw UnimplementedError('$runtimeType must override index()');

  /// Render the create form (`GET /{resource}/create`).
  Widget create() =>
      throw UnimplementedError('$runtimeType must override create()');

  /// Render a single resource (`GET /{resource}/:id`).
  Widget show(String id) =>
      throw UnimplementedError('$runtimeType must override show(id)');

  /// Render the edit form (`GET /{resource}/:id/edit`).
  Widget edit(String id) =>
      throw UnimplementedError('$runtimeType must override edit(id)');
}
