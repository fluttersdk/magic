import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:path/path.dart' as p;

import '../helpers/design_md_parser.dart';

/// `design:sync`: regenerates a wind theme source file from a `DESIGN.md`.
///
/// DESIGN.md is the single source of truth for the app theme. This command
/// parses its front-matter color roles (each carrying a single-file `dark:`
/// overlay), maps them onto the 17 property-prefixed wind alias keys (the
/// `MagicStarterTokens.defaultAliases` contract), and emits a Dart source file
/// exposing:
///
/// - a `Map<String, String>` of arbitrary-hex light+dark alias pairs
///   (`'bg-surface': 'bg-[#f9f9ff] dark:bg-[#0f1419]'`), drop-in compatible
///   with `WindThemeData(aliases: ...)`, and
/// - a brand `primary` [MaterialColor] with a generated 50-900 ramp seeded from
///   the DESIGN.md `primary` light hex, for `WindThemeData.toThemeData()`
///   Material interop.
///
/// The emission keys are property-prefixed (`bg-surface`, `text-fg`,
/// `border-color-border`) and NOT bare role names: wind's alias expander only
/// expands a whole unprefixed token that exactly matches an alias key.
///
/// The generated file is written atomically (`.tmp` + rename) and is a pure
/// function of the DESIGN.md, so re-running on an unchanged input is
/// byte-identical (idempotent).
class DesignSyncCommand extends ArtisanCommand {
  /// Creates a [DesignSyncCommand].
  ///
  /// @param projectRoot  Override for project-root resolution; defaults to
  ///                      [FileHelper.findProjectRoot]. Used by tests to run
  ///                      against a temp directory.
  DesignSyncCommand({String? projectRoot}) : _projectRootOverride = projectRoot;

  final String? _projectRootOverride;

  /// DESIGN.md color role name -> (wind alias key, wind utility prefix).
  ///
  /// The order is the stable emission order of the generated alias map. A role
  /// absent from the DESIGN.md is simply skipped (the consumer's
  /// [DesignSyncCommand] does not fabricate values for missing roles).
  static const List<_AliasMapping> _aliasMappings = <_AliasMapping>[
    _AliasMapping('surface', 'bg-surface', 'bg'),
    _AliasMapping('surface-container', 'bg-surface-container', 'bg'),
    _AliasMapping('surface-container-high', 'bg-surface-container-high', 'bg'),
    _AliasMapping('fg', 'text-fg', 'text', altRole: 'on-surface'),
    _AliasMapping('fg-muted', 'text-fg-muted', 'text'),
    _AliasMapping('fg-disabled', 'text-fg-disabled', 'text'),
    _AliasMapping('primary', 'bg-primary', 'bg'),
    _AliasMapping('on-primary', 'text-on-primary', 'text'),
    _AliasMapping('primary-container', 'bg-primary-container', 'bg'),
    _AliasMapping('accent', 'bg-accent', 'bg'),
    _AliasMapping('border', 'border-color-border', 'border'),
    _AliasMapping('border-subtle', 'border-color-border-subtle', 'border'),
    _AliasMapping('destructive', 'bg-destructive', 'bg'),
    _AliasMapping('on-destructive', 'text-on-destructive', 'text'),
    _AliasMapping('destructive-container', 'bg-destructive-container', 'bg'),
    _AliasMapping('success', 'bg-success', 'bg'),
    _AliasMapping('warning', 'bg-warning', 'bg'),
  ];

  @override
  String get signature =>
      'design:sync '
      '{--input=DESIGN.md : Path to the DESIGN.md source, relative to the project root} '
      '{--output=lib/config/wind_theme.g.dart : Path for the generated wind theme file}';

  @override
  String get description =>
      'Generate the wind theme (semantic aliases + brand seed) from DESIGN.md.';

  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  Future<int> handle(ArtisanContext ctx) async {
    // 1. Resolve the input/output paths under the host project root.
    final root = _projectRootOverride ?? FileHelper.findProjectRoot();
    final inputPath = p.join(
      root,
      (ctx.input.option('input') as String?) ?? 'DESIGN.md',
    );
    final outputPath = p.join(
      root,
      (ctx.input.option('output') as String?) ?? 'lib/config/wind_theme.g.dart',
    );

    if (!FileHelper.fileExists(inputPath)) {
      ctx.output.error('DESIGN.md not found at $inputPath.');
      return 1;
    }

    // 2. Parse the DESIGN.md into the shared spec model.
    final spec = DesignMdParser.parse(FileHelper.readFile(inputPath));
    if (!spec.hasFrontMatter) {
      ctx.output.error(
        'DESIGN.md has no parseable YAML front matter; nothing to emit.',
      );
      return 1;
    }
    if (!spec.colors.containsKey('primary')) {
      ctx.output.error(
        "DESIGN.md defines no 'primary' color; a brand seed is required.",
      );
      return 1;
    }

    // 3. Render the theme source (pure function of the spec) and write it
    //    atomically so open editors never observe a partial file.
    final source = _renderTheme(spec);
    final outFile = File(outputPath);
    if (!outFile.parent.existsSync()) {
      outFile.parent.createSync(recursive: true);
    }
    final tmpPath = '$outputPath.tmp';
    File(tmpPath).writeAsStringSync(source);
    File(tmpPath).renameSync(outputPath);

    ctx.output.success(
      'Synced wind theme from ${p.relative(inputPath, from: root)} -> '
      '${p.relative(outputPath, from: root)}',
    );
    return 0;
  }

