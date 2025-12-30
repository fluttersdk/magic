import '../../events/magic_event.dart';
import '../../database/eloquent/model.dart';

/// Fired when an ability check is performed (allowed or denied).
class GateAccessChecked extends MagicEvent {
  /// The ability that was checked.
  final String ability;

  /// The arguments passed to the check.
  final dynamic arguments;

  /// Whether access was granted.
  final bool allowed;

  /// The user who performed the check (null if guest).
  final Model? user;

  GateAccessChecked({
    required this.ability,
    this.arguments,
    required this.allowed,
    this.user,
  });

  /// Whether access was denied.
  bool get denied => !allowed;
}

/// Fired when an ability check results in denial.
///
/// This is a convenience event for listening specifically to denied access.
class GateAccessDenied extends MagicEvent {
  /// The ability that was denied.
  final String ability;

  /// The arguments passed to the check.
  final dynamic arguments;

  /// The user who was denied (null if guest).
  final Model? user;

  GateAccessDenied({
    required this.ability,
    this.arguments,
    this.user,
  });
}

/// Fired when a new ability is defined.
class GateAbilityDefined extends MagicEvent {
  /// The name of the defined ability.
  final String ability;

  GateAbilityDefined(this.ability);
}

/// Fired when Gate.before() callback is registered.
class GateBeforeRegistered extends MagicEvent {
  GateBeforeRegistered();
}
