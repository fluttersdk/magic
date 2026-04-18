import '../session/session_store.dart';

/// The Session Facade.
///
/// Provides a Laravel-style flash-data API for surviving navigation: flash
/// input on failed submit, navigate back, repopulate the form with
/// [Session.old] / [Session.error].
///
/// ```dart
/// // On failed submit:
/// Session.flash(form.data);
/// Session.flashErrors({'email': ['Invalid email.']});
/// MagicRoute.back();
///
/// // In the form view:
/// WFormInput(
///   initialValue: Session.old('email') ?? '',
/// );
/// if (Session.hasError('email'))
///   WText(Session.error('email')!, className: 'text-red-500');
/// ```
///
/// Flash data survives exactly one navigation. Call [Session.tick] on every
/// real route change. The router delegate listener can fire for non-navigation
/// events (redirect re-evaluation, notifier rebuilds), so gate the tick on an
/// actual location change:
///
/// ```dart
/// var lastLocation = MagicRouter.instance.currentLocation;
/// MagicRouter.instance.routerConfig.routerDelegate.addListener(() {
///   final currentLocation = MagicRouter.instance.currentLocation;
///   if (currentLocation == lastLocation) return;
///   lastLocation = currentLocation;
///   Session.tick();
/// });
/// ```
class Session {
  Session._();

  static SessionStore _store = SessionStore();

  /// The underlying store. Exposed for testing.
  static SessionStore get store => _store;

  /// Flash input values for the next frame.
  static void flash(Map<String, dynamic> input) => _store.flash(input);

  /// Flash validation errors for the next frame.
  static void flashErrors(Map<String, List<String>> errors) =>
      _store.flashErrors(errors);

  /// Read a flashed input value as a string.
  static String? old(String field, [String? fallback]) =>
      _store.old(field, fallback);

  /// Read a flashed input value in its original type.
  static dynamic oldRaw(String field) => _store.oldRaw(field);

  /// Read the first flashed error for a field.
  static String? error(String field) => _store.error(field);

  /// Read all flashed errors for a field.
  static List<String> errors(String field) => _store.errors(field);

  /// Whether the given field has a flashed error.
  static bool hasError(String field) => _store.hasError(field);

  /// Whether any flashed input or error is readable.
  static bool get hasFlash => _store.hasFlash;

  /// Advance the flash bucket. Call on every navigation.
  static void tick() => _store.tick();

  /// Wipe both buckets. Intended for tests.
  static void reset() => _store.reset();

  /// Swap the underlying store (for testing).
  static void setStore(SessionStore store) {
    _store = store;
  }

  /// Top-level helper equivalent to [old].
  // Kept here to avoid a second public class.
  static String? oldInput(String field, [String? fallback]) =>
      old(field, fallback);
}

/// Top-level helper, mirrors Laravel's `old()`.
///
/// ```dart
/// WFormInput(initialValue: old('email') ?? '');
/// ```
String? old(String field, [String? fallback]) => Session.old(field, fallback);

/// Top-level helper, mirrors Laravel's `$errors->first('field')`.
String? error(String field) => Session.error(field);
