import 'dart:ui';
import '../../events/magic_event.dart';

/// Fired when the application locale changes.
class LocaleChanged extends MagicEvent {
  /// The new locale.
  final Locale locale;

  LocaleChanged(this.locale);
}

/// Fired when the application has fully booted and all providers are ready.
class AppBooted extends MagicEvent {}
