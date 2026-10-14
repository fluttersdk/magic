---
paths: "lib/src/broadcasting/**/*.dart"
---

# Broadcasting Domain

- `Echo` facade proxies to `BroadcastManager` bound at `'broadcasting'` in the IoC container
- `BroadcastServiceProvider` is **NOT** auto-registered — add explicitly to `providers` list, same as `EncryptionServiceProvider`
- Bootstrap: `BroadcastServiceProvider.register()` binds `BroadcastManager` singleton; `boot()` auto-connects unless default is `'null'`

## Echo Facade API

- `Echo.channel(name)` — public channel (no auth)
- `Echo.private(name)` — private channel (driver adds `private-` prefix, performs HTTP auth)
- `Echo.join(name)` — presence channel (driver adds `presence-` prefix, auth + member tracking)
- `Echo.listen(channel, event, callback)` — shorthand for `channel().listen()`
- `Echo.leave(name)` — unsubscribe from channel
- `Echo.connect()` / `Echo.disconnect()` — connection lifecycle
- `Echo.socketId` — server-assigned ID; `null` when disconnected
- `Echo.connectionState` — `Stream<BroadcastConnectionState>` (connecting/connected/disconnected/reconnecting)
- `Echo.onReconnect` — `Stream<void>` emits once per reconnect handshake, after every channel was sent its subscribe (never on the first connection). It does NOT mean the channels are confirmed; refetch on `channel.onSubscriptionChanged` turning `true` instead
- `Echo.addInterceptor(interceptor)` — attach interceptor to default connection
- `Echo.manager` — direct `BroadcastManager` access (for `extend()`)
- `Echo.fake()` / `Echo.unfake()` — test double swap

## BroadcastChannel Contract

- `channel.listen(event, callback)` — returns `this` (chainable)
- `channel.stopListening(event)` — remove named listener
- `channel.events` — raw `Stream<BroadcastEvent>` for all events
- `channel.name` — fully-qualified name as sent to server
- `channel.isSubscribed` — the server confirmed the channel on this socket (`subscription_succeeded`); `false` after a drop, a leave, or a failed auth. `connected` does NOT imply it
- `channel.onSubscriptionChanged` — `Stream<bool>` emitting `isSubscribed` on each change; never replays

Both members are abstract: every driver's channel and every hand-written test double implements them.

## BroadcastPresenceChannel Contract

Extends `BroadcastChannel` with:
- `channel.members` — `List<Map<String, dynamic>>` (immutable snapshot)
- `channel.onJoin` — `Stream<Map<String, dynamic>>` member join events
- `channel.onLeave` — `Stream<Map<String, dynamic>>` member leave events

## BroadcastManager

- `BroadcastManager.extend(name, factory)` — register custom driver; `factory` receives `Map<String, dynamic>` config
- `BroadcastManager.resetDrivers()` — clear custom drivers (testing only)
- `manager.connection([name])` — resolve named or default driver; default is cached after first resolution
- Config key: `broadcasting.default` for default connection name, `broadcasting.connections.{name}` for per-connection config

## BroadcastDriver Contract

Abstract interface all drivers must implement: `connect()`, `disconnect()`, `socketId`, `isConnected`, `connectionState`, `onReconnect`, `channel(name)`, `private(name)`, `join(name)`, `leave(name)`, `addInterceptor(interceptor)`.

## BroadcastInterceptor Contract

All hooks have pass-through defaults — override only what you need:
- `onSend(Map<String, dynamic> message) => message` — called before outbound message; return empty map to suppress
- `onReceive(BroadcastEvent event) => event` — called on inbound event; return modified event
- `onError(dynamic error) => error` — called on driver error; return replacement to recover

Register via `Echo.addInterceptor()` or `driver.addInterceptor()` in a ServiceProvider `boot()`.

## ReverbBroadcastDriver

