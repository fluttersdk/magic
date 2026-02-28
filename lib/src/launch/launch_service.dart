import 'package:url_launcher/url_launcher.dart';

import '../facades/log.dart';
import 'launch_adapter.dart';

/// Service for launching URLs, emails, phone calls, and SMS.
///
/// This service provides a clean, testable API over the `url_launcher` package,
/// automatically handling URI parsing, error catching, and logging.
class LaunchService {
  final LaunchAdapter _adapter;

  /// Creates a new launch service instance.
  ///
  /// Defaults to using [DefaultLaunchAdapter] if no adapter is provided.
  LaunchService({LaunchAdapter? adapter})
      : _adapter = adapter ?? DefaultLaunchAdapter();

  /// Launches a URL using the specified mode.
  ///
  /// Returns `true` if the URL was successfully launched, `false` otherwise.
  /// Any errors during URI parsing or launching are caught and logged.
  ///
  /// [mode] determines how the URL is opened. Defaults to [LaunchMode.externalApplication].
  Future<bool> url(
    String url, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    if (url.trim().isEmpty) {
      return false;
    }

    try {
      final uri = Uri.parse(url);
      return await _adapter.launch(uri, mode: mode);
    } on FormatException catch (e) {
      Log.error('Invalid URL format: $url', e);
      return false;
    } catch (e) {
      Log.error('Launch failed: $url', e);
      return false;
    }
  }

  /// Launches an email client to send an email.
  ///
  /// Returns `true` if the email client was successfully opened, `false` otherwise.
  ///
  /// [address] is the recipient's email address.
  /// [subject] and [body] are optional and will be pre-filled in the email.
  Future<bool> email(
    String address, {
    String? subject,
    String? body,
  }) async {
    if (address.trim().isEmpty) {
      return false;
    }

    try {
      final queryParameters = <String, String>{
        if (subject != null) 'subject': subject,
        if (body != null) 'body': body,
      };

      final uri = Uri(
        scheme: 'mailto',
        path: address,
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
      );

      return await _adapter.launch(uri);
    } catch (e) {
      Log.error('Launch failed for email: $address', e);
      return false;
    }
  }

  /// Launches the device's phone dialer.
  ///
  /// Returns `true` if the dialer was successfully opened, `false` otherwise.
  ///
  /// [number] is the phone number to dial.
  Future<bool> phone(String number) async {
    if (number.trim().isEmpty) {
      return false;
    }

    try {
      final uri = Uri(
        scheme: 'tel',
        path: number,
      );

      return await _adapter.launch(uri);
    } catch (e) {
      Log.error('Launch failed for phone: $number', e);
      return false;
    }
  }

  /// Launches the device's SMS messaging app.
  ///
  /// Returns `true` if the SMS app was successfully opened, `false` otherwise.
  ///
  /// [number] is the recipient's phone number.
  /// [body] is optional and will be pre-filled in the message.
  Future<bool> sms(
    String number, {
    String? body,
  }) async {
    if (number.trim().isEmpty) {
      return false;
    }

    try {
      final uri = Uri(
        scheme: 'sms',
        path: number,
        queryParameters: body != null ? <String, String>{'body': body} : null,
      );

      return await _adapter.launch(uri);
    } catch (e) {
      Log.error('Launch failed for sms: $number', e);
      return false;
    }
  }

  /// Checks if a URL can be launched.
  ///
  /// Returns `true` if the URL can be handled by the device, `false` otherwise.
  Future<bool> canLaunch(String url) async {
    if (url.trim().isEmpty) {
      return false;
    }

    try {
      final uri = Uri.parse(url);
      return await _adapter.canLaunch(uri);
    } on FormatException catch (e) {
      Log.error('Invalid URL format: $url', e);
      return false;
    } catch (e) {
      Log.error('Launch failed: $url', e);
      return false;
    }
  }
}
