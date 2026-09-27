import 'package:fluttersdk_artisan/artisan.dart';
import 'package:path/path.dart' as path;

import '../helpers/magic_stub_loader.dart';

/// The generator kinds `make:test --kind=<kind>` understands, one per
/// `make:*` command that carries a matching-test convention (see
/// `CreatesMatchingTest`).
enum TestKind {
  controller('controller'),
  action('action'),
  form('form'),
  repository('repository'),
  request('request'),
  view('view'),
  unit('unit');

  const TestKind(this.value);

  /// The `--kind=<value>` string this member parses from.
  final String value;

  /// Resolves [raw] to a [TestKind], or `null` when it matches none.
  static TestKind? fromValue(String? raw) {
    for (final kind in TestKind.values) {
      if (kind.value == raw) return kind;
    }
    return null;
  }
}

/// Where a [TestKind]'s source class lives and how its test mirrors it.
class _KindSpec {
  const _KindSpec({
    required this.libNamespace,
    required this.testNamespace,
    required this.classSuffix,
    required this.stubName,
  });

  /// Where the generator under test writes its class, relative to the
  /// project root (e.g. `lib/app/controllers`). Empty for `unit`, which has
  /// no source-file counterpart.
  final String libNamespace;

  /// Where the matching test lives, relative to the project root (e.g.
  /// `test/app/controllers`).
  final String testNamespace;

  /// Suffix guaranteed on the class/file name (e.g. `Controller`); `null`
  /// when the kind carries no suffix (action, unit).
  final String? classSuffix;

  /// Stub name (without `.stub`) rendering this kind's test skeleton.
  final String stubName;
}

/// The `make:test` generator command.
///
/// Scaffolds a test skeleton mirroring where a `make:*` generator's own
/// output lives (Laravel's `make:test`, ported to magic's `lib/` -> `test/`
/// layout): `lib/app/controllers/monitor_controller.dart` gets
/// `test/app/controllers/monitor_controller_test.dart`, and so on for
/// `--kind=action|form|repository|request|view|unit`.
///
/// ## Usage
///
/// ```bash
/// artisan make:test Monitor --kind=controller
/// artisan make:test Monitors/PauseMonitor --kind=action   # Nested path
/// artisan make:test Monitor --kind=repository --force     # Overwrite
/// ```
///
/// The generated test imports the target class as `package:<name>/...`,
/// where `<name>` is read from the target project's own `pubspec.yaml`
/// (relative `../lib/` imports would trip `avoid_relative_lib_imports`).
class MakeTestCommand extends ArtisanGeneratorCommand {
  /// Optional test root override; enables isolation in unit tests.
  final String? _testRoot;

  /// Creates a [MakeTestCommand].
  ///
  /// [testRoot] overrides the project root resolution, used in tests only.
  MakeTestCommand({String? testRoot}) : _testRoot = testRoot;

  static const Map<TestKind, _KindSpec> _specs = <TestKind, _KindSpec>{
    TestKind.controller: _KindSpec(
      libNamespace: 'lib/app/controllers',
      testNamespace: 'test/app/controllers',
      classSuffix: 'Controller',
      stubName: 'test.controller',
    ),
    TestKind.action: _KindSpec(
      libNamespace: 'lib/app/actions',
      testNamespace: 'test/app/actions',
      classSuffix: null,
      stubName: 'test.action',
    ),
    TestKind.form: _KindSpec(
      libNamespace: 'lib/app/forms',
      testNamespace: 'test/app/forms',
      classSuffix: 'FormObject',
      stubName: 'test.form',
    ),
    TestKind.repository: _KindSpec(
      libNamespace: 'lib/app/repositories',
      testNamespace: 'test/app/repositories',
      classSuffix: 'Repository',
      stubName: 'test.repository',
    ),
    TestKind.request: _KindSpec(
      libNamespace: 'lib/app/validation/requests',
      testNamespace: 'test/app/validation/requests',
      classSuffix: 'Request',
      stubName: 'test.request',
    ),
    TestKind.view: _KindSpec(
      libNamespace: 'lib/resources/views',
      testNamespace: 'test/resources/views',
      classSuffix: 'View',
      stubName: 'test.view',
    ),
    TestKind.unit: _KindSpec(
      libNamespace: '',
      testNamespace: 'test/unit',
      classSuffix: null,
      stubName: 'test.unit',
    ),
  };

  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  String get name => 'make:test';

