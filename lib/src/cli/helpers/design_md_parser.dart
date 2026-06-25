import 'dart:math' as math;

import 'package:yaml/yaml.dart';

/// A single color role resolved into its light and dark sRGB hex values.
///
/// DESIGN.md models dark mode as a single-file overlay: a role is either a bare
/// hex scalar (light only, [dark] mirrors [light]) or a `{ light, dark }` map.
/// This diverges from the upstream Google design.md format, which has no
/// in-file dark overlay; the divergence is the deliberate "wind-flavored
/// superset" that lets one DESIGN.md drive a wind light+dark alias map.
class DesignColor {
  /// Creates a color role with explicit light and dark hex values.
  const DesignColor({required this.light, required this.dark});

  /// The light-mode sRGB hex value (e.g. `#f9f9ff`).
  final String light;

  /// The dark-mode sRGB hex value (e.g. `#0f1419`); equals [light] when the
  /// role declared no overlay.
  final String dark;
}

/// A component token group with its references already resolved.
class DesignComponent {
  /// Creates a component from its [resolved] sub-token values and the set of
  /// references that could not be resolved.
  const DesignComponent({required this.resolved, required this.unresolvedRefs});

  /// Sub-token name to its resolved literal value (references followed to the
  /// underlying primitive). An unresolved reference is omitted from this map
  /// and recorded in [unresolvedRefs].
  final Map<String, String> resolved;

  /// The raw `{...}` reference strings that did not resolve (broken or
  /// circular). Empty when every reference resolved.
  final List<String> unresolvedRefs;
}

/// The parsed, fully-resolved DESIGN.md model.
///
/// Pure data: both `design:sync` (emission) and `design:lint` (validation)
/// consume this single representation so the two commands never drift on what
/// a DESIGN.md means.
class DesignSpec {
  /// Creates a design spec.
  const DesignSpec({
    required this.name,
    required this.hasFrontMatter,
    required this.colors,
    required this.typography,
    required this.rounded,
    required this.spacing,
    required this.components,
    required this.sections,
    required this.unknownTopLevelKeys,
    required this.parseWarning,
  });

  /// The `name` front-matter field, or an empty string when absent.
  final String name;

  /// Whether a YAML front-matter block was present and parsed.
  final bool hasFrontMatter;

  /// Color roles keyed by their DESIGN.md role name (`surface`, `primary`...).
  final Map<String, DesignColor> colors;

  /// Typography groups keyed by level name; each is a property map.
  final Map<String, Map<String, String>> typography;

  /// Corner-radius scale keyed by level name (`sm`, `md`, ...).
  final Map<String, String> rounded;

  /// Spacing scale keyed by level name.
  final Map<String, String> spacing;

  /// Component token groups keyed by component name.
  final Map<String, DesignComponent> components;

  /// Markdown `##` section headings in document order.
  final List<String> sections;

  /// Top-level YAML keys that are not part of the schema (used by the
  /// unknown-key lint rule). The `dark:` overlay lives inside `colors`, so it
  /// never surfaces here.
  final List<String> unknownTopLevelKeys;

  /// A recoverable parse warning (e.g. missing front matter), or null.
  final String? parseWarning;
}

/// Parses a DESIGN.md document into a [DesignSpec].
///
/// Parsing is total: malformed references, missing front matter, and circular
/// references never throw; they surface as [DesignComponent.unresolvedRefs] or
/// [DesignSpec.parseWarning] so the linter can report them as findings.
class DesignMdParser {
  DesignMdParser._();

  /// Canonical top-level YAML keys per the DESIGN.md schema.
  static const List<String> schemaKeys = <String>[
    'version',
    'name',
    'description',
    'colors',
    'typography',
    'rounded',
    'spacing',
    'components',
  ];

  /// Maximum reference-chain depth before a reference is treated as unresolved.
  static const int _maxReferenceDepth = 10;

  /// Matches a `{group.token}` reference.
  static final RegExp _referencePattern = RegExp(r'^\{([a-zA-Z0-9_.-]+)\}$');

