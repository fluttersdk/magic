# HTTP & NETWORK LAYER

MagicController (reactive state) + middleware pipeline (Kernel) + Dio-backed HTTP client (MagicResponse).

## STRUCTURE

```
http/
├── kernel.dart              # Middleware registry + execution
├── magic_controller.dart    # Base controller + MagicStateMixin
└── middleware/              # Middleware implementations

network/
├── contracts/network_driver.dart      # Driver interface
├── drivers/dio_network_driver.dart
├── magic_response.dart                # Response wrapper
└── network_manager.dart
```
## MAGIC CONTROLLER

`MagicController extends ChangeNotifier`. Lifecycle: `onInit()` (async, fetch data), `onClose()` (dispose).

**MagicStateMixin** — mixed into `MagicController`:
```dart
ValueNotifier<RxStatus> rxStatus   // loading | success | error | empty
void setLoading()
void setSuccess(dynamic data)
void setError(String msg)
void setEmpty()
```

**renderState()** — dispatches `onLoading` / `onSuccess(data)` / `onError(msg)` / `onEmpty` based on `rxStatus`.

**ValidatesRequests mixin** (in `concerns/validates_requests.dart`, NOT `http/`):
```dart
Map<String, String> validationErrors           // field → first error message
void setErrorFromResponse(MagicResponse res)   // parses Laravel 422
void clearValidationErrors()
```

## MIDDLEWARE PIPELINE

```dart
void handle(void Function() next);   // must call next() to proceed; omit to halt
```

**Kernel**:
```dart
Kernel.global([() => AuthMiddleware()]);                // runs on every request
Kernel.register('auth', () => AuthMiddleware());         // named middleware
final passed = await Kernel.execute([AuthMiddleware()]); // false if chain halted
```

Route-level: `.middleware(['auth'])` on `RouteDefinition`. Kernel resolves named strings to factories. Skipping `next()` halts the chain.

## NETWORK DRIVER

Default: `DioNetworkDriver`. Base URL + headers from `config/auth.dart`.

```dart
Http.get('/resource', query: {'page': 1})   // index / show
Http.post('/resource', data: body)           // store
Http.put('/resource/$id', data: body)        // update (full)
Http.patch('/resource/$id', data: body)      // update (partial)
Http.delete('/resource/$id')                 // destroy
Http.withToken(token).get('/secure')         // fluent token override — new instance
```
## MAGIC RESPONSE

```dart
res.successful   // statusCode 200-299
res.failed       // statusCode >= 400
res.data         // Map<String, dynamic> — raw body
res['key']       // shorthand for res.data['key']
res.errors       // Map<String, List<String>> — from {"errors": {...}}
res.firstError   // String? — first message across all fields
res.statusCode   // int
```

Laravel 422: `res.errors` reads `response.data['errors']`. Use `res.firstError ?? 'Unknown error'` in `setError()`.  
Laravel data wrapper: `res.data['data'] as List` — unwrap manually.

## FILE UPLOADS

```dart
final file = await MultipartFile.fromFile(xfile.path, filename: xfile.name);
await Http.post('/upload', data: FormData.fromMap({'file': file}));
```

`MagicFile` carries `path`, `name`, `mimeType`. Always set `filename` — some APIs reject without it.

## GOTCHAS

1. `onInit()` is async — first `build()` fires before it completes; render `loading` state by default.
2. `setSuccess()` calls `notifyListeners()` — never call from constructor or `build()`.
3. Middleware MUST call `next()` or the route never renders.
4. `Kernel.global()` replaces the list — call once inside a ServiceProvider `boot()`.
5. `res.data` is `null` on network errors (timeout, no connection) — guard before access.
6. `withToken()` returns a new driver instance; does not mutate the singleton.
7. `setErrorFromResponse()` only populates on HTTP 422 — check `res.failed` separately for 500s.
8. `ValidatesRequests` mixin lives in `concerns/`, not `http/` — import from `concerns/validates_requests.dart`.