- Implements Pusher-compatible WebSocket protocol (Laravel Reverb, Soketi, etc.)
- Constructor DI: `channelFactory` overrides WebSocket creation, `authFactory` overrides HTTP auth call — both for testing
- Auto-reconnection: exponential backoff with 30% random jitter — `base = 500ms × 2^attempt` (capped at `max_reconnect_delay`), then `delay = base + random(0..base×0.3)`. Jitter prevents thundering herd on server restart. Set `reconnect: false` to disable
- Activity monitor: client-side inactivity detection using Pusher protocol `activity_timeout` (from server handshake). After `activity_timeout` seconds of silence → sends `pusher:ping`. If no `pusher:pong` within 30s (`pongTimeout`) → drops the connection as a code-less close (state `reconnecting`, channels unsubscribed, backoff retry) without awaiting the dead socket's close. Timer resets on ANY inbound message
- Connection timeout: configurable via `connection_timeout` (default 15s). If server doesn't complete Pusher handshake within timeout → drops the socket, schedules reconnect, throws `TimeoutException`
- Constructor DI: `pongTimeout` (Duration, default 30s) and `random` (Random) — both for testing determinism
- Socket generation: every socket gets a `_generation`; a late close, an auth answer, or an auth retry from an older socket is dropped (`_isCurrent`). Old sockets are never awaited on close
- Resubscription: EVERY handshake (first connect, timer retry, explicit `connect()` after a drop) subscribes every registered channel with the new socket id, as pusher-js does. There is no subscription queue. Private/presence re-authenticate. `onReconnect` emits after the replay ran (each channel sent its subscribe, or its first auth attempt failed), never for the first connection
- Single flight: one socket attempt at a time (`_inFlight`). A reconnect timer that fires while an attempt is in flight waits for it and retries if it ended with no socket and armed no retry of its own (a drop during a timer reconnect's replay)
- Auth error handling: the default auth factory throws `BroadcastAuthException` (`statusCode`, `channelName`, `isRetryable`) on a non-2xx answer. Status `0` and 5xx retry with `backoffDelay` while the socket lasts, logged via `Log.warning()`; 401, 403 and others are logged via `Log.error()` and not retried. Every failure goes through the interceptor `onError()` chain; one channel's failure doesn't block others
- Close codes decide the reconnect: 4000–4099 = fatal (no reconnect, state `disconnected`), 4100–4199 = backoff, 4200–4299 = immediate, any other code or none (a Reverb restart sends no close frame) = backoff. A socket lost before its handshake with no retry also reports `disconnected`
- A `pusher:error` frame on an open socket never reconnects; it only reaches interceptors (Reverb sends 4200 for any server exception without closing)
- Heartbeat: responds to `pusher:ping` with `pusher:pong` automatically
- Private/presence auth: HTTP POST to `auth_endpoint` with `{socket_id, channel_name}` — expects `{auth: '...'}` response

## NullBroadcastDriver

- Silently no-ops all operations — used for local dev or when `broadcasting.default` is `'null'`
- `BroadcastServiceProvider.boot()` skips `connect()` when default connection is `'null'`

## FakeBroadcastManager (Testing)

- `Echo.fake()` — binds `FakeBroadcastManager` in container; returns the fake for assertions
- `Echo.unfake()` — removes fake binding (or use `MagicApp.reset()` + `Magic.flush()` in `setUp()`)
- Assertions: `assertConnected()`, `assertDisconnected()`, `assertSubscribed(channel)`, `assertNotSubscribed(channel)`, `assertListening(channel, event)`, `assertNotListening(channel, event)`, `assertInterceptorAdded()` — all throw `AssertionError` with descriptive messages
- `fake.dispatch(channel, event, data)` — run the registered handler with a decoded payload, as the driver would on an incoming frame. Throws if nothing is listening, because dispatching into silence is the failure it exists to reveal
- `fake.reset()` — clear all recorded state; confirmed channels emit `false` first
- `fake.driver` — access underlying `FakeBroadcastDriver` for low-level inspection (`.subscribedChannels`, `.addedInterceptors`, `.isConnected`, `.listeners`)
- `fake.driver.setSubscribed(name, value)` — stands in for the server's confirmation (`true`) or a drop (`false`) on the fully-qualified name; every fake channel starts unconfirmed

**Subscribing and listening are separate, and only `assertListening` covers the second.** `assertSubscribed` passes for an app that holds a live channel and registers no handler at all, so a deleted `listen()` line is invisible to it. Reach for `assertListening` on the line your realtime feature depends on, and `dispatch()` when you need to prove a handler actually runs rather than merely exists.

A second `listen()` for one event REPLACES the first, matching `ReverbBroadcastDriver`, which cancels the previous subscription before storing the new one.

## Config

```dart
// config/broadcasting.dart
final broadcastingConfig = {
  'broadcasting': {
    'default': Env.get('BROADCAST_CONNECTION', 'null'),
    'connections': {
      'reverb': {
        'driver': 'reverb',
        'host': Env.get('REVERB_HOST', 'localhost'),
        'port': int.parse(Env.get('REVERB_PORT', '8080')!),
        'scheme': Env.get('REVERB_SCHEME', 'ws'),
        'app_key': Env.get('REVERB_APP_KEY', ''),
        'auth_endpoint': '/broadcasting/auth',
        'reconnect': true,
        'max_reconnect_delay': 30000,
        'activity_timeout': 120,
        'connection_timeout': 15,
      },
      'null': {'driver': 'null'},
    },
  },
};
```

Use `configFactories` (not `configs`) when config values depend on `Env.get()`.