  /// Parses [content] into a [DesignSpec].
  ///
  /// @param content  The raw DESIGN.md text (YAML front matter + markdown).
  /// @return The fully-resolved spec.
  static DesignSpec parse(String content) {
    // 1. Split the front matter from the markdown body.
    final frontMatter = _extractFrontMatter(content);
    final sections = _extractSections(content);

    if (frontMatter == null) {
      return DesignSpec(
        name: '',
        hasFrontMatter: false,
        colors: const <String, DesignColor>{},
        typography: const <String, Map<String, String>>{},
        rounded: const <String, String>{},
        spacing: const <String, String>{},
        components: const <String, DesignComponent>{},
        sections: sections,
        unknownTopLevelKeys: const <String>[],
        parseWarning:
            'No YAML front matter found. Design tokens cannot be validated.',
      );
    }

    final yaml = loadYaml(frontMatter);
    if (yaml is! YamlMap) {
      return DesignSpec(
        name: '',
        hasFrontMatter: false,
        colors: const <String, DesignColor>{},
        typography: const <String, Map<String, String>>{},
        rounded: const <String, String>{},
        spacing: const <String, String>{},
        components: const <String, DesignComponent>{},
        sections: sections,
        unknownTopLevelKeys: const <String>[],
        parseWarning: 'Front matter is not a YAML mapping.',
      );
    }

    // 2. Map the typed token groups.
    final colors = _parseColors(yaml['colors']);
    final typography = _parseTypography(yaml['typography']);
    final rounded = _parseDimensionMap(yaml['rounded']);
    final spacing = _parseDimensionMap(yaml['spacing']);

    // 3. Build the symbol table for reference resolution, then resolve every
    //    component sub-token against it.
    final symbols = _buildSymbolTable(colors, rounded, spacing);
    final components = _parseComponents(yaml['components'], symbols);

    // 4. Collect unknown top-level keys for the unknown-key rule.
    final unknownKeys = <String>[
      for (final key in yaml.keys)
        if (key is String && !schemaKeys.contains(key)) key,
    ];

    return DesignSpec(
      name: (yaml['name'] as String?) ?? '',
      hasFrontMatter: true,
      colors: colors,
      typography: typography,
      rounded: rounded,
      spacing: spacing,
      components: components,
      sections: sections,
      unknownTopLevelKeys: unknownKeys,
      parseWarning: null,
    );
  }

  /// Extracts the YAML front-matter block delimited by leading/trailing `---`.
  static String? _extractFrontMatter(String content) {
    final lines = content.split('\n');
    if (lines.isEmpty || lines.first.trim() != '---') return null;

    final buffer = StringBuffer();
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        return buffer.toString();
      }
      buffer.writeln(lines[i]);
    }
    return null;
  }

  /// Extracts `##` section headings in document order, skipping any heading
  /// inside the front-matter block.
  static List<String> _extractSections(String content) {
    final lines = content.split('\n');
    final headings = <String>[];
    var inFrontMatter = false;
    var seenFirstDelimiter = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == '---' && !seenFirstDelimiter && headings.isEmpty) {
        inFrontMatter = !inFrontMatter;
        seenFirstDelimiter = false;
        continue;
      }
      if (trimmed == '---' && inFrontMatter) {
        inFrontMatter = false;
        continue;
      }
      if (inFrontMatter) continue;

      final match = RegExp(r'^##\s+(.+)$').firstMatch(line);
      if (match != null) headings.add(match.group(1)!.trim());
    }
    return headings;
  }

  /// Parses the `colors` group, accepting either a bare hex scalar (light only)
  /// or a `{ light, dark }` overlay map per role.
  static Map<String, DesignColor> _parseColors(dynamic node) {
    if (node is! YamlMap) return const <String, DesignColor>{};

    final result = <String, DesignColor>{};
    for (final entry in node.entries) {
      final key = entry.key;
      if (key is! String) continue;
      final value = entry.value;

      if (value is String) {
        result[key] = DesignColor(light: value, dark: value);
        continue;
      }
      if (value is YamlMap) {
        final light = (value['light'] ?? value['default']) as String?;
        final dark = (value['dark'] ?? light) as String?;
        if (light == null) continue;
        result[key] = DesignColor(light: light, dark: dark ?? light);
      }
    }
    return result;
  }

  /// Parses the `typography` group into a name -> property-map structure.
  static Map<String, Map<String, String>> _parseTypography(dynamic node) {
    if (node is! YamlMap) return const <String, Map<String, String>>{};

    final result = <String, Map<String, String>>{};
    for (final entry in node.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || value is! YamlMap) continue;

      final props = <String, String>{};
      for (final prop in value.entries) {
        if (prop.key is String) {
          props[prop.key as String] = prop.value.toString();
        }
      }
      result[key] = props;
    }
    return result;
  }

  /// Parses a flat `name -> dimension` group (`rounded`, `spacing`).
  static Map<String, String> _parseDimensionMap(dynamic node) {
    if (node is! YamlMap) return const <String, String>{};

    final result = <String, String>{};
    for (final entry in node.entries) {
      if (entry.key is String) {
        result[entry.key as String] = entry.value.toString();
      }
    }
    return result;
  }

  /// Builds the dotted-path symbol table (`colors.primary`, `rounded.md`, ...)
  /// against which component references resolve.
  static Map<String, String> _buildSymbolTable(
    Map<String, DesignColor> colors,
    Map<String, String> rounded,
    Map<String, String> spacing,
  ) {
    final symbols = <String, String>{};
    for (final entry in colors.entries) {
      // References resolve to the light value; dark is carried separately into
      // the alias map by the emitter, not through the reference graph.
      symbols['colors.${entry.key}'] = entry.value.light;
    }
    for (final entry in rounded.entries) {
      symbols['rounded.${entry.key}'] = entry.value;
    }
    for (final entry in spacing.entries) {
      symbols['spacing.${entry.key}'] = entry.value;
    }
    return symbols;
  }

  /// Parses the `components` group and resolves each sub-token reference.
  static Map<String, DesignComponent> _parseComponents(
    dynamic node,
    Map<String, String> symbols,
  ) {
    if (node is! YamlMap) return const <String, DesignComponent>{};

    final result = <String, DesignComponent>{};
    for (final entry in node.entries) {
      final name = entry.key;
      final body = entry.value;
      if (name is! String || body is! YamlMap) continue;

      final resolved = <String, String>{};
      final unresolved = <String>[];
      for (final prop in body.entries) {
        final propName = prop.key;
        if (propName is! String) continue;
        final raw = prop.value.toString();

        final match = _referencePattern.firstMatch(raw);
        if (match == null) {
          resolved[propName] = raw;
          continue;
        }

        final value = _resolveReference(
          symbols,
          match.group(1)!,
          <String>{},
          0,
        );
        if (value == null) {
          unresolved.add(raw);
        } else {
          resolved[propName] = value;
        }
      }
      result[name] = DesignComponent(
        resolved: resolved,
        unresolvedRefs: unresolved,
      );
    }
    return result;
  }

  /// Resolves a `group.token` path with chained resolution and cycle detection.
  /// Returns null when the path is missing, circular, or exceeds the depth cap.
  static String? _resolveReference(
    Map<String, String> symbols,
    String path,
    Set<String> visited,
    int depth,
  ) {
    if (depth > _maxReferenceDepth) return null;
    if (visited.contains(path)) return null;
    visited.add(path);

    final value = symbols[path];
    if (value == null) return null;

    final match = _referencePattern.firstMatch(value);
    if (match != null) {
      return _resolveReference(symbols, match.group(1)!, visited, depth + 1);
    }
    return value;
  }
}

