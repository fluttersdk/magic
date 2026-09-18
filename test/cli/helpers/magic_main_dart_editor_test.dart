import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/cli/helpers/magic_main_dart_editor.dart';

/// Minimal main.dart fixture containing a single-line Magic.init call.
const String _singleLineSource = '''
void main() async {
  await Magic.init(configs: []);
  runApp(MagicApplication());
}
''';

/// Multi-line Magic.init fixture (nested configFactories list).
const String _multiLineSource = '''
void main() async {
  await Magic.init(
    configs: [
      () => appConfig,
      () => authConfig,
    ],
  );
  runApp(MagicApplication());
}
''';

void main() {
  // ---------------------------------------------------------------------------
  // injectBeforeMagicInit
  // ---------------------------------------------------------------------------

  group('MagicMainDartEditor.injectBeforeMagicInit', () {
    test(
      'delegates to MainDartEditor.injectBeforeAnchor with Magic.init anchor',
      () {
        // The snippet should be inserted before the line containing 'Magic.init'.
        const snippet = '  DuskPlugin.install();\n';
        final result = MagicMainDartEditor.injectBeforeMagicInit(
          source: _singleLineSource,
          snippet: snippet,
        );

        // The snippet must appear before the Magic.init line.
        final snippetIndex = result.indexOf(snippet.trim());
        final initIndex = result.indexOf('Magic.init');
        expect(
          snippetIndex,
          isNot(-1),
          reason: 'snippet must be present in result',
        );
        expect(
          snippetIndex,
          lessThan(initIndex),
          reason: 'snippet must precede Magic.init',
        );
      },
    );

    test(
      'is idempotent — calling twice with same snippet leaves source unchanged',
      () {
        const snippet = '  DuskPlugin.install();\n';
        final once = MagicMainDartEditor.injectBeforeMagicInit(
          source: _singleLineSource,
          snippet: snippet,
        );
        final twice = MagicMainDartEditor.injectBeforeMagicInit(
          source: once,
          snippet: snippet,
        );
        expect(twice, equals(once));
      },
    );

    test('returns source unchanged when Magic.init is absent', () {
      const source = '''
void main() async {
  runApp(MagicApplication());
}
''';
      final result = MagicMainDartEditor.injectBeforeMagicInit(
        source: source,
        snippet: '  DuskPlugin.install();\n',
      );
      expect(result, equals(source));
    });

    test('respects optional indent parameter', () {
      const snippet = 'DuskPlugin.install();\n';
      const indent = '  ';
      final result = MagicMainDartEditor.injectBeforeMagicInit(
        source: _singleLineSource,
        snippet: snippet,
        indent: indent,
      );
      // With indent applied the inserted line should have leading spaces.
      expect(result, contains('  DuskPlugin.install();'));
    });

    test('works on multi-line Magic.init call', () {
      const snippet = '  SentryFlutter.init();\n';
      final result = MagicMainDartEditor.injectBeforeMagicInit(
        source: _multiLineSource,
        snippet: snippet,
      );
      final snippetIndex = result.indexOf(snippet.trim());
      final initIndex = result.indexOf('await Magic.init');
      expect(snippetIndex, isNot(-1));
      expect(snippetIndex, lessThan(initIndex));
    });
  });

  // ---------------------------------------------------------------------------
  // injectAfterMagicInit
  // ---------------------------------------------------------------------------

  group('MagicMainDartEditor.injectAfterMagicInit', () {
    test(
      'inserts snippet after the closing paren of Magic.init on a single-line call',
      () {
        const snippet = '  MagicDuskIntegration.install();\n';
        final result = MagicMainDartEditor.injectAfterMagicInit(
          source: _singleLineSource,
          snippet: snippet,
        );

        // Snippet must appear after the Magic.init line and before runApp.
        final snippetIndex = result.indexOf(snippet.trim());
        final initIndex = result.indexOf('Magic.init');
        final runAppIndex = result.indexOf('runApp');
        expect(
          snippetIndex,
          isNot(-1),
          reason: 'snippet must be present in result',
        );
        expect(
          snippetIndex,
          greaterThan(initIndex),
          reason: 'snippet must follow Magic.init',
        );
        expect(
          snippetIndex,
          lessThan(runAppIndex),
          reason: 'snippet must precede runApp',
        );
      },
    );

    test('inserts snippet after closing paren of multi-line Magic.init', () {
      const snippet = '  MagicDuskIntegration.install();\n';
      final result = MagicMainDartEditor.injectAfterMagicInit(
        source: _multiLineSource,
        snippet: snippet,
      );

      final snippetIndex = result.indexOf(snippet.trim());
      final initIndex = result.indexOf('await Magic.init');
      final runAppIndex = result.indexOf('runApp');
      expect(snippetIndex, isNot(-1));
      expect(snippetIndex, greaterThan(initIndex));
      expect(snippetIndex, lessThan(runAppIndex));
    });

    test(
      'is idempotent — calling twice with same snippet leaves source unchanged',
      () {
        const snippet = '  MagicDuskIntegration.install();\n';
        final once = MagicMainDartEditor.injectAfterMagicInit(
          source: _singleLineSource,
          snippet: snippet,
        );
        final twice = MagicMainDartEditor.injectAfterMagicInit(
          source: once,
          snippet: snippet,
        );
        expect(twice, equals(once));
      },
    );

    test('returns source unchanged when Magic.init is absent', () {
      const source = '''
void main() async {
  runApp(MagicApplication());
}
''';
      final result = MagicMainDartEditor.injectAfterMagicInit(
        source: source,
        snippet: '  MagicDuskIntegration.install();\n',
      );
      expect(result, equals(source));
    });
  });
}
