import 'package:fluttersdk_artisan/artisan.dart';
import 'package:path/path.dart' as p;

import '../helpers/design_md_parser.dart';

/// The severity of a [_Finding].
enum _Severity {
  /// A correctness violation; fails the lint (nonzero exit).
  error,

  /// A quality concern; reported but does not fail the lint.
  warning,

  /// An informational note.
  info,
}

/// A single lint finding.
class _Finding {
  const _Finding(this.severity, this.path, this.message);

  final _Severity severity;
  final String path;
  final String message;
}

/// `design:lint`: validates a `DESIGN.md` against six rules ported from the
/// design.md reference linter, adapted to the wind-flavored superset.
///
/// Rules:
/// - **broken-ref** (error): a component references a token that does not
///   resolve.
/// - **missing-primary** (warning): colors are defined but `primary` is absent.
/// - **unknown-key** (warning): a top-level YAML key looks like a typo of a
///   schema key. The single-file `dark:` overlay lives inside `colors`, so it
///   is structurally never a top-level key and is never flagged.
/// - **section-order** (warning): markdown sections appear out of canonical
///   order.
/// - **missing-sections** (info): the optional `spacing` / `rounded` groups are
///   absent.
/// - **orphaned-tokens** (warning): a custom color token is defined but never
///   referenced (MD3 baseline families are exempt).
/// - **contrast-ratio** (warning): a component `backgroundColor` /`textColor`
///   pair falls below WCAG AA 4.5:1.
///
/// The Tailwind/DTCG export-conformance and rem-based spacing/rounded rules
/// from the reference linter are intentionally dropped; wind uses 4px logical
/// spacing and arbitrary-hex aliases, so those checks do not apply.
class DesignLintCommand extends ArtisanCommand {
  /// Creates a [DesignLintCommand].
  ///
  /// @param projectRoot  Override for project-root resolution; defaults to
  ///                      [FileHelper.findProjectRoot].
  DesignLintCommand({String? projectRoot}) : _projectRootOverride = projectRoot;

  final String? _projectRootOverride;

  /// Canonical DESIGN.md section order, with accepted aliases resolved.
  static const List<String> _canonicalOrder = <String>[
    'Overview',
    'Colors',
    'Typography',
    'Layout',
    'Elevation & Depth',
    'Shapes',
    'Components',
    "Do's and Don'ts",
  ];

  /// Section heading aliases that resolve to a canonical name.
  static const Map<String, String> _sectionAliases = <String, String>{
    'Brand & Style': 'Overview',
    'Layout & Spacing': 'Layout',
    'Elevation': 'Elevation & Depth',
  };

  /// MD3 baseline color families never flagged as orphaned even when unused.
  static const Set<String> _md3Families = <String>{
    'primary',
    'secondary',
    'tertiary',
    'error',
    'surface',
    'background',
    'outline',
    'fg',
    'accent',
    'border',
    'destructive',
    'success',
    'warning',
  };

  /// Maximum edit distance for the unknown-key typo heuristic.
  static const int _maxTypoDistance = 2;

  @override
  String get signature =>
      'design:lint '
      '{--input=DESIGN.md : Path to the DESIGN.md to validate, relative to the project root}';

  @override
  String get description => 'Validate a DESIGN.md against the design rules.';

  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  Future<int> handle(ArtisanContext ctx) async {
    // 1. Resolve the input path and read it.
    final root = _projectRootOverride ?? FileHelper.findProjectRoot();
    final inputPath = p.join(
      root,
      (ctx.input.option('input') as String?) ?? 'DESIGN.md',
    );
    if (!FileHelper.fileExists(inputPath)) {
      ctx.output.error('DESIGN.md not found at $inputPath.');
      return 1;
    }

    final spec = DesignMdParser.parse(FileHelper.readFile(inputPath));

    // 2. Run every rule and collect findings.
    final findings = <_Finding>[
      if (spec.parseWarning != null)
        _Finding(_Severity.warning, '', spec.parseWarning!),
      ..._brokenRef(spec),
      ..._missingPrimary(spec),
      ..._unknownKey(spec),
      ..._sectionOrder(spec),
      ..._missingSections(spec),
      ..._orphanedTokens(spec),
      ..._contrastRatio(spec),
    ];

    // 3. Report and decide the exit code on error-severity findings.
    return _report(ctx, findings);
  }

