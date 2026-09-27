import 'package:fluttersdk_artisan/artisan.dart';

import '../helpers/creates_matching_test.dart';
import '../helpers/magic_stub_loader.dart';
import 'make_test_command.dart' show TestKind;

/// A resolved suffixed identifier (a controller or a form object): the class
/// name with its suffix guaranteed, and the directory it lives under
/// (relative to its own default namespace, empty when flat).
typedef _SuffixedName = ({String className, String directory});

/// The `make:view` generator command.
///
/// Scaffolds a new view class using the view stub templates: a plain
/// `StatelessWidget` for a view with no backing controller, or a
/// `MagicStatefulView<T>` wired to one.
///
/// ## Usage
///
/// ```bash
/// artisan make:view Login                          # → StatelessWidget
/// artisan make:view Auth/Register                   # Nested path
/// artisan make:view Monitor --controller=Monitor    # MagicStatefulView<MonitorController>
/// artisan make:view Login --stateful                # Controller derived: LoginController
/// artisan make:view Monitors/List --controller=Monitor --list --form=MonitorFormObject
/// ```
///
/// The `View` suffix is appended automatically when omitted. `--list` expects
/// a controller made with `make:controller --resource`, which exposes the
/// `ensureFresh()` method [RefetchesOnMount] calls.
class MakeViewCommand extends ArtisanGeneratorCommand with CreatesMatchingTest {
  /// Optional test root override — enables isolation in unit tests.
  final String? _testRoot;

  /// Captures the parsed `--stateful` flag at [handle] time so [getStub] can
  /// honour it without re-reading the [ArtisanContext.input].
  bool _statefulFlag = false;

  /// Captures the parsed `--list` flag at [handle] time.
  bool _listFlag = false;

  /// Captures the parsed `--controller` value at [handle] time, or `null`
  /// when the controller should be derived from the view's own name.
  String? _controllerOption;

  /// Captures the parsed `--form` value at [handle] time, or `null` when no
  /// form object is wired.
  String? _formOption;

  /// Creates a [MakeViewCommand].
  ///
  /// [testRoot] overrides the project root resolution, used in tests only.
  MakeViewCommand({String? testRoot}) : _testRoot = testRoot;

  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  String get name => 'make:view';

  @override
  String get description => 'Create a new view class';

  @override
  String getDefaultNamespace() => 'lib/resources/views';

  @override
  String getProjectRoot() => _testRoot ?? super.getProjectRoot();

  @override
  void configure(ArgParser parser) {
    // 1. Register --force, --test (and base args) from parent first.
    super.configure(parser);

    // 2. Add view-specific flags.
    parser.addFlag(
      'stateful',
      help: 'Generate a stateful view with lifecycle hooks',
      negatable: false,
    );
    parser.addOption(
      'controller',
      help:
          'Bind the view to this controller (suffix optional); implies '
          '--stateful.',
    );
    parser.addFlag(
      'list',
      help:
          'Add RefetchesOnMount so the view reloads on every mount. Expects '
          'a controller made with `make:controller --resource`, which '
          'exposes `ensureFresh()`.',
      negatable: false,
    );
    parser.addOption(
      'form',
      help:
          'Add a State-owned form object field (suffix optional), disposed '
          'in onClose; implies --stateful.',
    );
  }

  /// Whether any flag captured in [handle] calls for a stateful view.
  bool get _isStateful =>
      _statefulFlag ||
      _listFlag ||
      (_controllerOption?.isNotEmpty ?? false) ||
      (_formOption?.isNotEmpty ?? false);

  @override
  String getStub() =>
      MagicStubLoader.load(_isStateful ? 'view.stateful' : 'view');

  /// Provides extra placeholder replacements for the view stub.
  ///
  /// [name] is the BASE name without the `View` suffix
  /// (e.g., `Login`, `Auth/Register`).
  @override
  Map<String, String> getReplacements(String name) {
    final parsed = StringHelper.parseName(name);
    final replacements = <String, String>{
      '{{ snakeName }}': StringHelper.toSnakeCase(parsed.className),
    };

    if (!_isStateful) return replacements;

    // The number of `../` steps from the generated file back up to `lib/`:
    // 2 for `resources/views` plus one per nested view directory segment
    // (e.g. `lib/resources/views/monitors/monitors_list_view.dart` needs 3).
    final viewDirDepth = parsed.directory.isEmpty
        ? 0
        : parsed.directory.split('/').length;
    final upCount = 2 + viewDirDepth;

    final controller = _resolveController(parsed.className);
    replacements['{{ controllerClassName }}'] = controller.className;
    replacements['{{ controllerImportPath }}'] = _relativeImportPath(
      upCount,
      'app/controllers',
      controller,
    );
    replacements['{{ mixinClause }}'] = _listFlag
        ? '\n    with RefetchesOnMount<${controller.className}, '
              '${parsed.className}View>'
        : '';

    String? formClassName;
    if (_formOption != null && _formOption!.isNotEmpty) {
      final form = _resolveSuffixed(_formOption!, 'FormObject');
      formClassName = form.className;
      replacements['{{ formImportLine }}'] =
          "\nimport '${_relativeImportPath(upCount, 'app/forms', form)}';";
    } else {
      replacements['{{ formImportLine }}'] = '';
    }

    replacements['{{ stateBody }}'] = _buildStateBody(
      controllerClassName: controller.className,
      formClassName: formClassName,
      isList: _listFlag,
    );

    return replacements;
  }

