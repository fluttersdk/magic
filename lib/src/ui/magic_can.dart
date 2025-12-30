import 'package:flutter/widgets.dart';

import '../facades/gate.dart';

/// A widget that conditionally renders content based on authorization.
///
/// MagicCan checks if the authenticated user has the specified ability
/// and renders the child widget only if authorized. This enables
/// declarative, Laravel-style authorization in your UI.
///
/// ## Basic Usage
///
/// ```dart
/// MagicCan(
///   ability: 'update-post',
///   arguments: post,
///   child: WButton(
///     text: 'Edit Post',
///     onTap: () => controller.edit(post),
///   ),
/// )
/// ```
///
/// ## With Placeholder
///
/// ```dart
/// MagicCan(
///   ability: 'view-admin-panel',
///   child: AdminPanel(),
///   placeholder: Text('Access Denied'),
/// )
/// ```
///
/// ## Multiple Abilities
///
/// ```dart
/// // For "OR" logic, nest MagicCan widgets:
/// MagicCan(
///   ability: 'update-post',
///   arguments: post,
///   child: EditButton(),
///   placeholder: MagicCan(
///     ability: 'view-post',
///     arguments: post,
///     child: ViewButton(),
///   ),
/// )
/// ```
///
/// ## Notes
///
/// - If the user is not authenticated, the placeholder is always shown.
/// - If the ability is not defined, the placeholder is shown.
/// - Authorization is checked synchronously on build.
class MagicCan extends StatelessWidget {
  /// The ability name to check (e.g., 'update-post').
  final String ability;

  /// Optional arguments passed to the ability check (e.g., a Post model).
  final dynamic arguments;

  /// The widget to render if the user has the ability.
  final Widget child;

  /// The widget to render if the user lacks the ability.
  ///
  /// Defaults to an empty `SizedBox.shrink()`.
  final Widget placeholder;

  /// Create a MagicCan widget.
  const MagicCan({
    super.key,
    required this.ability,
    this.arguments,
    required this.child,
    this.placeholder = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    if (Gate.allows(ability, arguments)) {
      return child;
    }
    return placeholder;
  }
}

/// A widget that renders content only if the user CANNOT perform an action.
///
/// This is the inverse of [MagicCan].
///
/// ```dart
/// MagicCannot(
///   ability: 'view-content',
///   child: LoginPrompt(),
/// )
/// ```
class MagicCannot extends StatelessWidget {
  /// The ability name to check.
  final String ability;

  /// Optional arguments passed to the ability check.
  final dynamic arguments;

  /// The widget to render if the user LACKS the ability.
  final Widget child;

  /// The widget to render if the user HAS the ability.
  final Widget placeholder;

  /// Create a MagicCannot widget.
  const MagicCannot({
    super.key,
    required this.ability,
    this.arguments,
    required this.child,
    this.placeholder = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    if (Gate.denies(ability, arguments)) {
      return child;
    }
    return placeholder;
  }
}