  /// Renders the generated wind theme Dart source.
  ///
  /// Pure: no I/O, no clock reads, so the output is fully determined by [spec]
  /// (the idempotence guarantee).
  String _renderTheme(DesignSpec spec) {
    final buf = StringBuffer()
      ..writeln('// GENERATED: do not edit by hand.')
      ..writeln('// Regenerate via: dart run magic:artisan design:sync')
      ..writeln('//')
      ..writeln('// Source of truth: DESIGN.md')
      ..writeln()
      ..writeln("import 'package:flutter/material.dart';")
      ..writeln()
      ..writeln('/// Semantic wind alias map generated from DESIGN.md.')
      ..writeln('///')
      ..writeln('/// Drop-in for `WindThemeData(aliases: designAliases)`; the')
      ..writeln('/// keys match the magic_starter token contract.')
      ..writeln('const Map<String, String> designAliases = <String, String>{');

    for (final mapping in _aliasMappings) {
      final color =
          spec.colors[mapping.role] ??
          (mapping.altRole != null ? spec.colors[mapping.altRole!] : null);
      if (color == null) continue;

      final light = '${mapping.prefix}-[${color.light}]';
      final dark = 'dark:${mapping.prefix}-[${color.dark}]';
      buf.writeln("  '${mapping.aliasKey}': '$light $dark',");
    }
    buf
      ..writeln('};')
      ..writeln()
      ..writeln('/// The brand `primary` color with a generated 50-900 ramp.')
      ..writeln('///')
      ..writeln(
        '/// Seeded from the DESIGN.md `primary` light hex; consumed by',
      )
      ..writeln('/// `WindThemeData.toThemeData()` Material interop.')
      ..writeln('final Map<String, MaterialColor> designColors =');

    final primary = spec.colors['primary']!.light;
    buf
      ..writeln('    <String, MaterialColor>{')
      ..writeln("  'primary': ${_renderMaterialColor(primary)},")
      ..writeln('};');

    return buf.toString();
  }

  /// Renders a [MaterialColor] literal with a 50-900 ramp generated from the
  /// seed [hex], mirroring the ramp shape used by the starter install command.
  String _renderMaterialColor(String hex) {
    final rgb = _hexToRgb(hex);
    final seed = 0xFF000000 | (rgb[0] << 16) | (rgb[1] << 8) | rgb[2];

    // Tint towards white for light shades, shade towards black for dark ones.
    // 500 is the seed itself; this keeps the brand hue recognizable across the
    // ramp without depending on a color-science package.
    const ramp = <int, double>{
      50: 0.92,
      100: 0.84,
      200: 0.66,
      300: 0.48,
      400: 0.26,
      500: 0.0,
      600: -0.12,
      700: -0.24,
      800: -0.36,
      900: -0.48,
    };

    final buf = StringBuffer()
      ..writeln('MaterialColor(')
      ..writeln(
        '    0x${seed.toRadixString(16).toUpperCase().padLeft(8, '0')},',
      )
      ..writeln('    <int, Color>{');
    for (final entry in ramp.entries) {
      final shade = _applyTint(rgb, entry.value);
      final argb = 0xFF000000 | (shade[0] << 16) | (shade[1] << 8) | shade[2];
      buf.writeln(
        '      ${entry.key}: Color(0x${argb.toRadixString(16).toUpperCase().padLeft(8, '0')}),',
      );
    }
    buf.write('    })');
    return buf.toString();
  }

  /// Tints [rgb] towards white (positive [factor]) or black (negative).
  List<int> _applyTint(List<int> rgb, double factor) {
    int channel(int c) {
      if (factor >= 0) {
        return (c + (255 - c) * factor).round().clamp(0, 255);
      }
      return (c * (1 + factor)).round().clamp(0, 255);
    }

    return <int>[channel(rgb[0]), channel(rgb[1]), channel(rgb[2])];
  }

  /// Parses a `#RGB` / `#RRGGBB` string into `[r, g, b]`; defaults to black on
  /// a malformed value (the lint pass is responsible for rejecting bad hex).
  List<int> _hexToRgb(String hex) {
    var body = hex.trim().toLowerCase().replaceFirst('#', '');
    if (body.length == 3) {
      body = '${body[0]}${body[0]}${body[1]}${body[1]}${body[2]}${body[2]}';
    }
    if (body.length != 6 || !RegExp(r'^[0-9a-f]{6}$').hasMatch(body)) {
      return <int>[0, 0, 0];
    }
    return <int>[
      int.parse(body.substring(0, 2), radix: 16),
      int.parse(body.substring(2, 4), radix: 16),
      int.parse(body.substring(4, 6), radix: 16),
    ];
  }
}

/// Maps a DESIGN.md color role onto a wind alias key + utility prefix.
class _AliasMapping {
  const _AliasMapping(this.role, this.aliasKey, this.prefix, {this.altRole});

  /// The DESIGN.md role name (e.g. `surface`).
  final String role;

  /// An alternative role name accepted when [role] is absent (e.g. `on-surface`
  /// satisfies the `text-fg` key).
  final String? altRole;

  /// The wind alias key (e.g. `bg-surface`).
  final String aliasKey;

  /// The wind utility prefix used for both the light and `dark:` token
  /// (`bg`, `text`, or `border`).
  final String prefix;
}