  @override
  Future<int> handle(ArtisanContext ctx) async {
    final rawName = ctx.input.argument(0);
    if (rawName == null || rawName.isEmpty) {
      ctx.output.error('Not enough arguments (missing: "name").');
      return 1;
    }

    // 1. Capture flags so getStub/getReplacements can honour them without
    //    re-reading the context.
    _statefulFlag = ctx.input.hasOption('stateful');
    _listFlag = ctx.input.hasOption('list');
    _controllerOption = ctx.input.option('controller') as String?;
    _formOption = ctx.input.option('form') as String?;

    // 2. Derive base name (no View suffix) and full name (with suffix).
    final baseName = _stripSuffix(rawName, 'View');
    final fullName = _withSuffix(rawName, 'View');

    // 3. Resolve output path using the FULL name so filename is correct
    //    (e.g., LoginView → login_view.dart).
    final filePath = getPath(fullName);

    // 4. Abort if file exists and --force was not provided.
    if (FileHelper.fileExists(filePath) && !ctx.input.hasOption('force')) {
      ctx.output.error('File already exists at $filePath');
      return 1;
    }

    // 5. Build stub content using the BASE name so {{ className }} resolves
    //    correctly — the stub appends "View" to the placeholder itself.
    final content = buildClass(baseName);
    FileHelper.writeFile(filePath, content);

    ctx.output.success('Created: $filePath');

    // 6. Chain make:test --kind=view when --test was passed.
    if (ctx.input.hasOption('test')) {
      return createMatchingTest(ctx, TestKind.view, rawName);
    }

    return 0;
  }

  /// Resolves the controller this view binds to: the `--controller` value
  /// when given (suffix guaranteed), or one derived from the view's own
  /// [viewClassName] (e.g. `Login` → `LoginController`).
  _SuffixedName _resolveController(String viewClassName) {
    final option = _controllerOption;
    if (option != null && option.isNotEmpty) {
      return _resolveSuffixed(option, 'Controller');
    }
    return (className: '${viewClassName}Controller', directory: '');
  }

  /// Resolves [raw] to a suffixed class name and its directory, guaranteeing
  /// [suffix] is present exactly once.
  _SuffixedName _resolveSuffixed(String raw, String suffix) {
    final parsed = StringHelper.parseName(raw);
    final className = parsed.className.endsWith(suffix)
        ? parsed.className
        : '${parsed.className}$suffix';
    return (className: className, directory: parsed.directory);
  }

  /// The relative import path from the generated view file back up
  /// [upCount] directories, then down into `lib/$appSubpath/$name`.
  String _relativeImportPath(
    int upCount,
    String appSubpath,
    _SuffixedName name,
  ) {
    final ups = '../' * upCount;
    final dirSegment = name.directory.isEmpty ? '' : '${name.directory}/';
    final fileName = StringHelper.toSnakeCase(name.className);
    return '$ups$appSubpath/$dirSegment$fileName.dart';
  }

  /// Renders the `_XViewState` body: the optional form field, the
  /// controller-registering `initState`, the optional `onClose` (form
  /// disposal) and the optional `refetch` override (`--list`).
  String _buildStateBody({
    required String controllerClassName,
    required String? formClassName,
    required bool isList,
  }) {
    final buffer = StringBuffer();

    if (formClassName != null) {
      buffer
        ..writeln(
          "  /// The form object backing this screen's inputs, disposed in "
          '[onClose].',
        )
        ..writeln('  late final form = $formClassName();')
        ..writeln();
    }

    buffer
      ..writeln('  @override')
      ..writeln('  void initState() {')
      ..writeln(
        '    // Register the controller before the base state resolves it '
        'via',
      )
      ..writeln(
        '    // Magic.find<T>() (which throws when unregistered). '
        'Idempotent.',
      )
      ..writeln('    Magic.findOrPut($controllerClassName.new);')
      ..writeln('    super.initState();')
      ..writeln('  }');

    if (formClassName != null) {
      buffer
        ..writeln()
        ..writeln('  @override')
        ..writeln('  void onClose() {')
        ..writeln('    form.dispose();')
        ..writeln('  }');
    }

    if (isList) {
      buffer
        ..writeln()
        ..writeln('  @override')
        ..writeln('  Future<void> refetch() => controller.ensureFresh();');
    }

    return buffer.toString();
  }

  /// Returns [name] with [suffix] appended to the last path segment if absent.
  String _withSuffix(String name, String suffix) {
    final parts = name.split('/');
    final last = parts.last;
    final normalisedLast = last.endsWith(suffix) ? last : '$last$suffix';
    return [...parts.sublist(0, parts.length - 1), normalisedLast].join('/');
  }

  /// Returns [name] with [suffix] removed from the last path segment if present.
  String _stripSuffix(String name, String suffix) {
    final parts = name.split('/');
    final last = parts.last;
    final strippedLast = last.endsWith(suffix)
        ? last.substring(0, last.length - suffix.length)
        : last;
    return [...parts.sublist(0, parts.length - 1), strippedLast].join('/');
  }
}
