/// Magic ↔ fluttersdk_dusk integration adapter sub-barrel.
///
/// Import this file when your app uses both magic and fluttersdk_dusk
/// and wants the MagicDuskIntegration enrichers wired into DuskPlugin.
/// Consumers MUST add fluttersdk_dusk to their own pubspec.yaml
/// dependencies; magic ships fluttersdk_dusk as a dev-dependency only,
/// so transitive resolution does not happen through magic itself.
///
/// Host integration (debug-only in lib/main.dart). MagicDuskIntegration
/// MUST run AFTER `Magic.init()` because its enrichers query
/// `Magic.find<X>()` for form / nav / controller state. DuskPlugin
/// itself installs BEFORE `Magic.init()` so the snapshot pipeline is
/// live during Magic boot:
///
/// ```dart
/// if (kDebugMode) {
///   DuskPlugin.install();
/// }
/// await Magic.init(configFactories: [...]);
/// if (kDebugMode) {
///   MagicDuskIntegration.install();
/// }
/// ```
///
/// See `references/magic/lib/src/cli/dusk_integration.dart` for the
/// concrete MagicDuskIntegration class and 14 enrichers.
library;

export 'src/cli/dusk_integration.dart';
