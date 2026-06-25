import 'dart:io';

import 'package:path/path.dart' as p;

/// One discovered preview entry from a `*.preview.dart` filesystem scan.
///
/// Pairs the Dart class name with the URL-safe [slug] and human [label] the
/// catalog uses, plus the [importPath] relative to the generated
/// `_previews.g.dart` so the emitted file can reach the preview widget (preview
/// files are intentionally not exported from any barrel).
class DiscoveredPreview {
  /// Creates a discovered preview.
  const DiscoveredPreview({
    required this.className,
    required this.slug,
    required this.label,
    required this.importPath,
  });

  /// The public preview class name (e.g. `ButtonPreview`).
  final String className;

  /// The URL-safe `:component` slug (e.g. `button`).
  final String slug;

  /// The catalog sidebar label (the class name minus the `Preview` suffix).
  final String label;

  /// The import path relative to the generated file's directory.
  final String importPath;
}

/// Matches a PUBLIC preview class declaration: `class XxxPreview extends ...`.
///
/// The leading `(?<![\w])` plus the absence of a leading `_` guards against
/// matching the private `_XxxPreviewState` companion of a stateful preview.
/// Comments and string literals are not excluded by design, mirroring
/// `commands_index_writer.dart`: preview class declarations live at the top
/// level of their file by convention.
final RegExp _previewClassPattern = RegExp(
  r'(?<![\w$])class\s+([A-Z]\w*Preview)\s+extends\s+\w+',
);

/// Validates a discovered preview class is a clean PascalCase identifier
/// BEFORE it is interpolated into generated Dart source (defense against a
/// malformed name landing in the emitted file).
final RegExp _identifierPattern = RegExp(r'^[A-Z][a-zA-Z0-9_]*$');

