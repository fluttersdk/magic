@Tags(<String>['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_artisan/artisan.dart';
import 'package:path/path.dart' as p;

import 'package:magic/src/cli/commands/make_action_command.dart';
import 'package:magic/src/cli/commands/make_component_command.dart';
import 'package:magic/src/cli/commands/make_controller_command.dart';
import 'package:magic/src/cli/commands/make_enum_command.dart';
import 'package:magic/src/cli/commands/make_event_command.dart';
import 'package:magic/src/cli/commands/make_form_command.dart';
import 'package:magic/src/cli/commands/make_lang_command.dart';
import 'package:magic/src/cli/commands/make_listener_command.dart';
import 'package:magic/src/cli/commands/make_middleware_command.dart';
import 'package:magic/src/cli/commands/make_migration_command.dart';
import 'package:magic/src/cli/commands/make_model_command.dart';
import 'package:magic/src/cli/commands/make_policy_command.dart';
import 'package:magic/src/cli/commands/make_provider_command.dart';
import 'package:magic/src/cli/commands/make_repository_command.dart';
import 'package:magic/src/cli/commands/make_request_command.dart';
import 'package:magic/src/cli/commands/make_resource_command.dart';
import 'package:magic/src/cli/commands/make_seeder_command.dart';
import 'package:magic/src/cli/commands/make_test_command.dart';
import 'package:magic/src/cli/commands/make_view_command.dart';

import '../commands/_harness.dart';

/// `flutter test` runs with the package root as the working directory (see
/// `test/cli/docs_generator_count_test.dart`'s `_repoRoot`), which is also
/// where [MagicStubLoader] resolves `assets/stubs/` from via
/// `.dart_tool/package_config.json`'s self-referencing `magic` entry. That
/// resolution is untouched by the generators writing into [_ProbeProject];
/// only their OUTPUT path is redirected there via each command's `testRoot`.
String get _magicRoot => Directory.current.path;

/// Runs [command] against [args] through the shared harness, failing loudly
/// (with the command name and args) on a non-zero exit code instead of
/// leaving a missing file to surface as a confusing analyzer error later.
Future<void> _run(ArtisanCommand command, List<String> args) async {
  final int code = await command.handle(buildCommandContext(command, args));
  expect(
    code,
    0,
    reason: 'artisan ${command.name} ${args.join(' ')} exited $code',
  );
}

void main() {
  late Directory probeRoot;

  setUpAll(() async {
    // 1. Scaffold a throwaway Flutter package (`gen_probe`) the generators
    //    write into: a path dependency on magic's own worktree root, plus
    //    flutter_lints wired the same way a real consumer would.
    probeRoot = Directory.systemTemp.createTempSync('gen_probe_');
    _writeProbePubspec(probeRoot.path, magicRoot: _magicRoot);
    _writeProbeAnalysisOptions(probeRoot.path);
    _seedEnglishLangFile(probeRoot.path);

    // 2. Run every generator in-process, exactly the combination a developer
    //    scaffolding a new vertical plus a handful of standalone pieces would
    //    invoke from their own terminal.
    await _generateEverything(probeRoot.path);

    // 3. Resolve the path dependency (offline first; CI runners without a
    //    warm pub cache for magic's own transitive deps fall back online).
    await _pubGet(probeRoot.path);
  });

  tearDownAll(() {
    if (probeRoot.existsSync()) probeRoot.deleteSync(recursive: true);
  });

  test('every make:* generator output analyzes with flutter_lints, zero '
      'issues', () async {
    final ProcessResult result = await Process.run('flutter', <String>[
      'analyze',
    ], workingDirectory: probeRoot.path);
    final String output = '${result.stdout}${result.stderr}';

    expect(output, contains('No issues found!'), reason: output);
  });
}

/// Writes `gen_probe`'s `pubspec.yaml`: a path dependency on [magicRoot] (an
/// ABSOLUTE path, so pub resolves it regardless of where the temp directory
/// landed), plus `flutter_test`/`flutter_lints` the same way any consumer
/// project wires them.
void _writeProbePubspec(String root, {required String magicRoot}) {
  final String pubspec =
      '''
name: gen_probe
description: Throwaway probe project proving every make:* generator's output analyzes clean.
publish_to: none
version: 0.0.1

environment:
  sdk: ">=3.11.0 <4.0.0"
  flutter: ">=3.41.0"

dependencies:
  flutter:
    sdk: flutter
  magic:
    path: $magicRoot

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
''';
  FileHelper.writeFile(p.join(root, 'pubspec.yaml'), pubspec);
}

/// Writes `gen_probe`'s `analysis_options.yaml`: the plain `flutter_lints`
/// ruleset a fresh consumer project ships, no magic-specific overrides.
void _writeProbeAnalysisOptions(String root) {
  FileHelper.writeFile(
    p.join(root, 'analysis_options.yaml'),
    'include: package:flutter_lints/flutter.yaml\n',
  );
}

/// Seeds `assets/lang/en.json` so `make:lang tr` copies a real key tree
/// instead of falling back to `{}` (both are valid JSON; this exercises the
/// copy path).
void _seedEnglishLangFile(String root) {
  final String json = const JsonEncoder.withIndent(
    '  ',
  ).convert(<String, String>{'welcome': 'Welcome'});
  FileHelper.writeFile(p.join(root, 'assets', 'lang', 'en.json'), json);
}

/// Runs every `make:*` generator this step covers, in dependency order, into
/// [root]: `make:resource` composes its own CRUD vertical (with its own
/// chained tests); the standalone `Probe` model plus one source file per
/// `TestKind` gives every `make:test --kind=<kind>` call a real class to
/// import: a kind with no matching source would otherwise fail the analyzer
/// on a missing import, which is not a generator defect.
Future<void> _generateEverything(String root) async {
  // 1. The composed CRUD vertical.
  await _run(MakeResourceCommand(testRoot: root), <String>['Monitor']);

  // 2. Standalone pieces with no dependency on the vertical above.
  await _run(MakeComponentCommand(testRoot: root), <String>['Badge']);
  await _run(MakeEnumCommand(testRoot: root), <String>['Region', '--wire']);

  // 3. A second model, `Probe`, plus one source file per TestKind so every
  //    `make:test Probe --kind=<kind>` below imports a real class.
  await _run(MakeModelCommand(testRoot: root), <String>['Probe']);
  await _run(MakeControllerCommand(testRoot: root), <String>['Probe']);
  await _run(MakeActionCommand(testRoot: root), <String>['Probe']);
  await _run(MakeFormCommand(testRoot: root), <String>['Probe']);
  await _run(MakeRepositoryCommand(testRoot: root), <String>['Probe']);
  await _run(MakeRequestCommand(testRoot: root), <String>['Probe']);
  await _run(MakeViewCommand(testRoot: root), <String>[
    'Probe',
    '--controller=Probe',
  ]);

  // 4. `make:test Probe --kind=<kind>` for every TestKind, now that each
  //    kind's source class exists.
  for (final TestKind kind in TestKind.values) {
    await _run(MakeTestCommand(testRoot: root), <String>[
      'Probe',
      '--kind=${kind.value}',
    ]);
  }

  // 5. The remaining generators this step covers, none of which chains a
  //    matching test.
  await _run(MakeEventCommand(testRoot: root), <String>['ProbeCreated']);
  await _run(MakeListenerCommand(testRoot: root), <String>[
    'LogProbeCreated',
    '--event=ProbeCreated',
  ]);
  await _run(MakeMiddlewareCommand(testRoot: root), <String>[
    'EnsureProbeReady',
  ]);
  await _run(MakeProviderCommand(testRoot: root), <String>['Probe']);
  await _run(MakePolicyCommand(testRoot: root), <String>['Probe']);
  await _run(MakeSeederCommand(testRoot: root), <String>['Probe']);
  await _run(MakeMigrationCommand(testRoot: root), <String>[
    'create_probes_table',
    '--create=probes',
  ]);
  await _run(MakeLangCommand(testRoot: root), <String>['tr']);
}

/// Runs `flutter pub get --offline` in [root]; falls back to an online
/// `flutter pub get` when the offline cache cannot resolve every transitive
/// dependency (a cold pub cache, or a runner that never fetched
/// `fluttersdk_wind`/`fluttersdk_artisan` before).
Future<void> _pubGet(String root) async {
  final ProcessResult offline = await Process.run('flutter', <String>[
    'pub',
    'get',
    '--offline',
  ], workingDirectory: root);
  if (offline.exitCode == 0) return;

  final ProcessResult online = await Process.run('flutter', <String>[
    'pub',
    'get',
  ], workingDirectory: root);
  expect(
    online.exitCode,
    0,
    reason:
        'flutter pub get failed offline and online:\n'
        'offline: ${offline.stdout}${offline.stderr}\n'
        'online: ${online.stdout}${online.stderr}',
  );
}
