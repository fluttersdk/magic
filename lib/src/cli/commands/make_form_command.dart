import 'package:fluttersdk_artisan/artisan.dart';
import 'package:path/path.dart' as path;

import '../helpers/magic_stub_loader.dart';

/// The `make:form` generator command.
///
/// Scaffolds a new [MagicFormObject] subclass inside `lib/app/forms/`. The
/// `FormObject` suffix is deliberate: apps already name form WIDGETS
/// `<Resource>Form` (uptizm's `MonitorForm` among them), so the object that
/// backs one needs a distinct name.
///
/// ## Usage
///
/// ```bash
/// artisan make:form Monitor                          # -> MonitorFormObject
/// artisan make:form MonitorFormObject                # Suffix already present
/// artisan make:form Monitor --request=StoreMonitorRequest
/// artisan make:form Monitor --force                  # Overwrite existing file
/// ```
class MakeFormCommand extends ArtisanGeneratorCommand {
  /// Optional test root override: injected in tests to avoid touching the
  /// real filesystem.
  final String? _testRoot;

  /// Captures the parsed `--request` value during [handle] so
  /// [getReplacements] can consume it without re-reading [ArtisanContext.input].
  String? _requestOption;

  /// Creates a [MakeFormCommand].
  ///
  /// Pass [testRoot] to pin the project root to a temp directory during tests.
  MakeFormCommand({String? testRoot}) : _testRoot = testRoot;

  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  String get name => 'make:form';

  @override
  String get description => 'Create a new form object class';

  @override
  String getDefaultNamespace() => 'lib/app/forms';

  @override
  String getStub() => MagicStubLoader.load('form');

  @override
  String getProjectRoot() => _testRoot ?? super.getProjectRoot();

  @override
  void configure(ArgParser parser) {
    super.configure(parser);
    parser.addOption(
      'request',
      help: 'The FormRequest class this form validates against',
    );
  }

  @override
  Future<int> handle(ArtisanContext ctx) async {
    // 1. Capture --request so [getReplacements] (called from [buildClass])
    //    can use it without re-reading the context.
    _requestOption = ctx.input.option('request') as String?;
    return super.handle(ctx);
  }

  /// Normalises [name] so the last path segment always carries the
  /// `FormObject` suffix. Used by both [getPath] and [buildClass] to keep
  /// the class identifier, file name, and stub substitutions in sync.
  String _normalizeName(String name) {
    final parsed = StringHelper.parseName(name);
    final className = parsed.className.endsWith('FormObject')
        ? parsed.className
        : '${parsed.className}FormObject';

    return parsed.directory.isEmpty
        ? className
        : '${parsed.directory}/$className';
  }

  /// Returns the class name with the `FormObject` suffix guaranteed.
  String _resolveClassName(String name) {
    final parsed = StringHelper.parseName(name);
    return parsed.className.endsWith('FormObject')
        ? parsed.className
        : '${parsed.className}FormObject';
  }

  /// Overrides to produce the FormObject-suffixed file name as the output path.
  @override
  String getPath(String name) {
    final parsed = StringHelper.parseName(name);
    final className = _resolveClassName(name);
    final fileName = StringHelper.toSnakeCase(className);
    final namespace = getDefaultNamespace();
    final projectRoot = getProjectRoot();

    if (parsed.directory.isEmpty) {
      return path.join(projectRoot, namespace, '$fileName.dart');
    }

    return path.join(
      projectRoot,
      namespace,
      parsed.directory,
      '$fileName.dart',
    );
  }

  /// Overrides stub building so the parent's internal `{{ className }}`
  /// substitution writes the FormObject-suffixed class name.
  @override
  String buildClass(String name) => super.buildClass(_normalizeName(name));

  @override
  Map<String, String> getReplacements(String name) {
    // [name] is already normalised (FormObject-suffixed) at this point.
    final className = StringHelper.parseName(name).className;
    final modelName = className.replaceAll('FormObject', '');

    return {
      '{{ modelName }}': modelName,
      '{{ requestImport }}': _renderRequestImport(
        StringHelper.toSnakeCase(modelName),
      ),
      '{{ requestExpression }}': _renderRequestExpression(),
    };
  }

  /// Renders the request import line: a real import for the class named via
  /// `--request`, or a TODO placeholder pointing at the conventional
  /// `validation/requests/` path when the flag was not supplied.
  String _renderRequestImport(String modelSnakeName) {
    final request = _requestOption;
    if (request == null || request.isEmpty) {
      return '// TODO: Import your form request\n'
          "// import '../validation/requests/${modelSnakeName}_request.dart';";
    }

    final requestSnakeName = StringHelper.toSnakeCase(request);
    return "import '../validation/requests/$requestSnakeName.dart';";
  }

  /// Renders the `request` getter body: a real instance of the class named
  /// via `--request`, or an [UnimplementedError] pointing the author at it.
  String _renderRequestExpression() {
    final request = _requestOption;
    if (request == null || request.isEmpty) {
      return "throw UnimplementedError(\n"
          "    'Import your form request and override request.',\n"
          '  )';
    }

    return '$request()';
  }
}
