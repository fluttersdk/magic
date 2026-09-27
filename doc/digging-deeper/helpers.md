# Helpers

`Str`, `Number`, and `Arr` are static namespace helpers modelled on Laravel's Support layer, and `Cast` is magic's own, together covering locale-aware casing, locale-aware number formatting, dot-path map access, and defensive type reading for loosely-typed wire data. `AppLifecycle` is a small, unrelated static namespace for reading the app lifecycle as a stream from code that runs before a `WidgetsBinding` necessarily exists.

- [Str](#str)
- [Number](#number)
- [Arr](#arr)
- [Cast](#cast)
- [Composing Arr and Cast](#composing-arr-and-cast)
- [AppLifecycle](#applifecycle)
- [LatestRead](#latestread)
- [Poll](#poll)
- [Countdown](#countdown)
- [Debouncer](#debouncer)
- [UrlGenerator](#urlgenerator)

<a name="str"></a>
## Str

`Str.upper` and `Str.lower` are locale-aware replacements for `String.toUpperCase()`/`toLowerCase()`, which get Turkish and Azerbaijani wrong: those alphabets distinguish a dotted `i` from a dotless `ı`, a pair Dart's own mapping conflates. Every method defaults its `locale` to `Lang.current.languageCode`, and accepts a full tag (`tr_TR`, `tr-TR`) as well as a bare language code.

```dart
Str.upper('çalışan izleyiciler', locale: 'tr'); // 'ÇALIŞAN İZLEYİCİLER'
Str.upper('istanbul', locale: 'en');            // 'ISTANBUL'

Str.lower('İSTANBUL', locale: 'tr');            // 'istanbul'
Str.lower('IŞIK', locale: 'tr');                // 'ışık'
```

`Str.initials(value, {limit, capitalize, locale})` takes the first letter of each whitespace-separated word. `limit` (greater than 0) keeps only the first N words; `capitalize` routes the result through `Str.upper` under `locale`. A blank or null `value` returns `''`.

```dart
Str.initials('ismail kaya', limit: 2, capitalize: true, locale: 'tr'); // 'İK'
```

`Str.unwrap(value, before, [after])` strips `before` from the start and `after` (default `before`) from the end, each checked and stripped independently, mirroring Laravel's `Str::unwrap`. A prefix-only match (`'"x'`) loses the leading quote and is left unbalanced rather than untouched.

```dart
Str.unwrap('"quoted"', '"');       // 'quoted'
Str.unwrap('"x', '"');             // 'x', prefix-only match still strips
Str.unwrap('[value]', '[', ']');   // 'value'
```

`Str.ascii(value)` folds Latin-1 Supplement and Latin Extended-A letters, the Romanian comma-below letters `Ș ș Ț ț`, `ẞ`, and the Angstrom sign U+212B to their plain ASCII base, for building a search key. Combining marks (U+0300-U+036F) are always dropped, whatever letter they decorate. A Latin letter outside that coverage (Vietnamese, the rest of Latin Extended-B/Additional) and every other script pass through untouched; magic folds Latin only, unlike Laravel's `Str::ascii`, which transliterates every script it has a table for and would otherwise collapse a non-Latin word to `?` or a phonetic guess.

```dart
Str.ascii('çalışan izleyiciler'); // 'calisan izleyiciler'
Str.ascii('Ångström');            // 'Angstrom'
```

`Str.squish(value)` trims `value` and collapses every run of whitespace to one space, mirroring Laravel's `Str::squish`. The whitespace class is Dart's `\s` plus the two Hangul filler code points (U+3164, U+1160) a rendered blank can carry without registering as `\s`; both ends of `value` are checked against the same class, so a boundary and a middle occurrence of the same code point fold the same way.

```dart
Str.squish('  hello   world  '); // 'hello world'
```

<a name="number"></a>
## Number

`Number` formats numeric values with a locale's own grouping, decimal, and currency conventions, resolving `locale` (or `Lang.current` when omitted) through `Intl.verifiedLocale`; an unknown locale falls back to `'en'` instead of throwing inside a `build` method.

```dart
Number.format(1234567.891, maxPrecision: 3, locale: 'tr'); // '1.234.567,891'
Number.format(1234567.891, maxPrecision: 3, locale: 'en'); // '1,234,567.891'
```

`Number.currency(amount, {code, precision, locale})` is built on `NumberFormat.simpleCurrency`, not `NumberFormat.currency`: the latter renders the bare ISO code with no symbol (`'TRY1.234,50'`), while `simpleCurrency` resolves the locale's own symbol.

```dart
Number.currency(1234.5, code: 'TRY', locale: 'tr'); // '₺1.234,50'
```

`Number.percentage(value, {precision, maxPrecision, locale})` takes a 0-100 input like Laravel's `Number::percentage()`, not intl's native 0-1 fraction, so a caller never has to remember to divide by 100 first.

```dart
Number.percentage(99.95, precision: 2, locale: 'tr'); // '%99,95'
Number.percentage(99.95, precision: 2, locale: 'en'); // '99.95%'
```

`Number.fileSize(bytes, {precision, maxPrecision, locale})` steps by 1024 (B, KB, MB, GB, TB, PB) and formats the final number through `Number.format`.

```dart
Number.fileSize(1536, maxPrecision: 1, locale: 'en'); // '1.5 KB'
```

`Number.abbreviate(value, {precision, maxPrecision, locale})` compacts a value with the locale's own unit letters (`Mn`, `B` for Turkish; `M`, `K` for English).

```dart
Number.abbreviate(1500000, maxPrecision: 1, locale: 'tr'); // '1,5 Mn'
```

<a name="arr"></a>
## Arr

`Arr` carries dot-path access into a nested `Map<String, dynamic>`, mirroring Laravel's `Arr::get` / `has` / `set` / `dot`.

```dart
Arr.get({'a': {'b': [10, 20]}}, 'a.b.1'); // 20
Arr.has({'a': {'b': 1}}, 'a.b');          // true

final map = <String, dynamic>{};
Arr.set(map, 'a.b.c', 1);                 // {'a': {'b': {'c': 1}}}

Arr.dot({'a': {'b': 1}});                 // {'a.b': 1}
```

An exact key wins over walking the path: a map that happens to hold a literal `'a.b'` key reads that value rather than descending into `map['a']['b']`. A numeric path segment indexes into a `List` at that position. `Arr.get` answers the given fallback (`null` by default) when the path is unreachable.

**`Arr` carries no typed accessors.** There is no `Arr.getString`, `Arr.getInt`, or similar; typing a value read off a path is [Cast](#cast)'s job, composed at the call site.

<a name="cast"></a>
## Cast

`Cast` reads a loosely-typed wire value (a field out of a nested map or a pivot row that has not gone through the ORM's own coercion) as a specific Dart type, degrading to a fallback instead of throwing. Use it on a value pulled out of a decoded JSON map, not on a model attribute, since the ORM already coerces those through `get<T>`.

```dart
Cast.stringOr('hello', 'fallback');   // 'hello'
Cast.stringOr(42, 'fallback');        // 'fallback'
Cast.stringOrNull(42);                // null

Cast.intOr(3.9, 0);                   // 3
Cast.intOr('3', 0);                   // 3, the one reader that parses a numeric string
Cast.intOr('abc', 0);                 // 0

Cast.intOrNull('3');                  // null, unlike intOr
Cast.numOrNull(3.5);                  // 3.5
Cast.doubleOrNull(3);                 // 3.0

Cast.boolOr('yes', false);            // false, only a real bool passes
Cast.boolOrNull(false);               // false

Cast.idOrNull(42);                    // '42', a num stringifies rather than degrading
Cast.idOrNull('abc-123');             // 'abc-123'
Cast.idOrNull(true);                  // null
```

`Cast.intOr` is the one reader that parses a numeric string, because the fields it serves are orders and durations, and silently falling back on `"3"` would sort a list wrongly or shorten a delay. Every other reader (`numOrNull`, `doubleOrNull`, `intOrNull`) leaves a numeric string as unreadable, so the caller's own `?? fallback` decides what it means rather than a number appearing on a chart from a value the backend was not supposed to send. `Cast.idOrNull` stringifies a number rather than answering null, because a primary key can be a uuid or a bigint depending on backend configuration, and reading an int id as null would corrupt a save-diff that branches on a null id to mean "create this row".

<a name="composing-arr-and-cast"></a>
## Composing Arr and Cast

`Arr.get` performs no type check of its own; compose it with `Cast` at the call site for a typed read off a nested payload:

```dart
final priority = Cast.intOr(Arr.get(payload, 'meta.priority'), 0);
final label = Cast.stringOrNull(Arr.get(payload, 'meta.label'));
```

<a name="applifecycle"></a>
## AppLifecycle

`AppLifecycle.states()` exposes the app lifecycle as a `Stream<AppLifecycleState>`, for a reader constructed before a `WidgetsBinding` necessarily exists. A dependency built inside a service provider's `register()` runs before the app has bound anything, so reaching for `WidgetsBinding.instance` at construction time throws; `AppLifecycle.states()` defers that lookup to the moment a listener actually subscribes.

```dart
final subscription = AppLifecycle.states().listen((state) {
  if (state == AppLifecycleState.paused) Log.info('app paused');
});

// Later, when done:
await subscription.cancel();
```

Each subscription owns its own observer: it is added to the binding on `listen` and removed on `cancel`, so nothing outlives its reader and nothing before the first `listen` touches the binding at all. Prefer Flutter's own `AppLifecycleListener` when the reader is a widget-lifetime object; reach for `AppLifecycle.states()` only when construction has to happen before a binding is guaranteed to exist.

<a name="latestread"></a>
## LatestRead

`LatestRead` drops a stale answer that lands after a newer read for the same key already started, in place of a hand-rolled read counter. `begin([key])` starts a new read and hands back a token; `isCurrent(token, [key])` answers whether that token is still the newest one issued.

```dart
final _reads = LatestRead();

Future<void> loadChecks(String monitorId) async {
  final token = _reads.begin(monitorId);
  final checks = await Http.get('monitors/$monitorId/checks');

  if (!_reads.isCurrent(token, monitorId)) return; // a newer read for this key already started

  setChecks(checks.data);
}
```

`invalidate([key])` bumps the counter without starting a new read, dropping whatever read is currently in flight for `key` when it lands.

<a name="poll"></a>
## Poll

`Poll.until` re-reads on a fixed interval until a value is accepted or an attempt budget runs out, replacing a `Timer`-per-field polling loop hand-rolled once per screen.

```dart
final handle = Poll.until<CheckResult>(
  read: () => Http.get('checks/$checkId').then((r) => r.successful ? CheckResult.fromMap(r.data) : null),
  done: (result) => result.status != 'pending',
  every: const Duration(seconds: 2),
  maxAttempts: 15,
);

final outcome = await handle.result;
switch (outcome) {
  case PollSettled(value: final result):
    setSuccess(result);
  case PollExhausted():
    setError('Check did not finish in time');
  case PollCancelled():
    break; // the caller cancelled; nothing to show
}
```

The first read runs only after one `every` interval, never immediately, since the caller already has whatever state it polled before starting. A `null` read result is treated as "not landed yet" and never reaches `done`; a throwing read spends its attempt like a read that answered nothing, logged rather than propagated. `handle.cancel()` stops the pending read early and settles `PollCancelled`. Cancel a `Poll.until` handle from `OwnsTimers` (`own(Poll.until(...))`) so a controller never has to track it by hand.

<a name="countdown"></a>
## Countdown

`Countdown` is a per-key clock ticking down to zero once a second, for something like a "check now" cooldown per monitor id, where several independent countdowns run without one key's clock interfering with another's.

```dart
final cooldowns = Countdown()..onTick = (key, remaining) => refreshUI();

cooldowns.start(monitorId, 30);
cooldowns.remaining(monitorId);  // seconds left, or null once finished
cooldowns.isRunning(monitorId);
cooldowns.cancel(monitorId);     // or cancelAll()
```

A key's countdown stops and forgets its own state the moment it reaches zero; it never ticks into negative numbers or keeps a finished timer running.

<a name="debouncer"></a>
## Debouncer

`Debouncer` coalesces repeated calls under the same key into one delayed run of the LAST callback given, generalising a single-purpose reload debounce.

```dart
final debouncer = Debouncer();

void onSearchChanged(String query) {
  debouncer.run('search', const Duration(milliseconds: 300), () => search(query));
}
```

Each call to `run` for a given key cancels that key's still-pending timer and arms a fresh one. `cancelAll()` cancels every pending run without firing any of them.

<a name="urlgenerator"></a>
## UrlGenerator

`UrlGenerator` (and the top-level `url()` helper) builds an absolute URL against the app's configured origin, Laravel's `url()`/`URL::to`. It is not named `Url`: that name is already taken by the validation rule at `lib/src/validation/rules/url.dart`.

```dart
url('/terms');                              // 'https://example.com/terms'
UrlGenerator.to('/terms', query: {'ref': 'app'});
UrlGenerator.localized('/pricing');         // '/tr/pricing' under an active non-default locale
```

The origin is read from `Config.get(UrlGenerator.originKey, ...)` (`'app.url'` by default), falling back to `Env.filled('APP_URL', '')`. Override `UrlGenerator.originKey` once, before any call, for an app whose origin config lives under a different key (a marketing-site origin distinct from the API base URL). `localized()` prefixes the active language unless it is the configured default one, or degrades to the bare path when the active language is not in `localization.supported_locales`.
