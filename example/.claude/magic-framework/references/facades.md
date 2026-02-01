# Facade API Reference

## Auth
- `guard([String? name])` → Guard instance
- `login(Map data, Authenticatable user)` → Future<void>
- `logout()` → Future<void>
- `check()` → bool
- `guest` → bool
- `user<T>()` → T?
- `id()` → dynamic
- `hasToken()` → Future<bool>
- `getToken()` → Future<String?>
- `refreshToken()` → Future<bool>
- `restore()` → Future<void>
- `registerModel<T>(T Function(Map) factory)` → void

## Cache
Resolution: `Magic.make<CacheManager>('cache')`
- `put(String key, dynamic value, {Duration? ttl})` → Future<void>
- `get(String key, {dynamic defaultValue})` → Future<dynamic>
- `has(String key)` → Future<bool>
- `forget(String key)` → Future<void>
- `flush()` → Future<void>
- `remember<T>(String key, Duration ttl, Future<T> Function() callback)` → Future<T>

## Config
Resolution: static `MagicApp.config`
- `get<T>(String key, [T? defaultValue])` → T?
- `getOrFail<T>(String key)` → T (throws)
- `set(String key, dynamic value)` → void
- `has(String key)` → bool
- `all()` → Map
- `merge(Map config)` → void
- `prepend(String key, dynamic value)` → void
- `push(String key, dynamic value)` → void
- `forget(String key)` → void
- `flush()` → void

## DB
Resolution: `Magic.make<DatabaseManager>('db')`
- `table(String name)` → QueryBuilder
- `select(String sql, [List? params])` → Future<List<Map>>
- `statement(String sql, [List? params])` → Future<void>
- `insert(String sql, [List? params])` → Future<int>
- `update(String sql, [List? params])` → Future<int>
- `delete(String sql, [List? params])` → Future<int>
- `beginTransaction()` → Future<void>
- `commit()` → Future<void>
- `rollback()` → Future<void>
- `transaction<T>(Future<T> Function() callback)` → Future<T>

## Event
Resolution: static `EventDispatcher.instance`
- `dispatch(MagicEvent event)` → Future<void>

## Http
Resolution: `Magic.make<NetworkDriver>('network')`
- `index(String resource, {Map? filters, Map? headers})` → Future
- `show(String resource, dynamic id, {Map? headers})` → Future
- `store(String resource, Map data, {Map? headers})` → Future
- `update(String resource, dynamic id, Map data, {Map? headers})` → Future
- `destroy(String resource, dynamic id, {Map? headers})` → Future
- `get(String url, {Map? query, Map? headers})` → Future
- `post(String url, {dynamic data, Map? headers})` → Future
- `put(String url, {dynamic data, Map? headers})` → Future
- `delete(String url, {Map? headers})` → Future
- `upload(String url, {Map? data, List? files, Map? headers})` → Future

## Log
Resolution: `Magic.make<LogManager>('log')`
- `log(String level, String message, [Map? context])`
- `emergency/alert/critical/error/warning/notice/info/debug(String message, [Map? context])`
- `channel(String name)` → LogDriver

## Lang
Resolution: static `Translator.instance`
- `get(String key, [Map? replace])` → String
- `has(String key)` → bool
- `current` → String (locale)
- `setLocale(String locale, {bool reload})` → Future<void>
- `detectAndSetLocale()` → Future<void>
- Global helper: `trans(key, [replace])`

## Storage
- `disk([String? name])` → StorageDisk
- `put(String path, dynamic contents, {String? mimeType})` → Future<void>
- `get(String path)` → Future<Uint8List>
- `getFile(String path)` → Future<MagicFile>
- `exists(String path)` → Future<bool>
- `delete(String path)` → Future<void>
- `url(String path)` → Future<String>
- `download(String path, {String? name})` → Future<void>

## Route
Resolution: static `MagicRouter.instance`
- `page(String path, Widget Function() handler)` → MagicRoute
- `group({String? prefix, List? middleware, String? as, Widget Function(Widget)? layout, void Function() routes})` → void
- `layout({Widget Function(Widget) builder, List routes})` → void
- `to(String path, {Map? query})` → void
- `toNamed(String name, {Map? params, Map? query})` → void
- `push(String path)` → void
- `back()` → void
- `replace(String path)` → void
- `config` → RouterConfig (for MaterialApp.router)

## Schema
- `create(String table, void Function(Blueprint) callback)` → Future<void>
- `table(String table, void Function(Blueprint) callback)` → Future<void>
- `dropIfExists(String table)` → Future<void>
- `drop(String table)` → Future<void>
- `hasTable(String table)` → Future<bool>
- `hasColumn(String table, String column)` → Future<bool>
- `getColumns(String table)` → Future<List<String>>
- `rename(String from, String to)` → Future<void>

## Gate
- `define(String ability, bool Function([List?]) callback)` → void
- `before(bool? Function() callback)` → void
- `allows(String ability, [List? arguments])` → bool
- `denies(String ability, [List? arguments])` → bool
- `has(String ability)` → bool

## Crypt
Resolution: `Magic.make<MagicEncrypter>('encrypter')`
- `encrypt(String value)` → String
- `decrypt(String value)` → String
- `encryptWithDeviceKey(String value)` → Future<String>
- `decryptWithDeviceKey(String value)` → Future<String>
- `hasDeviceKey()` → Future<bool>
- `generateDeviceKey()` → Future<void>
- `clearDeviceKey()` → Future<void>

## Vault
Resolution: `Magic.make<MagicVaultService>('vault')`
- `put(String key, String value)` → Future<void>
- `get(String key)` → Future<String?>
- `delete(String key)` → Future<void>
- `flush()` → Future<void> (WARNING: deletes ALL secure storage)

## Pick
- `image({double? maxWidth, double? maxHeight, int? imageQuality})` → Future<MagicFile?>
- `images({...})` → Future<List<MagicFile>>
- `camera({CameraDevice? preferredCamera, bool fallbackToGallery, ...})` → Future<MagicFile?>
- `video({Duration? maxDuration})` → Future<MagicFile?>
- `file({List<String>? extensions, bool withData})` → Future<MagicFile?>
- `files({List<String>? extensions, bool withData})` → Future<List<MagicFile>>
- `directory()` → Future<String?> (not Web)
- `saveFile({String? dialogTitle, String? fileName, Uint8List? bytes})` → Future<String?>
