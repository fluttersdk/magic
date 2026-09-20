import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:sqlite3/sqlite3.dart';

/// A migration whose `up` does two statements and can be told to fail between
/// them, which is the shape that makes a partial application visible.
class _TwoStepMigration extends Migration {
  _TwoStepMigration(this.name, {this.throwsAfterFirst = false});

  @override
  final String name;

  /// Whether to throw once the first statement is applied.
  final bool throwsAfterFirst;

  @override
  void up() {
    DB.statement('CREATE TABLE IF NOT EXISTS ${name}_a (x TEXT)');

    if (throwsAfterFirst) throw StateError('migration $name failed part way');

    DB.statement('CREATE TABLE IF NOT EXISTS ${name}_b (x TEXT)');
  }

  @override
  void down() {
    DB.statement('DROP TABLE IF EXISTS ${name}_b');
    DB.statement('DROP TABLE IF EXISTS ${name}_a');
  }
}

/// A migration that closes the migrator's own transaction from inside `up`.
///
/// `DB.beginTransaction` / `commit` / `rollback` are a documented pattern
/// (`doc/database/getting-started.md:195`), so a migration written this way was
/// legitimate before `run` opened a transaction of its own.
class _CommittingMigration extends Migration {
  _CommittingMigration(this.name);

  @override
  final String name;

  @override
  void up() {
    DB.statement('CREATE TABLE IF NOT EXISTS ${name}_a (x TEXT)');
    DB.commit();
  }

  @override
  void down() {}
}