  /// broken-ref: every unresolved component reference is an error.
  List<_Finding> _brokenRef(DesignSpec spec) {
    final findings = <_Finding>[];
    for (final entry in spec.components.entries) {
      for (final ref in entry.value.unresolvedRefs) {
        findings.add(
          _Finding(
            _Severity.error,
            'components.${entry.key}',
            'Reference $ref does not resolve to any defined token.',
          ),
        );
      }
    }
    return findings;
  }

  /// missing-primary: colors defined but no `primary`.
  List<_Finding> _missingPrimary(DesignSpec spec) {
    if (spec.colors.isNotEmpty && !spec.colors.containsKey('primary')) {
      return <_Finding>[
        const _Finding(
          _Severity.warning,
          'colors',
          "No 'primary' color defined. The agent will auto-generate key "
              'colors, reducing your control over the palette.',
        ),
      ];
    }
    return const <_Finding>[];
  }

  /// unknown-key: a top-level key within edit distance 2 of a schema key.
  List<_Finding> _unknownKey(DesignSpec spec) {
    final findings = <_Finding>[];
    for (final key in spec.unknownTopLevelKeys) {
      var bestMatch = '';
      var bestDistance = 1 << 30;
      for (final known in DesignMdParser.schemaKeys) {
        final distance = _levenshtein(key.toLowerCase(), known.toLowerCase());
        if (distance < bestDistance) {
          bestDistance = distance;
          bestMatch = known;
        }
      }
      if (bestDistance <= _maxTypoDistance && bestMatch.isNotEmpty) {
        findings.add(
          _Finding(
            _Severity.warning,
            key,
            'Unknown key "$key" - did you mean "$bestMatch"?',
          ),
        );
      }
    }
    return findings;
  }

  /// section-order: the first out-of-order known section pair.
  List<_Finding> _sectionOrder(DesignSpec spec) {
    final orderIndex = <String, int>{
      for (var i = 0; i < _canonicalOrder.length; i++) _canonicalOrder[i]: i,
    };
    final known = spec.sections
        .map((s) => _sectionAliases[s] ?? s)
        .where(orderIndex.containsKey)
        .toList();

    for (var i = 0; i < known.length - 1; i++) {
      final current = orderIndex[known[i]]!;
      final next = orderIndex[known[i + 1]]!;
      if (current > next) {
        return <_Finding>[
          _Finding(
            _Severity.warning,
            'sections',
            "Section '${known[i]}' appears before '${known[i + 1]}', which "
                'is out of order. Expected order: '
                '${_canonicalOrder.join(', ')}',
          ),
        ];
      }
    }
    return const <_Finding>[];
  }

  /// missing-sections: optional spacing / rounded groups absent.
  List<_Finding> _missingSections(DesignSpec spec) {
    final findings = <_Finding>[];
    if (spec.colors.isEmpty) return findings;
    if (spec.spacing.isEmpty) {
      findings.add(
        const _Finding(
          _Severity.info,
          'spacing',
          "No 'spacing' section defined. Layout spacing will fall back to "
              'agent defaults.',
        ),
      );
    }
    if (spec.rounded.isEmpty) {
      findings.add(
        const _Finding(
          _Severity.info,
          'rounded',
          "No 'rounded' section defined. Corner rounding will fall back to "
              'agent defaults.',
        ),
      );
    }
    return findings;
  }

