import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/cli/helpers/main_dart_smart_merger.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// Fresh flutter create counter-app with an async main — no Magic yet.
const String _freshAsyncSource = '''
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: const Scaffold(),
    );
  }
}
''';

/// Sync main — should be rejected.
const String _syncMainSource = '''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}
''';

/// Source that already has Magic fully merged (used for idempotence tests).
const String _alreadyMergedSource = '''
import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart';
import 'config/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Magic.init(configFactories: [
    () => appConfig,
  ]);
  runApp(MagicApplication(child: MyApp(), appName: 'Uptizm'));
}
''';

/// Source that already has the magic import but no Magic.init call yet.
const String _alreadyHasMagicImportSource = '''
import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

void main() async {
  runApp(const MyApp());
}
''';

void main() {
  // ---------------------------------------------------------------------------
  // 1. Happy path: fresh async counter-app gets all 3 mutations applied
  // ---------------------------------------------------------------------------
  group('MainDartSmartMerger.mergeMagicInto — happy path', () {
    test('adds magic + wind imports, injects Magic.init, wraps runApp', () {
      final result = MainDartSmartMerger.mergeMagicInto(
        _freshAsyncSource,
        appName: 'Uptizm',
        configImports: ["import 'config/app.dart';"],
        configFactories: ['() => appConfig'],
      );

      // Magic import added.
      expect(result, contains("import 'package:magic/magic.dart';"));

      // Wind import added.
      expect(
        result,
        contains("import 'package:fluttersdk_wind/fluttersdk_wind.dart';"),
      );

      // Config import added.
      expect(result, contains("import 'config/app.dart';"));

      // Magic.init injected with the factory.
      expect(result, contains('await Magic.init('));
      expect(result, contains('() => appConfig'));

      // runApp wrapped with MagicApplication.
      expect(result, contains('runApp(MagicApplication('));
      expect(result, contains("appName: 'Uptizm'"));
    });

    test('imports are placed before the flutter/material.dart line', () {
      final result = MainDartSmartMerger.mergeMagicInto(
        _freshAsyncSource,
        appName: 'Uptizm',
        configImports: [],
        configFactories: [],
      );

      final materialIndex = result.indexOf(
        "import 'package:flutter/material.dart';",
      );
      final magicIndex = result.indexOf("import 'package:magic/magic.dart';");
      expect(magicIndex, isNot(-1));
      expect(magicIndex, lessThan(materialIndex));
    });

    test(
      'Magic.init is inserted immediately after the main() async { line',
      () {
        final result = MainDartSmartMerger.mergeMagicInto(
          _freshAsyncSource,
          appName: 'Uptizm',
          configImports: [],
          configFactories: [],
        );

        final mainLineIndex = result.indexOf('void main() async {');
        final magicInitIndex = result.indexOf('await Magic.init(');
        expect(mainLineIndex, isNot(-1));
        expect(magicInitIndex, isNot(-1));
        // Magic.init must appear after the main() line.
        expect(magicInitIndex, greaterThan(mainLineIndex));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // 2. Sync main rejection
  // ---------------------------------------------------------------------------
  group('MainDartSmartMerger.mergeMagicInto — sync main rejection', () {
    test('throws FormatException when main() is synchronous', () {
      expect(
        () => MainDartSmartMerger.mergeMagicInto(
          _syncMainSource,
          appName: 'App',
          configImports: [],
          configFactories: [],
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('FormatException message names both --preserve and --force', () {
      try {
        MainDartSmartMerger.mergeMagicInto(
          _syncMainSource,
          appName: 'App',
          configImports: [],
          configFactories: [],
        );
        fail('expected FormatException');
      } on FormatException catch (e) {
        expect(e.message, contains('--preserve'));
        expect(e.message, contains('--force'));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Idempotence: re-running on already-merged source returns equivalent
  // ---------------------------------------------------------------------------
  group('MainDartSmartMerger.mergeMagicInto — idempotence', () {
    test('second call on already-merged source yields identical result', () {
      final once = MainDartSmartMerger.mergeMagicInto(
        _freshAsyncSource,
        appName: 'Uptizm',
        configImports: ["import 'config/app.dart';"],
        configFactories: ['() => appConfig'],
      );
      final twice = MainDartSmartMerger.mergeMagicInto(
        once,
        appName: 'Uptizm',
        configImports: ["import 'config/app.dart';"],
        configFactories: ['() => appConfig'],
      );
      expect(twice, equals(once));
    });

    test('fully-merged fixture re-runs without duplication', () {
      final result = MainDartSmartMerger.mergeMagicInto(
        _alreadyMergedSource,
        appName: 'Uptizm',
        configImports: ["import 'config/app.dart';"],
        configFactories: ['() => appConfig'],
      );

      // No duplicate imports.
      expect("import 'package:magic/magic.dart';".allMatches(result).length, 1);
      // No duplicate Magic.init.
      expect('await Magic.init('.allMatches(result).length, 1);
      // runApp still wrapped once only.
      expect('MagicApplication('.allMatches(result).length, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Missing runApp throws StateError from wrapRunApp path
  // ---------------------------------------------------------------------------
  group('MainDartSmartMerger.mergeMagicInto — missing runApp', () {
    test('throws StateError when source has no runApp call', () {
      const noRunApp = '''
import 'package:flutter/material.dart';

void main() async {
  print('hello');
}
''';
      expect(
        () => MainDartSmartMerger.mergeMagicInto(
          noRunApp,
          appName: 'App',
          configImports: [],
          configFactories: [],
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Multi-import preservation: user's custom imports are kept
  // ---------------------------------------------------------------------------
  group('MainDartSmartMerger.mergeMagicInto — multi-import preservation', () {
    test('existing user imports are preserved after merge', () {
      const withExtraImport = '''
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() async {
  runApp(const MyApp());
}
''';
      final result = MainDartSmartMerger.mergeMagicInto(
        withExtraImport,
        appName: 'App',
        configImports: [],
        configFactories: [],
      );

      expect(
        result,
        contains("import 'package:sentry_flutter/sentry_flutter.dart';"),
      );
      expect(result, contains("import 'package:flutter/material.dart';"));
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Empty configImports / configFactories: Magic.init still injected
  // ---------------------------------------------------------------------------
  group('MainDartSmartMerger.mergeMagicInto — empty config lists', () {
    test('Magic.init is injected even when configFactories is empty', () {
      final result = MainDartSmartMerger.mergeMagicInto(
        _freshAsyncSource,
        appName: 'Uptizm',
        configImports: [],
        configFactories: [],
      );

      expect(result, contains('await Magic.init('));
    });

    test('no config imports are added when configImports is empty', () {
      final result = MainDartSmartMerger.mergeMagicInto(
        _freshAsyncSource,
        appName: 'Uptizm',
        configImports: [],
        configFactories: [],
      );

      // Magic + wind imports still present; no phantom config imports.
      expect(result, contains("import 'package:magic/magic.dart';"));
      expect(
        result,
        contains("import 'package:fluttersdk_wind/fluttersdk_wind.dart';"),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Already-has-magic-import: no duplicate import added
  // ---------------------------------------------------------------------------
  group('MainDartSmartMerger.mergeMagicInto — already has magic import', () {
    test('does not add a duplicate magic import when it already exists', () {
      final result = MainDartSmartMerger.mergeMagicInto(
        _alreadyHasMagicImportSource,
        appName: 'Uptizm',
        configImports: [],
        configFactories: [],
      );

      expect("import 'package:magic/magic.dart';".allMatches(result).length, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // 8. runApp already wrapped: idempotent (no double-wrapping)
  // ---------------------------------------------------------------------------
  group('MainDartSmartMerger.mergeMagicInto — runApp already wrapped', () {
    test(
      'does not double-wrap runApp when MagicApplication is already the child',
      () {
        final result = MainDartSmartMerger.mergeMagicInto(
          _alreadyMergedSource,
          appName: 'Uptizm',
          configImports: ["import 'config/app.dart';"],
          configFactories: ['() => appConfig'],
        );

        // runApp still appears exactly once.
        expect('runApp('.allMatches(result).length, 1);
        // MagicApplication still appears exactly once as the wrapper.
        expect('MagicApplication('.allMatches(result).length, 1);
      },
    );
  });
}
