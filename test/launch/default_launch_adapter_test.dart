import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/launch/launch_adapter.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Records what `url_launcher` hands the platform instead of opening it.
class _RecordingPlatform extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final List<(String, LaunchOptions)> launched = <(String, LaunchOptions)>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add((url, options));

    return true;
  }
}

void main() {
  late UrlLauncherPlatform original;
  late _RecordingPlatform platform;

  setUp(() {
    original = UrlLauncherPlatform.instance;
    platform = _RecordingPlatform();
    UrlLauncherPlatform.instance = platform;
  });

  tearDown(() => UrlLauncherPlatform.instance = original);

  test('hands the web window name and the mode to url_launcher', () async {
    final opened = await DefaultLaunchAdapter().launch(
      Uri.parse('https://flutter.dev/file.pdf'),
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_self',
    );

    expect(opened, isTrue);
    expect(platform.launched.single.$1, 'https://flutter.dev/file.pdf');
    expect(platform.launched.single.$2.webOnlyWindowName, '_self');
    expect(
      platform.launched.single.$2.mode,
      PreferredLaunchMode.platformDefault,
    );
  });

  test('leaves the web window name unset by default', () async {
    await DefaultLaunchAdapter().launch(Uri.parse('https://flutter.dev'));

    expect(platform.launched.single.$2.webOnlyWindowName, isNull);
  });
}