  /// orphaned-tokens: a custom color token never referenced by a component.
  List<_Finding> _orphanedTokens(DesignSpec spec) {
    if (spec.components.isEmpty) return const <_Finding>[];

    // Collect every color value a component resolved to. A reference resolves
    // to the role's light hex (see DesignMdParser symbol table), so match on
    // that to discover which roles are actually in use.
    final referencedHexes = <String>{};
    for (final component in spec.components.values) {
      referencedHexes.addAll(component.resolved.values);
    }

    final referencedFamilies = <String>{};
    for (final entry in spec.colors.entries) {
      if (referencedHexes.contains(entry.value.light)) {
        referencedFamilies.add(_colorFamily(entry.key));
      }
    }

    final findings = <_Finding>[];
    for (final entry in spec.colors.entries) {
      if (referencedHexes.contains(entry.value.light)) continue;
      final family = _colorFamily(entry.key);
      if (referencedFamilies.contains(family)) continue;
      if (_md3Families.contains(family)) continue;
      findings.add(
        _Finding(
          _Severity.warning,
          'colors.${entry.key}',
          "'${entry.key}' is defined but never referenced by any component.",
        ),
      );
    }
    return findings;
  }

  /// contrast-ratio: a component bg/text pair below WCAG AA 4.5:1.
  List<_Finding> _contrastRatio(DesignSpec spec) {
    final findings = <_Finding>[];
    for (final entry in spec.components.entries) {
      final bg = entry.value.resolved['backgroundColor'];
      final text = entry.value.resolved['textColor'];
      if (bg == null || text == null) continue;

      final ratio = DesignContrast.ratio(bg, text);
      if (ratio < DesignContrast.wcagAaMinimum) {
        findings.add(
          _Finding(
            _Severity.warning,
            'components.${entry.key}',
            'textColor ($text) on backgroundColor ($bg) has contrast ratio '
                '${ratio.toStringAsFixed(2)}:1, below the WCAG AA minimum of '
                '${DesignContrast.wcagAaMinimum}:1.',
          ),
        );
      }
    }
    return findings;
  }

  /// Reduces an MD3-style color token name to its family root.
  String _colorFamily(String name) {
    var n = name;
    n = n.replaceFirst(RegExp(r'^on-'), '');
    n = n.replaceFirst(RegExp(r'^inverse-'), '');
    n = n.replaceFirst(RegExp(r'^on-'), '');
    n = n.replaceFirst(RegExp(r'-container.*$'), '');
    n = n.replaceFirst(RegExp(r'-fixed.*$'), '');
    n = n.replaceFirst(
      RegExp(r'-(dim|bright|tint|variant|muted|disabled|subtle)$'),
      '',
    );
    return n;
  }

  /// The classic dynamic-programming Levenshtein edit distance.
  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (i) => i);
    var current = List<int>.filled(b.length + 1, 0);

    for (var i = 0; i < a.length; i++) {
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        current[j + 1] = <int>[
          current[j] + 1,
          previous[j + 1] + 1,
          previous[j] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      final swap = previous;
      previous = current;
      current = swap;
    }
    return previous[b.length];
  }

  /// Prints findings grouped by severity and returns the exit code (nonzero
  /// when any error-severity finding is present).
  int _report(ArtisanContext ctx, List<_Finding> findings) {
    if (findings.isEmpty) {
      ctx.output.success('DESIGN.md passed all design rules.');
      return 0;
    }

    var errors = 0;
    for (final finding in findings) {
      final prefix = finding.path.isEmpty ? '' : '${finding.path}: ';
      switch (finding.severity) {
        case _Severity.error:
          errors++;
          ctx.output.error('$prefix${finding.message}');
        case _Severity.warning:
          ctx.output.warning('$prefix${finding.message}');
        case _Severity.info:
          ctx.output.info('$prefix${finding.message}');
      }
    }

    if (errors > 0) {
      ctx.output.error('DESIGN.md failed with $errors error(s).');
      return 1;
    }
    ctx.output.info(
      'DESIGN.md passed (with ${findings.length} non-error finding(s)).',
    );
    return 0;
  }
}
