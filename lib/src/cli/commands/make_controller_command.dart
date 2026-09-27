import 'package:fluttersdk_artisan/artisan.dart';
import 'package:path/path.dart' as path;

import '../helpers/creates_matching_test.dart';
import '../helpers/magic_stub_loader.dart';
import 'make_test_command.dart';

/// The `make:controller` generator command.
///
/// Scaffolds a state-owning `MagicController` implementing `SessionScoped`:
/// a plain controller by default, or (with `--resource`) a read controller
/// wrapping a `RepositoryQuery` over the target model's repository.
/// `--actions`, `--broadcasts`, `--timers` and `--validates` mix in
/// `RunsActions`, `ListensToBroadcasts`, `OwnsTimers` and
/// `ValidatesRequests`/`CollapsesIndexedErrorKeys` respectively, always in
/// that same order regardless of the order the flags were passed.
///
/// ## Usage
///
/// ```bash
/// artisan make:controller Monitor                        # plain controller
/// artisan make:controller Monitor --resource              # reads MonitorRepository
/// artisan make:controller Monitor --resource --model=Ping # reads PingRepository
/// artisan make:controller Monitor --broadcasts --timers --actions --validates
/// artisan make:controller Admin/Dashboard --test          # + matching test
/// ```
///
/// The `Controller` suffix is appended automatically when omitted.
class MakeControllerCommand extends ArtisanGeneratorCommand
    with CreatesMatchingTest {
  /// Optional test root override; enables isolation in unit tests.
  final String? _testRoot;

  /// Captures the parsed flags at [handle] time so [getStub] and
  /// [getReplacements] can honour them without re-reading
  /// [ArtisanContext.input].
  bool _resourceFlag = false;
  bool _actionsFlag = false;
  bool _broadcastsFlag = false;
  bool _timersFlag = false;
  bool _validatesFlag = false;

  /// The `--model` option, or `null` when the caller left it to its default
  /// (the controller's own base name); see [_modelClassName].
  String? _modelOption;

  /// Creates a [MakeControllerCommand].
  ///
  /// [testRoot] overrides the project root resolution, used in tests only.
  MakeControllerCommand({String? testRoot}) : _testRoot = testRoot;

  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  String get name => 'make:controller';

  @override
  String get description => 'Create a new controller class';

  @override
  String getDefaultNamespace() => 'lib/app/controllers';

  @override
  String getProjectRoot() => _testRoot ?? super.getProjectRoot();

  @override
  void configure(ArgParser parser) {
    // 1. Register --force and --test (via CreatesMatchingTest) from the
    //    parent chain first.
    super.configure(parser);

    // 2. Add controller-specific flags.
    parser.addFlag(
      'resource',
      abbr: 'r',
      help:
          'Generate a read controller owning a RepositoryQuery over the model',
      negatable: false,
    );
    parser.addOption(
      'model',
      abbr: 'm',
      help:
          'The model a --resource controller reads '
          '(default: the controller name)',
    );
    parser.addFlag('actions', help: 'Mix in RunsActions', negatable: false);
    parser.addFlag(
      'broadcasts',
      help: 'Mix in ListensToBroadcasts',
      negatable: false,
    );
    parser.addFlag('timers', help: 'Mix in OwnsTimers', negatable: false);
    parser.addFlag(
      'validates',
      help: 'Mix in ValidatesRequests and CollapsesIndexedErrorKeys',
      negatable: false,
    );
  }

  @override
  String getStub() => MagicStubLoader.load(
    _resourceFlag ? 'controller.resource' : 'controller',
  );

  /// Provides the placeholder replacements the controller stubs need beyond
  /// `{{ className }}` (already handled by the base class): the class
  /// header, the class body, and (for `--resource`) the model's class
  /// name and its two relative imports.
  ///
  /// [name] is the BASE name without the `Controller` suffix, matching what
  /// [handle] passes to [buildClass].
  @override
  Map<String, String> getReplacements(String name) {
    final className = StringHelper.parseName(name).className;
    final replacements = <String, String>{
      '{{ classHeader }}': _buildClassHeader(),
      '{{ classBody }}': _buildClassBody(className),
    };

    if (_resourceFlag) {
      final directory = StringHelper.parseName(name).directory;
      final modelName = _modelClassName(className);
      final modelSnake = StringHelper.toSnakeCase(modelName);
      replacements['{{ modelClassName }}'] = modelName;
      replacements['{{ modelImport }}'] = _relativeImport(
        directory,
        'lib/app/models',
        modelSnake,
      );
      replacements['{{ repositoryImport }}'] = _relativeImport(
        directory,
        'lib/app/repositories',
        '${modelSnake}_repository',
      );
    }

    return replacements;
  }

  @override
  Future<int> handle(ArtisanContext ctx) async {
    final rawName = ctx.input.argument(0);
    if (rawName == null || rawName.isEmpty) {
      ctx.output.error('Not enough arguments (missing: "name").');
      return 1;
    }

    // 1. Capture flags so getStub/getReplacements can honour them.
    _resourceFlag = ctx.input.hasOption('resource');
    _actionsFlag = ctx.input.hasOption('actions');
    _broadcastsFlag = ctx.input.hasOption('broadcasts');
    _timersFlag = ctx.input.hasOption('timers');
    _validatesFlag = ctx.input.hasOption('validates');
    _modelOption = ctx.input.option('model') as String?;

    // 2. Derive base name (no Controller suffix) and full name (with suffix).
    final baseName = _stripSuffix(rawName, 'Controller');
    final fullName = _withSuffix(rawName, 'Controller');

    // 3. Resolve output path using the FULL name so filename is correct
    //    (e.g., MonitorController → monitor_controller.dart).
    final filePath = getPath(fullName);

    // 4. Abort if file exists and --force was not provided.
    if (FileHelper.fileExists(filePath) && !ctx.input.hasOption('force')) {
      ctx.output.error('File already exists at $filePath');
      return 1;
    }

    // 5. Build stub content using the BASE name so {{ className }} resolves
    //    correctly; the stub appends "Controller" to the placeholder itself.
    final content = buildClass(baseName);
    FileHelper.writeFile(filePath, content);

    ctx.output.success('Created: $filePath');

    // 6. Chain make:test when --test was passed, mirroring this class's own
    //    (possibly nested) name.
    if (ctx.input.hasOption('test')) {
      return createMatchingTest(ctx, TestKind.controller, rawName);
    }

    return 0;
  }

  /// Resolves the model class a `--resource` controller reads: `--model`
  /// when given, otherwise the controller's own base [className].
  String _modelClassName(String className) =>
      (_modelOption != null && _modelOption!.isNotEmpty)
      ? _modelOption!
      : className;

  /// Builds the `extends ... [with ...] implements SessionScoped` clause.
  ///
  /// Mixins are selected in a FIXED order, never the order flags were
  /// passed, so any combination of `--actions`/`--broadcasts`/`--timers`/
  /// `--validates` produces one stable header. `ValidatesRequests` must
  /// precede `CollapsesIndexedErrorKeys` in the `with` list, since the
  /// latter is constrained `on ValidatesRequests`.
  String _buildClassHeader() {
    final mixins = <String>[
      if (_broadcastsFlag) 'ListensToBroadcasts',
      if (_timersFlag) 'OwnsTimers',
      if (_actionsFlag) 'RunsActions',
      if (_validatesFlag) ...<String>[
        'ValidatesRequests',
        'CollapsesIndexedErrorKeys',
      ],
    ];

    final buffer = StringBuffer('extends MagicController');
    if (mixins.isNotEmpty) {
      buffer.write('\n    with ${mixins.join(', ')}');
    }
    buffer.write('\n    implements SessionScoped');
    return buffer.toString();
  }

  /// Builds the class body: the singleton accessor, the `--resource` read
  /// state (query, `items`, `onInit`/`onClose`, `ensureFresh`), the
  /// `--broadcasts` `listeners` getter, and `resetForSession` last.
  String _buildClassBody(String className) {
    final controllerName = '${className}Controller';
    final modelName = _resourceFlag ? _modelClassName(className) : null;

    final parts = <String>[
      _instanceAccessor(controllerName),
      if (modelName != null) _resourceBlock(modelName),
      if (_broadcastsFlag) _listenersGetter(),
      _resetForSession(modelName == null ? null : '${modelName}Repository'),
    ];
    return parts.join('\n\n');
  }

  String _instanceAccessor(String controllerName) =>
      '''
  /// Singleton accessor with lazy registration.
  static $controllerName get instance =>
      Magic.findOrPut($controllerName.new);''';

  /// The `--resource` read state: a [RepositoryQuery] over `<model>Repository`,
  /// the `items` it exposes, and the `onInit`/`ensureFresh`/`onClose` triad.
  String _resourceBlock(String modelClassName) {
    final repositoryName = '${modelClassName}Repository';
    return '''
  /// The read state for $modelClassName: the query owns the cursor and
  /// filters, while the rows themselves are cached in [$repositoryName].
  final RepositoryQuery<$modelClassName> _query =
      RepositoryQuery<$modelClassName>(repository: $repositoryName.instance);

  /// The rows fetched so far, in the order the server sent them.
  List<$modelClassName> get items => _query.items;

  /// Starts the first read and forwards every later query change.
  @override
  void onInit() {
    super.onInit();
    _query.addListener(refreshUI);
    unawaited(_query.reload());
  }

  /// The read a newly mounted view should ask for: joins the initial load
  /// while in flight, refetches once it has settled.
  Future<void> ensureFresh() => _query.ensureFresh();

  /// Re-reads the first page, for a write that adds a row the current
  /// cursor has no place for (a create).
  Future<void> reload() => _query.reload();

  /// Releases the query before the mixins clean up what they own.
  @override
  void onClose() {
    _query.dispose();
    super.onClose();
  }''';
  }

  /// The `--broadcasts` `listeners` getter [ListensToBroadcasts] requires,
  /// left empty for the caller to fill in.
  String _listenersGetter() => '''
  /// The broadcast events this controller applies itself; see
  /// [ListensToBroadcasts].
  @override
  Map<String, void Function(BroadcastEvent)> get listeners =>
      <String, void Function(BroadcastEvent)>{
        // TODO: 'team:event.name': _onEventName,
      };''';

  /// Builds `resetForSession`: for a `--resource` controller, resets
  /// [repositoryName] then reloads the query; otherwise a TODO stub, since a
  /// plain controller has no cached state of its own to clear yet.
  String _resetForSession(String? repositoryName) {
    if (repositoryName == null) {
      return '''
  /// Drops this controller's cached state for the session change
  /// [SessionScoped] describes, then refetches for the identity that is now
  /// authenticated.
  @override
  Future<void> resetForSession() async {
    // TODO: clear cached state, then refetch for the new session.
  }''';
    }

    return '''
  /// Drops the previous session's rows via [$repositoryName], publishes the
  /// cleared state, then refetches for the identity that is now
  /// authenticated.
  @override
  Future<void> resetForSession() async {
    await $repositoryName.instance.resetForSession();
    refreshUI();
    await _query.reload();
  }''';
  }

  /// Computes the `import '...'` path from `lib/app/controllers/<directory>/`
  /// to `<targetNamespace>/<fileStem>.dart`, POSIX-separated regardless of
  /// host OS (an import statement is never OS-specific).
  String _relativeImport(
    String directory,
    String targetNamespace,
    String fileStem,
  ) {
    final fromDir = directory.isEmpty
        ? 'lib/app/controllers'
        : 'lib/app/controllers/$directory';
    return path.posix.relative(
      '$targetNamespace/$fileStem.dart',
      from: fromDir,
    );
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