/// Greenfield WCAG relative-luminance + contrast-ratio helper.
///
/// There is no existing magic luminance utility to reuse, so this implements
/// the WCAG 2.x definition directly: sRGB channel linearization, the
/// 0.2126/0.7152/0.0722 luminance weights, and the `(L1 + 0.05) / (L2 + 0.05)`
/// ratio. Input is sRGB hex (`#RGB` or `#RRGGBB`); other CSS color formats are
/// out of scope because DESIGN.md recommends hex as the normative default.
class DesignContrast {
  DesignContrast._();

  /// The WCAG AA minimum contrast ratio for normal text.
  static const double wcagAaMinimum = 4.5;

  /// Computes the relative luminance of an sRGB hex color, or null when the
  /// value is not a valid `#RGB` / `#RRGGBB` string.
  static double? relativeLuminance(String hex) {
    final rgb = _parseHex(hex);
    if (rgb == null) return null;

    double linearize(int channel) {
      final s = channel / 255.0;
      return s <= 0.03928
          ? s / 12.92
          : math.pow((s + 0.055) / 1.055, 2.4) as double;
    }

    return 0.2126 * linearize(rgb[0]) +
        0.7152 * linearize(rgb[1]) +
        0.0722 * linearize(rgb[2]);
  }

  /// Computes the WCAG contrast ratio between two sRGB hex colors.
  ///
  /// Returns 1.0 (the no-contrast floor) when either color is unparseable, so
  /// callers treat malformed input as a failed pair rather than crashing.
  static double ratio(String a, String b) {
    final la = relativeLuminance(a);
    final lb = relativeLuminance(b);
    if (la == null || lb == null) return 1.0;

    final lighter = math.max(la, lb);
    final darker = math.min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Parses a `#RGB` or `#RRGGBB` string into `[r, g, b]` (0-255), or null.
  static List<int>? _parseHex(String hex) {
    final clean = hex.trim().toLowerCase();
    if (!clean.startsWith('#')) return null;

    var body = clean.substring(1);
    if (body.length == 3) {
      body = '${body[0]}${body[0]}${body[1]}${body[1]}${body[2]}${body[2]}';
    }
    if (body.length != 6 || !RegExp(r'^[0-9a-f]{6}$').hasMatch(body)) {
      return null;
    }

    return <int>[
      int.parse(body.substring(0, 2), radix: 16),
      int.parse(body.substring(2, 4), radix: 16),
      int.parse(body.substring(4, 6), radix: 16),
    ];
  }
}
