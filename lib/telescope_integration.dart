/// Magic ↔ fluttersdk_telescope integration adapter sub-barrel.
///
/// Import this file when your app uses both magic and fluttersdk_telescope
/// and wants the MagicTelescopeIntegration watchers wired into TelescopePlugin.
/// Consumers MUST add fluttersdk_telescope to their own pubspec.yaml
/// dependencies; magic ships fluttersdk_telescope as a dev-dependency only,
/// so transitive resolution does not happen through magic itself.
///
/// Host integration (debug-only in lib/main.dart). MagicTelescopeIntegration
/// MUST run AFTER `Magic.init()` because MagicHttpFacadeAdapter resolves
/// the NetworkDriver via the IoC container. TelescopePlugin itself
/// installs BEFORE `Magic.init()` so ExceptionWatcher catches Magic
/// boot errors:
///
/// ```dart
/// if (kDebugMode) {
///   TelescopePlugin.install();
/// }
/// await Magic.init(configFactories: [...]);
/// if (kDebugMode) {
///   MagicTelescopeIntegration.install();
/// }
/// ```
///
/// See `references/magic/lib/src/cli/telescope_integration.dart` for the
/// concrete MagicTelescopeIntegration class, 5 watchers, and
/// MagicHttpFacadeAdapter.
library;

export 'src/cli/telescope_integration.dart';
