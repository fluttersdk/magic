import 'package:dowel/dowel.dart';

import '../helpers/magic_stub_loader.dart';

/// Make Enum Command.
///
/// Scaffolds a new string-backed enum class using the `enum` stub template.
///
/// ## Usage
///
/// ```bash
/// dowel make:enum MonitorType
/// dowel make:enum Status/OrderStatus
/// dowel make:enum IncidentSeverity --wire # Wire-backed enum
/// ```
///
/// ## Output
///
/// Creates a file in `lib/app/enums/` with value/label pattern,
/// `fromValue()` factory, and `selectOptions` getter. With `--wire`, creates
/// a wire-backed enum instead: an `unknown` fallback case, a `fromWire()`
/// factory that never throws on an unrecognised value, and a `trans()`-backed
/// `label` getter.
class MakeEnumCommand extends DowelGeneratorCommand {
  /// Optional test root override: injected in tests to avoid touching the
  /// real filesystem.
  final String? _testRoot;

  /// Captures the parsed `--wire` flag at [handle] time so [getStub] can
  /// honour it without re-reading the [DowelContext.input].
  bool _wireFlag = false;

  /// Creates a [MakeEnumCommand].
  ///
  /// Pass [_testRoot] to pin the project root to a temp directory during tests.
  MakeEnumCommand({this._testRoot});

  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  String get name => 'make:enum';

  @override
  String get description => 'Create a new enum';

  @override
  String getDefaultNamespace() => 'lib/app/enums';

  @override
  String getProjectRoot() => _testRoot ?? super.getProjectRoot();

  @override
  void configure(ArgParser parser) {
    super.configure(parser);
    parser.addFlag(
      'wire',
      help: 'Generate a wire-backed enum mirroring a backend string value',
      negatable: false,
    );
  }

  @override
  String getStub() => MagicStubLoader.load(_wireFlag ? 'enum.wire' : 'enum');

  /// Returns placeholder replacements for the enum stub.
  ///
  /// Replaces `{{ className }}` and `{{ snakeName }}` from the parsed name.
  @override
  Map<String, String> getReplacements(String name) {
    final parsed = StringHelper.parseName(name);

    return {
      '{{ className }}': parsed.className,
      '{{ snakeName }}': StringHelper.toSnakeCase(parsed.className),
    };
  }

  @override
  Future<int> handle(DowelContext ctx) async {
    // 1. Capture --wire so getStub() selects the right template.
    _wireFlag = ctx.input.hasOption('wire');
    return super.handle(ctx);
  }
}