  @override
  String get description =>
      "Create a test skeleton mirroring a generator's output";

  @override
  String getDefaultNamespace() => 'test';

  @override
  String getProjectRoot() => _testRoot ?? super.getProjectRoot();

  /// This command picks its stub per `--kind` inside [handle]; [getStub] is
  /// unused (mirrors `make:component`'s multi-file generators).
  @override
  String getStub() => '';

  @override
  void configure(ArgParser parser) {
    super.configure(parser);
    parser.addOption(
      'kind',
      help:
          'The generator kind whose output this test mirrors: '
          '${TestKind.values.map((k) => k.value).join('|')}.',
    );
  }

  @override
  Future<int> handle(ArtisanContext ctx) async {
    // 1. Validate the required positional name.
    final rawName = ctx.input.argument(0);
    if (rawName == null || rawName.isEmpty) {
      ctx.output.error('Not enough arguments (missing: "name").');
      return 1;
    }

    // 2. Validate --kind against the known set.
    final kindOption = ctx.input.option('kind') as String?;
    final kind = TestKind.fromValue(kindOption);
    if (kind == null) {
      final known = TestKind.values.map((k) => k.value).join(', ');
      ctx.output.error(
        'Unknown --kind "${kindOption ?? ''}". Expected one of: $known.',
      );
      return 1;
    }

    // 3. Resolve the target project's own package name from its
    //    pubspec.yaml; the generated test imports app code as
    //    `package:<name>/...`.
    final projectRoot = getProjectRoot();
    final pubspecPath = path.join(projectRoot, 'pubspec.yaml');
    if (!FileHelper.fileExists(pubspecPath)) {
      ctx.output.error('pubspec.yaml not found at $pubspecPath');
      return 1;
    }
    final Object? packageName = FileHelper.readYamlFile(pubspecPath)['name'];
    if (packageName is! String || packageName.isEmpty) {
      ctx.output.error('pubspec.yaml at $pubspecPath declares no package name');
      return 1;
    }

    // 4. Resolve the output path and class name for this kind.
    final spec = _specs[kind]!;
    final parsed = StringHelper.parseName(rawName);
    final className = _withSuffix(parsed.className, spec.classSuffix);
    final fileStem = StringHelper.toSnakeCase(className);
    final filePath = parsed.directory.isEmpty
        ? path.join(projectRoot, spec.testNamespace, '${fileStem}_test.dart')
        : path.join(
            projectRoot,
            spec.testNamespace,
            parsed.directory,
            '${fileStem}_test.dart',
          );

    // 5. Abort if the test exists and --force was not provided.
    if (FileHelper.fileExists(filePath) && !ctx.input.hasOption('force')) {
      ctx.output.error('File already exists at $filePath');
      return 1;
    }

    // 6. Build and write the test skeleton from the kind's stub.
    final content = _render(
      spec,
      className,
      packageName,
      parsed.directory,
      fileStem,
    );
    FileHelper.writeFile(filePath, content);
    ctx.output.success('Created: $filePath');
    return 0;
  }

  /// Returns [className] with [suffix] appended when absent; unchanged when
  /// [suffix] is `null` (action, unit carry no suffix).
  String _withSuffix(String className, String? suffix) {
    if (suffix == null) return className;
    return className.endsWith(suffix) ? className : '$className$suffix';
  }

  /// Loads [spec]'s stub and substitutes `{{ className }}`, `{{ packageName
  /// }}`, and `{{ importPath }}`.
  String _render(
    _KindSpec spec,
    String className,
    String packageName,
    String directory,
    String fileStem,
  ) {
    final stub = MagicStubLoader.load(spec.stubName);
    return stub
        .replaceAll('{{ className }}', className)
        .replaceAll('{{ packageName }}', packageName)
        .replaceAll('{{ importPath }}', _importPath(spec, directory, fileStem));
  }

  /// The `package:<name>/`-relative import path to the source class, or an
  /// empty string for `unit` (no source-file counterpart; its stub only
  /// substitutes `{{ packageName }}` inside a TODO comment).
  String _importPath(_KindSpec spec, String directory, String fileStem) {
    if (spec.libNamespace.isEmpty) return '';
    final sourceNamespace = spec.libNamespace.substring('lib/'.length);
    return directory.isEmpty
        ? '$sourceNamespace/$fileStem.dart'
        : '$sourceNamespace/$directory/$fileStem.dart';
  }
}
