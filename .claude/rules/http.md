---
path: "lib/src/http/**/*.dart"
---

# HTTP Domain (Controllers & Middleware)

- `MagicController extends ChangeNotifier` — lifecycle: `onInit()` → use → `onClose()` → `dispose()`
- `@mustCallSuper` on both `onInit()` and `onClose()` — always call `super.onInit()` / `super.onClose()`
- `MagicStateMixin<T>` on MagicController: reactive state via `rxState` (T?), `rxStatus` (RxStatus)
- State helpers: `setLoading()`, `setSuccess(T data)`, `setError(String msg)`, `setEmpty()`
- Status checks: `isLoading`, `isSuccess`, `isError`, `isEmpty` — boolean getters
- `renderState(onSuccess, {onLoading, onError, onEmpty})` — declarative UI builder using AnimatedBuilder
- `setState(T?, {RxStatus? status, bool notify = true})` — low-level; use helpers above
- `refreshUI()` calls `notifyListeners()` with disposed guard — use this, not `notifyListeners()` directly
- `SimpleMagicController` — auto-calls `onInit()` in constructor. No state mixin
- `RxStatus` is const: `.loading()`, `.success()`, `.error(message)`, `.empty()`. Has `.type` (enum) and `.message`
- `MagicMiddleware`: abstract with `Future<void> handle(void Function() next)`. Call `next()` to proceed, skip to redirect
- `Kernel.register('name', () => MiddlewareInstance())` — factory registration, not instances
- Middleware chain: registered names referenced in route `.middleware(['auth', 'admin'])` — resolved at navigation time
- `Http` facade (network, not this module): RESTful methods + `MagicResponse` envelope. Different from controller layer