/// A migration that fails is rolled back, and a run that fails leaves nothing.
///
/// **The state this prevents is a permanent boot with no UI.** `run` applied
/// and recorded each migration in turn with no transaction anywhere, so a
/// failure part way left that migration's earlier statements applied and its
/// ledger row absent. Every later launch re-ran it from its first statement,
/// which was already applied, and failed identically. A host that runs
/// migrations inside `Magic.init` before `runApp` never renders again, and the
/// only repair is deleting the database.
///
/// SQLite rolls DDL back like anything else, which is what makes the fix one
/// `BEGIN`. Verified: `CREATE TABLE a(x); BEGIN; CREATE TABLE b(y); ROLLBACK;`
/// leaves only `a`.
void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    DatabaseManager().setConnection(sqlite3.openInMemory());
  });

  tearDown(DatabaseManager().dispose);

  /// Whether a table exists right now.
  bool exists(String table) => DB.select(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
    <Object?>[table],
  ).isNotEmpty;

  test('a migration that throws part way applies none of itself', () async {
    await expectLater(
      Migrator().run(<Migration>[
        _TwoStepMigration('half', throwsAfterFirst: true),
      ]),
      throwsA(isA<StateError>()),
    );

    expect(
      exists('half_a'),
      isFalse,
      reason: 'the first statement survived a failed migration',
    );
    expect(exists('half_b'), isFalse);
  });

  test('an earlier migration in the same run is rolled back too', () async {
    // The whole run is one unit, not each migration. A ledger that records
    // one and not the next describes a schema nobody designed, and the host
    // has no way to know which half it has.
    await expectLater(
      Migrator().run(<Migration>[
        _TwoStepMigration('first'),
        _TwoStepMigration('second', throwsAfterFirst: true),
      ]),
      throwsA(isA<StateError>()),
    );

    expect(exists('first_a'), isFalse);
    expect(exists('second_a'), isFalse);
  });

  test('the ledger records nothing for a run that failed', () async {
    await expectLater(
      Migrator().run(<Migration>[
        _TwoStepMigration('kept'),
        _TwoStepMigration('broken', throwsAfterFirst: true),
      ]),
      throwsA(isA<StateError>()),
    );

    // The tracking table itself survives: it is created outside the
    // transaction on purpose, because a database with no ledger and no
    // migrations is the state a fresh install is in anyway.
    expect(exists('magic_migrations'), isTrue);
    expect(DB.select('SELECT migration FROM magic_migrations'), isEmpty);
  });

  test('a retry after a failure succeeds rather than repeating it', () async {
    // The point of the rollback. Before it, the second attempt met a table
    // that already existed and threw again, for ever.
    await expectLater(
      Migrator().run(<Migration>[
        _TwoStepMigration('retry', throwsAfterFirst: true),
      ]),
      throwsA(isA<StateError>()),
    );

    await Migrator().run(<Migration>[_TwoStepMigration('retry')]);

    expect(exists('retry_a'), isTrue);
    expect(exists('retry_b'), isTrue);
    expect(DB.select('SELECT migration FROM magic_migrations'), hasLength(1));
  });

  test('a successful run still commits', () async {
    final List<String> ran = await Migrator().run(<Migration>[
      _TwoStepMigration('one'),
      _TwoStepMigration('two'),
    ]);

    expect(ran, <String>['one', 'two']);
    expect(exists('one_b'), isTrue);
    expect(exists('two_b'), isTrue);
  });

  test('a caller that opened its own transaction is not nested into', () async {
    // sqlite refuses a nested BEGIN with `cannot start a transaction within a
    // transaction`, so a migrator that opened one unconditionally would break
    // every host that already wraps the call. `autocommit` is false exactly
    // when a transaction is open, which is the only thing that can tell them
    // apart.
    await DB.transaction(
      () => Migrator().run(<Migration>[_TwoStepMigration('wrapped')]),
    );

    expect(exists('wrapped_b'), isTrue);
  });

  test(
    'a stale schema cache for the ledger does not silence the record',
    () async {
      // The ledger is created with a raw `execute`, which no cache hears about.
      // Reading its columns first caches the empty answer a missing table gives,
      // and `QueryBuilder.insert` filters every key against that cache: an empty
      // filter returns 0 WITHOUT inserting and without throwing
      // (`query_builder.dart:278-280`). So every migration would be applied and
      // never recorded, and re-applied on every launch for ever.
      expect(await DatabaseManager().getColumns('magic_migrations'), isEmpty);

      await Migrator().run(<Migration>[_TwoStepMigration('cached')]);

      expect(
        DB.select('SELECT migration FROM magic_migrations'),
        hasLength(1),
        reason: 'the migration ran and was not recorded, so it will run again',
      );
    },
  );

  test(
    'a failure inside a caller-owned transaction still rolls back',
    () async {
      // The caller's transaction does the work here rather than the migrator's,
      // which is the point of deferring to it.
      await expectLater(
        DB.transaction(
          () => Migrator().run(<Migration>[
            _TwoStepMigration('outer', throwsAfterFirst: true),
          ]),
        ),
        throwsA(isA<StateError>()),
      );

      expect(exists('outer_a'), isFalse);
    },
  );

  group('a migration that manages its own transaction', () {
    test(
      'is named in the error rather than reported as a late failure',
      () async {
        // The shape this replaces was the worst possible one. A `COMMIT` inside
        // `up` closed the migrator's own transaction, so every later migration
        // ran unprotected and the migrator's closing statement threw AFTER every
        // migration had succeeded and its ledger row had been committed. The
        // caller saw a failure from a run that had fully worked, and the retry
        // found nothing pending.
        await expectLater(
          Migrator().run(<Migration>[_CommittingMigration('selfcommit')]),
          throwsA(
            isA<StateError>().having(
              (StateError e) => e.message,
              'message',
              allOf(contains('selfcommit'), contains('transaction')),
            ),
          ),
        );
      },
    );

    test(
      'is named even when the host wrapped the call in its own transaction',
      () async {
        // The diagnostic used to be destroyed in exactly the shape this PR
        // tells hosts they may use. The migration's `commit()` closes the
        // HOST's transaction too, so `DB.transaction`'s catch found nothing to
        // roll back and sqlite threw `cannot rollback - no transaction is
        // active` over the StateError naming the migration.
        await expectLater(
          DB.transaction(
            () => Migrator().run(<Migration>[
              _CommittingMigration('wrappedcommit'),
            ]),
          ),
          throwsA(
            isA<StateError>().having(
              (StateError e) => e.message,
              'message',
              contains('wrappedcommit'),
            ),
          ),
        );
      },
    );

    test('does not leave a later migration running unprotected', () async {
      await expectLater(
        Migrator().run(<Migration>[
          _CommittingMigration('selfcommit'),
          _TwoStepMigration('after', throwsAfterFirst: true),
        ]),
        throwsA(isA<StateError>()),
      );

      // `after` must never have run at all: the guard stops the loop on the
      // migration that broke the contract rather than carrying on.
      expect(exists('after_a'), isFalse);
    });
  });
}
