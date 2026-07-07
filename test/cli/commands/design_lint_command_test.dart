import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/cli/commands/design_lint_command.dart';
import 'package:path/path.dart' as p;

/// A clean, well-ordered DESIGN.md that the linter must pass (exit 0), with the
/// single-file `dark:` overlay accepted (never flagged as an unknown key) and a
/// high-contrast component pair.
const String _clean = '''
---
name: Acme
colors:
  primary:
    light: "#5b21b6"
    dark: "#a78bfa"
  on-primary: "#ffffff"
  surface:
    light: "#f9f9ff"
    dark: "#0f1419"
typography:
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
rounded:
  md: 8px
spacing:
  md: 16px
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.md}"
    padding: "{spacing.md}"
---

## Overview

Acme system.

## Colors

Colors.

## Typography

Type.

## Layout

Layout.

## Components

Components.
''';

ArtisanContext _ctx(BufferedOutput output, List<String> args) {
  final parser = ArgParser()..addOption('input');
  final input = ArgvInput.parse(parser, args);
  return ArtisanContext.bare(input, output);
}

void main() {
  group('DesignLintCommand metadata', () {
    final cmd = DesignLintCommand();

    test('declares name design:lint', () {
      expect(cmd.name, 'design:lint');
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });
  });

  group('DesignLintCommand.handle()', () {
    late Directory root;
    late BufferedOutput output;

    setUp(() {
      root = Directory.systemTemp.createTempSync('design_lint_');
      output = BufferedOutput();
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    Future<int> lint(String content) {
      File(p.join(root.path, 'DESIGN.md')).writeAsStringSync(content);
      final cmd = DesignLintCommand(projectRoot: root.path);
      return cmd.handle(_ctx(output, <String>['--input=DESIGN.md']));
    }

    test('passes a clean file with the dark: overlay accepted', () async {
      final code = await lint(_clean);

      expect(code, 0);
      // The dark: overlay key must NOT trigger an unknown-key finding.
      expect(output.content, isNot(contains('Unknown key')));
    });

    test('flags a broken reference as an error and exits nonzero', () async {
      const broken = '''
---
name: Acme
colors:
  primary: "#5b21b6"
components:
  card:
    backgroundColor: "{colors.does-not-exist}"
---

## Colors
''';
      final code = await lint(broken);

      expect(code, isNot(0));
      expect(output.content, contains('does-not-exist'));
    });

    test('flags a WCAG contrast failure on a component bg/text pair', () async {
      const lowContrast = '''
---
name: Acme
colors:
  primary: "#aaaaaa"
  on-primary: "#cccccc"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
---

## Colors
''';
      await lint(lowContrast);

      expect(output.content.toLowerCase(), contains('contrast'));
    });

    test('warns when the primary color is missing', () async {
      const noPrimary = '''
---
name: Acme
colors:
  surface: "#f9f9ff"
---

## Colors
''';
      await lint(noPrimary);

      expect(output.content.toLowerCase(), contains('primary'));
    });

    test('warns on a top-level key that is a typo of a schema key', () async {
      const typo = '''
---
name: Acme
colers:
  primary: "#5b21b6"
---

## Colors
''';
      await lint(typo);

      expect(output.content, contains('colers'));
    });

    test('warns when sections appear out of canonical order', () async {
      const outOfOrder = '''
---
name: Acme
colors:
  primary: "#5b21b6"
---

## Typography

Type.

## Colors

Colors.
''';
      await lint(outOfOrder);

      expect(output.content.toLowerCase(), contains('order'));
    });

    test('flags an orphaned custom token never referenced', () async {
      const orphan = '''
---
name: Acme
colors:
  primary: "#5b21b6"
  on-primary: "#ffffff"
  brand-magenta: "#ff00ff"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
---

## Colors
''';
      await lint(orphan);

      expect(output.content, contains('brand-magenta'));
    });
  });
}
