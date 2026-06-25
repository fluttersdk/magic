import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/cli/helpers/design_md_parser.dart';

/// A minimal but complete DESIGN.md fixture used across parser tests.
///
/// Exercises the single-file `dark:` overlay (`surface`), light-only roles
/// (`accent`), `{colors.x}` references inside `components`, and the canonical
/// section order in the markdown body.
const String _fixture = '''
---
name: Test System
colors:
  surface:
    light: "#f9f9ff"
    dark: "#0f1419"
  on-surface:
    light: "#151c27"
    dark: "#e6e9f0"
  primary:
    light: "#7c3aed"
    dark: "#a78bfa"
  on-primary: "#ffffff"
  accent: "#4f46e5"
typography:
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: "400"
    lineHeight: 24px
rounded:
  sm: 4px
  md: 8px
spacing:
  sm: 8px
  md: 16px
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.md}"
    padding: "{spacing.md}"
---

# Test System

## Overview

A test design system.

## Colors

Color guidance.

## Typography

Type guidance.

## Components

Component guidance.
''';

void main() {
  group('DesignMdParser front matter', () {
    test('parses the document name', () {
      final spec = DesignMdParser.parse(_fixture);

      expect(spec.name, 'Test System');
    });

    test('parses a single-file light+dark overlay color role', () {
      final spec = DesignMdParser.parse(_fixture);

      final surface = spec.colors['surface'];
      expect(surface, isNotNull);
      expect(surface!.light, '#f9f9ff');
      expect(surface.dark, '#0f1419');
    });

    test('parses a light-only color role with dark falling back to light', () {
      final spec = DesignMdParser.parse(_fixture);

      final accent = spec.colors['accent'];
      expect(accent, isNotNull);
      expect(accent!.light, '#4f46e5');
      expect(accent.dark, '#4f46e5');
    });

    test('exposes typography, rounded and spacing groups', () {
      final spec = DesignMdParser.parse(_fixture);

      expect(spec.typography.containsKey('body-md'), isTrue);
      expect(spec.rounded['md'], '8px');
      expect(spec.spacing['md'], '16px');
    });

    test('extracts the markdown section headings in document order', () {
      final spec = DesignMdParser.parse(_fixture);

      expect(spec.sections, <String>[
        'Overview',
        'Colors',
        'Typography',
        'Components',
      ]);
    });
  });

  group('DesignMdParser reference resolution', () {
    test('resolves {colors.x} / {rounded.x} / {spacing.x} references', () {
      final spec = DesignMdParser.parse(_fixture);

      final button = spec.components['button-primary']!;
      expect(button.resolved['backgroundColor'], '#7c3aed');
      expect(button.resolved['textColor'], '#ffffff');
      expect(button.resolved['rounded'], '8px');
      expect(button.resolved['padding'], '16px');
      expect(button.unresolvedRefs, isEmpty);
    });

    test('records an unresolved reference rather than throwing', () {
      const broken = '''
---
name: Broken
colors:
  primary: "#7c3aed"
components:
  card:
    backgroundColor: "{colors.does-not-exist}"
---

## Colors
''';
      final spec = DesignMdParser.parse(broken);

      final card = spec.components['card']!;
      expect(card.unresolvedRefs, contains('{colors.does-not-exist}'));
    });

    test('treats a circular reference as unresolved (cycle guard)', () {
      const circular = '''
---
name: Circular
colors:
  a: "{colors.b}"
  b: "{colors.a}"
components:
  card:
    backgroundColor: "{colors.a}"
---

## Colors
''';
      final spec = DesignMdParser.parse(circular);

      expect(spec.components['card']!.unresolvedRefs, isNotEmpty);
    });
  });

  group('DesignMdParser missing front matter', () {
    test('returns an empty spec with a recoverable parse warning', () {
      final spec = DesignMdParser.parse('# No front matter\n\n## Colors\n');

      expect(spec.colors, isEmpty);
      expect(spec.hasFrontMatter, isFalse);
    });
  });

  group('WCAG contrast helper (greenfield)', () {
    test('computes black-on-white at the canonical 21:1 ratio', () {
      final ratio = DesignContrast.ratio('#000000', '#ffffff');

      expect(ratio, closeTo(21.0, 0.01));
    });

    test('white-on-white is 1:1', () {
      expect(DesignContrast.ratio('#ffffff', '#ffffff'), closeTo(1.0, 0.001));
    });

    test('is symmetric regardless of argument order', () {
      final a = DesignContrast.ratio('#7c3aed', '#ffffff');
      final b = DesignContrast.ratio('#ffffff', '#7c3aed');

      expect(a, closeTo(b, 0.0001));
    });

    test('linearizes sRGB channels: mid-gray on white below AA', () {
      // #808080 on white is ~3.95:1, under the 4.5:1 AA threshold.
      final ratio = DesignContrast.ratio('#808080', '#ffffff');

      expect(ratio, lessThan(4.5));
      expect(ratio, greaterThan(3.5));
    });

    test('expands 3-digit shorthand hex', () {
      final long = DesignContrast.ratio('#000000', '#ffffff');
      final short = DesignContrast.ratio('#000', '#fff');

      expect(short, closeTo(long, 0.0001));
    });

    test('returns null on an invalid color', () {
      expect(DesignContrast.relativeLuminance('not-a-color'), isNull);
    });
  });
}