/// Scans [previewsDir] recursively for `*.preview.dart` files, extracts the
/// single public `*Preview` class from each, and returns the discovered set
/// sorted deterministically by slug.
///
/// Invariants enforced (fail-fast, mirroring the artisan codegen primitives):
/// - exactly ONE public preview class per file;
/// - every class name is a valid PascalCase Dart identifier;
/// - no two files claim the same slug.
///
/// @param previewsDir  The directory holding `*.preview.dart` files.
/// @return The discovered previews, sorted by slug. Empty when the directory
///         does not exist.
/// @throws FormatException on a multi-class file, a malformed identifier, or a
///         slug collision.
List<DiscoveredPreview> discoverPreviews(Directory previewsDir) {
  if (!previewsDir.existsSync()) return const <DiscoveredPreview>[];

  // 1. Collect candidate files in a stable order so the scan itself never
  //    depends on filesystem enumeration order.
  final files =
      previewsDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => p.basename(f.path).endsWith('.preview.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  // 2. Extract + validate one preview class per file.
  final discovered = <DiscoveredPreview>[];
  for (final file in files) {
    final source = file.readAsStringSync();
    final matches = _previewClassPattern.allMatches(source).toList();
    if (matches.length != 1) {
      throw FormatException(
        'Expected exactly one public *Preview class in '
        '${p.basename(file.path)}, found ${matches.length}. Each '
        '*.preview.dart file must declare a single public preview widget.',
      );
    }

    final className = matches.single.group(1)!;
    if (!_identifierPattern.hasMatch(className)) {
      throw FormatException(
        'Invalid preview class name "$className" in '
        '${p.basename(file.path)}. Expected a PascalCase Dart identifier '
        r'matching ^[A-Z][a-zA-Z0-9_]*$.',
      );
    }

    final label = className.substring(0, className.length - 'Preview'.length);
    discovered.add(
      DiscoveredPreview(
        className: className,
        slug: _slugFor(label),
        label: label,
        importPath: _importPathFor(previewsDir, file),
      ),
    );
  }

  // 3. Fail fast on a slug collision so two previews never silently overwrite
  //    each other's `:component` route segment.
  _validateNoSlugCollisions(discovered);

  // 4. Deterministic sort by slug keeps the emitted file byte-identical across
  //    runs regardless of discovery order.
  discovered.sort((a, b) => a.slug.compareTo(b.slug));
  return discovered;
}

/// Renders the `_previews.g.dart` source from an already-sorted [previews]
/// list. Pure function (no I/O, no clock reads) so its output is fully
/// determined by the inputs, which is the idempotence guarantee.
///
/// The output is a FUNCTION returning a freshly-built `List<PreviewEntry>`,
/// never a top-level const list: a const list of widget refs would defeat the
/// release-mode tree-shaker (dart-lang/sdk#33920) and pin the dev catalog into
/// production builds.
String renderPreviewsIndex(List<DiscoveredPreview> previews) {
  final buf = StringBuffer()
    ..writeln('// GENERATED: do not edit by hand.')
    ..writeln('// Regenerate via: dart run magic:artisan previews:refresh')
    ..writeln('//')
    ..writeln('// Source: *.preview.dart files discovered under the scan dir.')
    ..writeln()
    ..writeln("import 'package:magic_devtools/preview.dart';");

  if (previews.isEmpty) {
    buf
      ..writeln()
      ..writeln('List<PreviewEntry> previewEntries() {')
      ..writeln('  return <PreviewEntry>[];')
      ..writeln('}')
      ..writeln();
    return buf.toString();
  }

  // Imports sorted by path for deterministic ordering. Slugs are already
  // collision-checked, so two previews never share an import alias.
  final imports = previews.map((e) => e.importPath).toSet().toList()..sort();
  for (final importPath in imports) {
    buf.writeln("import '$importPath';");
  }

  buf
    ..writeln()
    ..writeln('List<PreviewEntry> previewEntries() {')
    ..writeln('  return <PreviewEntry>[');
  for (final preview in previews) {
    buf
      ..writeln('    PreviewEntry(')
      ..writeln("      label: '${preview.label}',")
      ..writeln("      slug: '${preview.slug}',")
      ..writeln('      builder: (_) => const ${preview.className}(),')
      ..writeln('    ),');
  }
  buf
    ..writeln('  ];')
    ..writeln('}')
    ..writeln();
  return buf.toString();
}

/// End-to-end: scan [previewsDir], render, and atomically write
/// `_previews.g.dart` into that directory via `.tmp` + rename so concurrent
/// readers (open editors, lint daemons) never observe a partial file.
///
/// @return The discovered previews so the caller can report what was wired.
List<DiscoveredPreview> writePreviewsIndex(Directory previewsDir) {
  final discovered = discoverPreviews(previewsDir);
  if (!previewsDir.existsSync()) {
    previewsDir.createSync(recursive: true);
  }
  final outputPath = p.join(previewsDir.path, '_previews.g.dart');
  final tmpPath = '$outputPath.tmp';
  File(tmpPath).writeAsStringSync(renderPreviewsIndex(discovered));
  File(tmpPath).renameSync(outputPath);
  return discovered;
}

/// Converts a PascalCase [label] to a `snake_case` slug
/// (`SegmentedControl` -> `segmented_control`).
String _slugFor(String label) {
  final withUnderscores = label.replaceAllMapped(
    RegExp(r'(?<=[a-z0-9])([A-Z])'),
    (m) => '_${m.group(1)}',
  );
  return withUnderscores.toLowerCase();
}

/// Computes the import path of [file] relative to [previewsDir] (where the
/// generated `_previews.g.dart` lives), using forward slashes so the emitted
/// Dart is platform-stable.
String _importPathFor(Directory previewsDir, File file) {
  final relative = p.relative(file.path, from: previewsDir.path);
  return p.split(relative).join('/');
}

/// Throws [FormatException] when two discovered previews claim the same slug,
/// naming every colliding class so the operator can fix the source without
/// guessing which files clashed.
void _validateNoSlugCollisions(List<DiscoveredPreview> previews) {
  final bySlug = <String, List<String>>{};
  for (final preview in previews) {
    bySlug.putIfAbsent(preview.slug, () => <String>[]).add(preview.className);
  }
  for (final entry in bySlug.entries) {
    if (entry.value.length > 1) {
      final classes = (entry.value.toList()..sort()).join(', ');
      throw FormatException(
        'Duplicate preview slug "${entry.key}" claimed by: $classes. '
        'Each preview must resolve to a unique slug.',
      );
    }
  }
}
