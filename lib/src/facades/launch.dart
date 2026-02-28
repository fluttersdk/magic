import 'package:url_launcher/url_launcher.dart';

import '../foundation/magic.dart';
import '../launch/launch_service.dart';

/// The Launch Facade.
///
/// Provides a context-free, static API for opening URLs, emails, phone calls,
/// and SMS messages via the `url_launcher` package. Register [LaunchServiceProvider]
/// in your app's service providers to enable this facade.
///
/// ## Quick Start
///
/// ```dart
/// // In your ServiceProvider registration:
/// (app) => LaunchServiceProvider(app),
///
/// // Then use anywhere — no BuildContext needed:
/// await Launch.url('https://flutter.dev');
/// await Launch.email('hello@example.com', subject: 'Hello!');
/// await Launch.phone('+1234567890');
/// await Launch.sms('+1234567890', body: 'On my way!');
/// ```
///
/// All methods return `false` on failure and log errors via [Log]. They never throw.
class Launch {
  static LaunchService get _service => Magic.make<LaunchService>('launch');

  /// Opens the given [url] in an external application.
  ///
  /// The [mode] controls how the URL is opened; defaults to
  /// [LaunchMode.externalApplication].
  ///
  /// Returns `true` if the URL was successfully launched, `false` otherwise.
  /// Returns `false` immediately for empty strings without attempting a launch.
  ///
  /// ```dart
  /// final opened = await Launch.url('https://flutter.dev');
  /// final inApp = await Launch.url(
  ///   'https://flutter.dev',
  ///   mode: LaunchMode.inAppWebView,
  /// );
  /// ```
  static Future<bool> url(
    String url, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) =>
      _service.url(url, mode: mode);

  /// Opens the device's email client addressed to [address].
  ///
  /// Optionally pre-fills the [subject] and [body]. Special characters in
  /// both fields are automatically URI-encoded.
  ///
  /// Returns `true` if the email client was opened, `false` otherwise.
  /// Returns `false` immediately for an empty [address].
  ///
  /// ```dart
  /// await Launch.email(
  ///   'support@example.com',
  ///   subject: 'Bug Report',
  ///   body: 'I found an issue...',
  /// );
  /// ```
  static Future<bool> email(
    String address, {
    String? subject,
    String? body,
  }) =>
      _service.email(address, subject: subject, body: body);

  /// Opens the device's phone dialer pre-filled with [number].
  ///
  /// Returns `true` if the dialer was opened, `false` otherwise.
  /// Returns `false` immediately for an empty [number].
  ///
  /// ```dart
  /// await Launch.phone('+1234567890');
  /// ```
  static Future<bool> phone(String number) => _service.phone(number);

  /// Opens the device's SMS app addressed to [number].
  ///
  /// Optionally pre-fills the message [body]. Special characters in [body]
  /// are automatically URI-encoded.
  ///
  /// Returns `true` if the SMS app was opened, `false` otherwise.
  /// Returns `false` immediately for an empty [number].
  ///
  /// ```dart
  /// await Launch.sms('+1234567890', body: 'On my way!');
  /// ```
  static Future<bool> sms(
    String number, {
    String? body,
  }) =>
      _service.sms(number, body: body);

  /// Checks whether the given [url] can be launched on this device.
  ///
  /// Returns `true` if the device can handle the URL, `false` otherwise.
  /// Returns `false` for empty strings and malformed URLs.
  ///
  /// > **Note**: On iOS 9+ and Android 11+, this requires declaring the
  /// > relevant URL schemes in the native app manifest. See the
  /// > `url_launcher` documentation for details.
  ///
  /// ```dart
  /// if (await Launch.canLaunch('tel:+1234567890')) {
  ///   await Launch.phone('+1234567890');
  /// }
  /// ```
  static Future<bool> canLaunch(String url) => _service.canLaunch(url);
}
