import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_artisan/artisan.dart';
import 'package:magic/src/cli/commands/make_lang_command.dart';
import 'package:path/path.dart' as p;

import '_harness.dart';

/// Flattens a nested JSON map into dot-joined leaf key paths (e.g.
/// `{"common": {"back": "Back"}}` -> `['common.back']`). Used to assert
/// key-tree parity between a source and a generated locale without
/// requiring identical leaf VALUES.
List<String> _flattenKeys(Map<String, dynamic> map, [String prefix = '']) {
  final keys = <String>[];
  for (final entry in map.entries) {
    final path = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
    final value = entry.value;
    if (value is Map<String, dynamic>) {
      keys.addAll(_flattenKeys(value, path));
    } else {
      keys.add(path);
    }
  }
  return keys;
}

void main() {
  group('MakeLangCommand metadata', () {
    final cmd = MakeLangCommand();

    test('declares name make:lang', () {
      expect(cmd.name, 'make:lang');
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });
  });

  group('MakeLangCommand.handle()', () {
    late Directory projectRoot;

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_lang_');
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    /// Seeds `assets/lang/<code>.json` with [content] under [projectRoot].
    void seedLocale(String code, Map<String, dynamic> content) {
      final file = File(
        p.join(projectRoot.path, 'assets', 'lang', '$code.json'),
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(content));
    }

    test('copies the source key tree with identical flattened paths', () async {
      seedLocale('en', <String, dynamic>{
        'common': <String, dynamic>{'back': 'Back', 'save': 'Save'},
        'validation': <String, dynamic>{
          'required': 'The :attribute field is required.',
        },
      });

      final cmd = MakeLangCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(buildCommandContext(cmd, <String>['tr']));

      expect(code, 0);
      final file = File(p.join(projectRoot.path, 'assets', 'lang', 'tr.json'));
      expect(file.existsSync(), isTrue);

      final source =
          jsonDecode(
                File(
                  p.join(projectRoot.path, 'assets', 'lang', 'en.json'),
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final generated =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      expect(_flattenKeys(generated), _flattenKeys(source));
    });

    test(
      'copies each leaf value from the source (no machine translation)',
      () async {
        seedLocale('en', <String, dynamic>{
          'common': <String, dynamic>{'back': 'Back'},
        });

        final cmd = MakeLangCommand(testRoot: projectRoot.path);
        await cmd.handle(buildCommandContext(cmd, <String>['tr']));

        final file = File(
          p.join(projectRoot.path, 'assets', 'lang', 'tr.json'),
        );
        final generated =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        expect((generated['common'] as Map<String, dynamic>)['back'], 'Back');
      },
    );

    test('writes two-space indented JSON', () async {
      seedLocale('en', <String, dynamic>{
        'common': <String, dynamic>{'back': 'Back'},
      });

      final cmd = MakeLangCommand(testRoot: projectRoot.path);
      await cmd.handle(buildCommandContext(cmd, <String>['tr']));

      final file = File(p.join(projectRoot.path, 'assets', 'lang', 'tr.json'));
      expect(file.readAsStringSync(), contains('  "common"'));
    });

    test('--from=de with no de.json writes {}', () async {
      seedLocale('en', <String, dynamic>{
        'common': <String, dynamic>{'back': 'Back'},
      });

      final cmd = MakeLangCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['tr', '--from=de']),
      );

      expect(code, 0);
      final file = File(p.join(projectRoot.path, 'assets', 'lang', 'tr.json'));
      expect(file.readAsStringSync(), '{}');
    });

    test('without a source locale the file is {}', () async {
      final cmd = MakeLangCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(buildCommandContext(cmd, <String>['tr']));

      expect(code, 0);
      final file = File(p.join(projectRoot.path, 'assets', 'lang', 'tr.json'));
      expect(file.readAsStringSync(), '{}');
    });

    test('make:lang en with no en.json still writes {}', () async {
      final cmd = MakeLangCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(buildCommandContext(cmd, <String>['en']));

      expect(code, 0);
      final file = File(p.join(projectRoot.path, 'assets', 'lang', 'en.json'));
      expect(file.readAsStringSync(), '{}');
    });

    test('refuses to overwrite an existing target without --force', () async {
      seedLocale('en', <String, dynamic>{
        'common': <String, dynamic>{'back': 'Back'},
      });
      seedLocale('tr', <String, dynamic>{});

      final cmd = MakeLangCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(buildCommandContext(cmd, <String>['tr']));

      expect(code, 1);
    });

    test(
      'make:lang en --from=en is refused by the existing-file check',
      () async {
        seedLocale('en', <String, dynamic>{
          'common': <String, dynamic>{'back': 'Back'},
        });

        final cmd = MakeLangCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          buildCommandContext(cmd, <String>['en', '--from=en']),
        );

        expect(code, 1);
      },
    );

    test('overwrites with --force', () async {
      seedLocale('en', <String, dynamic>{
        'common': <String, dynamic>{'back': 'Back'},
      });
      seedLocale('tr', <String, dynamic>{});

      final cmd = MakeLangCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['tr', '--force']),
      );

      expect(code, 0);
      final file = File(p.join(projectRoot.path, 'assets', 'lang', 'tr.json'));
      final generated =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(generated.containsKey('common'), isTrue);
    });
  });
}
