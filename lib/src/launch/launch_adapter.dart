import 'package:url_launcher/url_launcher.dart';

/// The Launch Adapter contract.
///
/// This contract defines the interface for URL launching operations.
/// It is used to decouple the framework from the `url_launcher` package,
/// allowing for easier testing and alternative implementations.
abstract class LaunchAdapter {
  /// Launch the given [url].
  ///
  /// Returns `true` if the launch was successful, `false` otherwise.
  ///
  /// The [mode] parameter determines how the URL is opened.
  /// Defaults to [LaunchMode.externalApplication].
  Future<bool> launch(
    Uri url, {
    LaunchMode mode = LaunchMode.externalApplication,
  });

  /// Check if the given [url] can be launched.
  ///
  /// Returns `true` if the URL can be launched, `false` otherwise.
  Future<bool> canLaunch(Uri url);
}

/// Default implementation of the [LaunchAdapter] using `url_launcher`.
///
/// This implementation delegates all calls to the `url_launcher` package.
class DefaultLaunchAdapter implements LaunchAdapter {
  /// Launches the given [url] using the specified [mode].
  ///
  /// Returns `true` if the launch was successful, `false` otherwise.
  @override
  Future<bool> launch(
    Uri url, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) =>
      launchUrl(
        url,
        mode: mode,
      );

  /// Checks whether the given [url] can be launched on this device.
  ///
  /// Returns `true` if the URL can be handled, `false` otherwise.
  @override
  Future<bool> canLaunch(Uri url) => canLaunchUrl(url);
}
