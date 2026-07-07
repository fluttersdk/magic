import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/cli/commands/previews_refresh_command.dart';
import 'package:magic/src/cli/helpers/previews_index_writer.dart';
import 'package:path/path.dart' as p;

/// Seeds a `*.preview.dart` source file under [dir] declaring [className].
///
/// The body is irrelevant to discovery; only the public class declaration is
/// matched, so a minimal stateless shell is enough.
void _seedPreview(Directory dir, String fileName, String className) {
  final file = File(p.join(dir.path, fileName));
  file.writeAsStringSync('''
import 'package:flutter/widgets.dart';

class $className extends StatelessWidget {
  const $className({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
''');
}

/// A bare [ArtisanContext] with a buffered output for assertions.
ArtisanContext _ctx(List<String> args) {
  final parser = ArgParser()..addOption('path');
  final input = ArgvInput.parse(parser, args);
  return ArtisanContext.bare(input, BufferedOutput());
}

void main() {
  group('PreviewsRefreshCommand metadata', () {
    final cmd = PreviewsRefreshCommand();

    test('declares name previews:refresh', () {
      expect(cmd.name, 'previews:refresh');
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });

    test('description mentions _previews.g.dart', () {
      expect(cmd.description, contains('_previews.g.dart'));
    });

    test('extends ArtisanCommand', () {
      expect(cmd, isA<ArtisanCommand>());
    });
  });

  group('discoverPreviews', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('previews_discover_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('discovers public *Preview classes in *.preview.dart files', () {
      _seedPreview(tempDir, 'button.preview.dart', 'ButtonPreview');
      _seedPreview(tempDir, 'card.preview.dart', 'CardPreview');

      final discovered = discoverPreviews(tempDir);

      expect(
        discovered.map((e) => e.className),
        containsAll(<String>['ButtonPreview', 'CardPreview']),
      );
    });

    test('ignores files that are not *.preview.dart', () {
      _seedPreview(tempDir, 'button.preview.dart', 'ButtonPreview');
      File(
        p.join(tempDir.path, 'button.dart'),
      ).writeAsStringSync('class Button {}');

      final discovered = discoverPreviews(tempDir);

      expect(discovered, hasLength(1));
      expect(discovered.single.className, 'ButtonPreview');
    });

    test('ignores private _State classes inside a stateful preview', () {
      File(p.join(tempDir.path, 'toggle.preview.dart')).writeAsStringSync('''
import 'package:flutter/widgets.dart';

class TogglePreview extends StatefulWidget {
  const TogglePreview({super.key});
  @override
  State<TogglePreview> createState() => _TogglePreviewState();
}

class _TogglePreviewState extends State<TogglePreview> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
''');

      final discovered = discoverPreviews(tempDir);

      expect(discovered, hasLength(1));
      expect(discovered.single.className, 'TogglePreview');
    });

    test('derives a snake_case slug from the class name minus Preview', () {
      _seedPreview(
        tempDir,
        'segmented_control.preview.dart',
        'SegmentedControlPreview',
      );

      final discovered = discoverPreviews(tempDir);

      expect(discovered.single.slug, 'segmented_control');
      expect(discovered.single.label, 'SegmentedControl');
    });

    test('returns entries sorted deterministically by slug', () {
      _seedPreview(tempDir, 'zebra.preview.dart', 'ZebraPreview');
      _seedPreview(tempDir, 'alpha.preview.dart', 'AlphaPreview');
      _seedPreview(tempDir, 'mid.preview.dart', 'MidPreview');

      final discovered = discoverPreviews(tempDir);

      expect(discovered.map((e) => e.slug).toList(), <String>[
        'alpha',
        'mid',
        'zebra',
      ]);
    });

    test('throws on a file declaring more than one public preview class', () {
      File(p.join(tempDir.path, 'multi.preview.dart')).writeAsStringSync('''
import 'package:flutter/widgets.dart';

class OnePreview extends StatelessWidget {
  const OnePreview({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class TwoPreview extends StatelessWidget {
  const TwoPreview({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
''');

      expect(() => discoverPreviews(tempDir), throwsA(isA<FormatException>()));
    });

    test('throws on two files claiming the same slug', () {
      final nested = Directory(p.join(tempDir.path, 'nested'))..createSync();
      _seedPreview(tempDir, 'button.preview.dart', 'ButtonPreview');
      _seedPreview(nested, 'button.preview.dart', 'ButtonPreview');

      expect(() => discoverPreviews(tempDir), throwsA(isA<FormatException>()));
    });
  });

  group('renderPreviewsIndex', () {
    test(
      'emits a function returning List<PreviewEntry>, never a const list',
      () {
        final entries = <DiscoveredPreview>[
          const DiscoveredPreview(
            className: 'ButtonPreview',
            slug: 'button',
            label: 'Button',
            importPath: 'ui/components/button/button.preview.dart',
          ),
        ];

        final source = renderPreviewsIndex(entries);

        expect(source, contains('List<PreviewEntry> previewEntries()'));
        expect(source, isNot(contains('const List<PreviewEntry>')));
        expect(
          source,
          contains("import 'package:magic_devtools/preview.dart';"),
        );
        expect(source, contains('builder: (_) => const ButtonPreview()'));
        expect(source, contains("slug: 'button'"));
        expect(source, contains("label: 'Button'"));
        expect(
          source,
          contains("import 'ui/components/button/button.preview.dart';"),
        );
      },
    );

    test('emits an empty function body for no previews', () {
      final source = renderPreviewsIndex(const <DiscoveredPreview>[]);

      expect(source, contains('List<PreviewEntry> previewEntries()'));
      expect(source, contains('return <PreviewEntry>[];'));
    });
  });

  group('PreviewsRefreshCommand.handle()', () {
    late Directory projectRoot;
    late Directory previewsDir;

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('previews_refresh_');
      previewsDir = Directory(p.join(projectRoot.path, 'lib'))
        ..createSync(recursive: true);
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    test('generates lib/_previews.g.dart from discovered previews', () async {
      _seedPreview(previewsDir, 'button.preview.dart', 'ButtonPreview');

      final cmd = PreviewsRefreshCommand(projectRoot: projectRoot.path);
      final code = await cmd.handle(_ctx(const <String>[]));

      expect(code, 0);
      final generated = File(
        p.join(previewsDir.path, '_previews.g.dart'),
      ).readAsStringSync();
      expect(generated, contains('previewEntries()'));
      expect(generated, contains('ButtonPreview'));
    });

    test('is idempotent: byte-identical _previews.g.dart on re-run', () async {
      _seedPreview(previewsDir, 'button.preview.dart', 'ButtonPreview');
      _seedPreview(previewsDir, 'card.preview.dart', 'CardPreview');

      final outputPath = p.join(previewsDir.path, '_previews.g.dart');

      await PreviewsRefreshCommand(
        projectRoot: projectRoot.path,
      ).handle(_ctx(const <String>[]));
      final first = File(outputPath).readAsStringSync();

      await PreviewsRefreshCommand(
        projectRoot: projectRoot.path,
      ).handle(_ctx(const <String>[]));
      final second = File(outputPath).readAsStringSync();

      expect(second, first);
    });

    test('writes atomically with no .tmp leftover', () async {
      _seedPreview(previewsDir, 'button.preview.dart', 'ButtonPreview');

      await PreviewsRefreshCommand(
        projectRoot: projectRoot.path,
      ).handle(_ctx(const <String>[]));

      expect(
        File(p.join(previewsDir.path, '_previews.g.dart.tmp')).existsSync(),
        isFalse,
      );
    });

    test('honours the --path option for the scan target', () async {
      final components = Directory(p.join(projectRoot.path, 'lib', 'ui'))
        ..createSync(recursive: true);
      _seedPreview(components, 'badge.preview.dart', 'BadgePreview');

      final cmd = PreviewsRefreshCommand(projectRoot: projectRoot.path);
      final code = await cmd.handle(_ctx(const <String>['--path=lib/ui']));

      expect(code, 0);
      final generated = File(
        p.join(components.path, '_previews.g.dart'),
      ).readAsStringSync();
      expect(generated, contains('BadgePreview'));
    });

    test('computes the import path relative to the generated file', () async {
      final nested = Directory(p.join(previewsDir.path, 'components', 'button'))
        ..createSync(recursive: true);
      _seedPreview(nested, 'button.preview.dart', 'ButtonPreview');

      await PreviewsRefreshCommand(
        projectRoot: projectRoot.path,
      ).handle(_ctx(const <String>[]));

      final generated = File(
        p.join(previewsDir.path, '_previews.g.dart'),
      ).readAsStringSync();
      expect(
        generated,
        contains("import 'components/button/button.preview.dart';"),
      );
    });

    test('fails fast on a slug collision', () async {
      final nested = Directory(p.join(previewsDir.path, 'nested'))
        ..createSync(recursive: true);
      _seedPreview(previewsDir, 'button.preview.dart', 'ButtonPreview');
      _seedPreview(nested, 'button.preview.dart', 'ButtonPreview');

      final cmd = PreviewsRefreshCommand(projectRoot: projectRoot.path);

      expect(
        () => cmd.handle(_ctx(const <String>[])),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
