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
- `Echo.onReconnect` — `Stream<void>` emits once per successful reconnect
- `Echo.addInterceptor(interceptor)` — attach interceptor to default connection
- `Echo.manager` — direct `BroadcastManager` access (for `extend()`)
- `Echo.fake()` / `Echo.unfake()` — test double swap

## BroadcastChannel Contract

- `channel.listen(event, callback)` — returns `this` (chainable)
- `channel.stopListening(event)` — remove named listener
- `channel.events` — raw `Stream<BroadcastEvent>` for all events
- `channel.name` — fully-qualified name as sent to server

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
- Activity monitor: client-side inactivity detection using Pusher protocol `activity_timeout` (from server handshake). After `activity_timeout` seconds of silence → sends `pusher:ping`. If no `pusher:pong` within 30s (`pongTimeout`) → closes socket, triggers reconnect. Timer resets on ANY inbound message
- Connection timeout: configurable via `connection_timeout` (default 15s). If server doesn't complete Pusher handshake within timeout → closes socket, schedules reconnect, throws `TimeoutException`
- Constructor DI: `pongTimeout` (Duration, default 30s) and `random` (Random) — both for testing determinism
- Reconnect resubscription: all channels re-subscribed with `await` after reconnect. Private/presence re-authenticate. `onReconnect` emits only after all resubscriptions complete
- Auth error handling: failures logged via `Log.error()` with channel name, routed through interceptor `onError()` chain. Per-channel try/catch — one failure doesn't block others
- Pusher error codes: 4000–4099 = fatal (no reconnect), 4100–4199 = immediate, 4200–4299 = backoff
- Deduplication: ring buffer of size `dedup_buffer_size` (default 100) fingerprints — suppresses duplicate events on reconnect
- Heartbeat: responds to `pusher:ping` with `pusher:pong` automatically
- Private/presence auth: HTTP POST to `auth_endpoint` with `{socket_id, channel_name}` — expects `{auth: '...'}` response

## NullBroadcastDriver

- Silently no-ops all operations — used for local dev or when `broadcasting.default` is `'null'`
- `BroadcastServiceProvider.boot()` skips `connect()` when default connection is `'null'`

## FakeBroadcastManager (Testing)

- `Echo.fake()` — binds `FakeBroadcastManager` in container; returns the fake for assertions
- `Echo.unfake()` — removes fake binding (or use `MagicApp.reset()` + `Magic.flush()` in `setUp()`)
- Assertions: `assertConnected()`, `assertDisconnected()`, `assertSubscribed(channel)`, `assertNotSubscribed(channel)`, `assertInterceptorAdded()` — all throw `AssertionError` with descriptive messages
- `fake.reset()` — clear all recorded state
- `fake.driver` — access underlying `FakeBroadcastDriver` for low-level inspection (`.subscribedChannels`, `.addedInterceptors`, `.isConnected`)

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
        'dedup_buffer_size': 100,
      },
      'null': {'driver': 'null'},
    },
  },
};
```

Use `configFactories` (not `configs`) when config values depend on `Env.get()`.
