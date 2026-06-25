import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/cli/commands/design_sync_command.dart';
import 'package:path/path.dart' as p;

/// A clean DESIGN.md covering every semantic role the emitter maps, plus the
/// brand `primary` color the MaterialColor seed is derived from.
const String _design = '''
---
name: Acme
colors:
  surface:
    light: "#f9f9ff"
    dark: "#0f1419"
  surface-container:
    light: "#f0f3ff"
    dark: "#161b22"
  surface-container-high:
    light: "#e2e8f8"
    dark: "#1d242d"
  fg:
    light: "#151c27"
    dark: "#e6e9f0"
  fg-muted:
    light: "#534434"
    dark: "#9aa4b2"
  fg-disabled:
    light: "#867461"
    dark: "#5b6470"
  primary:
    light: "#7c3aed"
    dark: "#a78bfa"
  on-primary: "#ffffff"
  primary-container:
    light: "#ede9fe"
    dark: "#4c1d95"
  accent:
    light: "#4f46e5"
    dark: "#6366f1"
  border:
    light: "#d8c3ad"
    dark: "#30363d"
  border-subtle:
    light: "#e7eefe"
    dark: "#21262d"
  destructive:
    light: "#ba1a1a"
    dark: "#f87171"
  on-destructive: "#ffffff"
  destructive-container:
    light: "#ffdad6"
    dark: "#7f1d1d"
  success:
    light: "#15803d"
    dark: "#22c55e"
  warning:
    light: "#b45309"
    dark: "#f59e0b"
---

## Colors
''';

ArtisanContext _ctx(List<String> args) {
  final parser = ArgParser()
    ..addOption('input')
    ..addOption('output');
  final input = ArgvInput.parse(parser, args);
  return ArtisanContext.bare(input, BufferedOutput());
}

void main() {
  group('DesignSyncCommand metadata', () {
    final cmd = DesignSyncCommand();

    test('declares name design:sync', () {
      expect(cmd.name, 'design:sync');
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });

    test('extends ArtisanCommand', () {
      expect(cmd, isA<ArtisanCommand>());
    });
  });

  group('DesignSyncCommand.handle()', () {
    late Directory root;
    late String inputPath;
    late String outputPath;

    setUp(() {
      root = Directory.systemTemp.createTempSync('design_sync_');
      inputPath = p.join(root.path, 'DESIGN.md');
      outputPath = p.join(root.path, 'lib', 'config', 'wind_theme.g.dart');
      File(inputPath).writeAsStringSync(_design);
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    Future<String> run() async {
      final cmd = DesignSyncCommand(projectRoot: root.path);
      final code = await cmd.handle(
        _ctx(<String>[
          '--input=DESIGN.md',
          '--output=lib/config/wind_theme.g.dart',
        ]),
      );
      expect(code, 0);
      return File(outputPath).readAsStringSync();
    }

    test('emits the 17 property-prefixed alias keys from Step 7', () async {
      final generated = await run();

      const keys = <String>[
        'bg-surface',
        'bg-surface-container',
        'bg-surface-container-high',
        'text-fg',
        'text-fg-muted',
        'text-fg-disabled',
        'bg-primary',
        'text-on-primary',
        'bg-primary-container',
        'bg-accent',
        'border-color-border',
        'border-color-border-subtle',
        'bg-destructive',
        'text-on-destructive',
        'bg-destructive-container',
        'bg-success',
        'bg-warning',
      ];
      for (final key in keys) {
        expect(generated, contains("'$key':"), reason: 'missing alias $key');
      }
    });

    test('emits arbitrary-hex light+dark pairs for a surface role', () async {
      final generated = await run();

      expect(
        generated,
        contains("'bg-surface': 'bg-[#f9f9ff] dark:bg-[#0f1419]'"),
      );
      expect(
        generated,
        contains("'text-fg': 'text-[#151c27] dark:text-[#e6e9f0]'"),
      );
      expect(
        generated,
        contains(
          "'border-color-border': 'border-[#d8c3ad] dark:border-[#30363d]'",
        ),
      );
    });

    test('emits a brand primary MaterialColor with a 50-900 ramp', () async {
      final generated = await run();

      expect(generated, contains('MaterialColor('));
      for (final shade in <int>[
        50,
        100,
        200,
        300,
        400,
        500,
        600,
        700,
        800,
        900,
      ]) {
        expect(generated, contains('$shade:'), reason: 'missing shade $shade');
      }
      // The 500 shade is seeded from the primary light hex (#7c3aed).
      expect(generated, contains('0xFF7C3AED'));
    });

    test('exposes the aliases map and brand color as a public API', () async {
      final generated = await run();

      expect(generated, contains('Map<String, String>'));
      expect(generated, contains("'primary'"));
    });

    test('is idempotent: byte-identical output on re-run', () async {
      final first = await run();
      final second = await run();

      expect(second, first);
    });

    test('writes atomically with no .tmp leftover', () async {
      await run();

      expect(File('$outputPath.tmp').existsSync(), isFalse);
    });
  });
}
