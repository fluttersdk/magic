import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:path/path.dart' as p;

import '../helpers/previews_index_writer.dart';

/// `previews:refresh`: regenerates `<scan-dir>/_previews.g.dart` from the
/// `*.preview.dart` files discovered under a configurable scan directory.
///
/// The generated file is the dev-only preview catalog index consumed by
/// `MagicPreview.register(previewEntries())` (magic_devtools). It returns a
/// freshly-built `List<PreviewEntry>` from a FUNCTION (never a top-level const
/// list) so the release-mode tree-shaker can prove the catalog unreachable.
///
/// Mirrors the deterministic codegen primitives in fluttersdk_artisan
/// (`commands:refresh` / `plugins:refresh`): scan source of truth, extract via
/// regex, validate identifiers, collision-check, sort deterministically,
/// render a pure function of the inputs, write atomically via `.tmp` + rename.
/// Unlike those, it does NOT purge any AOT cli-bundle: the Flutter app consuming
/// this generated file has no out-of-isolate cli-bundle to invalidate.
///
/// ## Failure modes
///
/// - A `*.preview.dart` file with zero or multiple public preview classes ->
///   [FormatException].
/// - A malformed preview class name -> [FormatException].
/// - Two previews resolving to the same slug -> [FormatException].
///
/// ## Testing seam
///
/// The constructor accepts an optional `projectRoot` override so the command
/// can run against a temp directory without walking up for `pubspec.yaml`.
class PreviewsRefreshCommand extends ArtisanCommand {
  /// Creates a [PreviewsRefreshCommand].
  ///
  /// @param projectRoot  Override for project root resolution; defaults to
  ///                      [FileHelper.findProjectRoot].
  PreviewsRefreshCommand({String? projectRoot})
    : _projectRootOverride = projectRoot;

  final String? _projectRootOverride;

  @override
  String get signature =>
      'previews:refresh {--path=lib : Directory to scan for *.preview.dart files}';

  @override
  String get description =>
      'Regenerate <scan-dir>/_previews.g.dart from discovered *.preview.dart files.';

  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  Future<int> handle(ArtisanContext ctx) async {
    // 1. Resolve the scan directory under the host project root. The path is
    //    consumer-configurable because the app decides which directory holds
    //    its preview files.
    final root = _projectRootOverride ?? FileHelper.findProjectRoot();
    final scanPath = (ctx.input.option('path') as String?) ?? 'lib';
    final previewsDir = Directory(p.join(root, scanPath));

    // 2. Scan, validate, collision-check, sort, render, atomic-write.
    final discovered = writePreviewsIndex(previewsDir);

    // 3. Summarise so the operator sees what landed.
    ctx.output.success(
      'Refreshed ${discovered.length} preview(s) -> '
      '${p.join(scanPath, '_previews.g.dart')}',
    );
    return 0;
  }
}
