# Broadcasting

- [Introduction](#introduction)
- [Configuration](#configuration)
    - [Connection Options](#connection-options)
    - [Environment Variables](#environment-variables)
- [Echo Facade](#echo-facade)
    - [API Reference](#api-reference)
- [Channels](#channels)
    - [Public Channels](#public-channels)
    - [Private Channels](#private-channels)
    - [Presence Channels](#presence-channels)
- [Interceptors](#interceptors)
    - [Creating a Custom Interceptor](#creating-a-custom-interceptor)
    - [Registering Interceptors](#registering-interceptors)
- [Custom Drivers](#custom-drivers)
    - [Implementing a Custom Driver](#implementing-a-custom-driver)
    - [Registering the Custom Driver](#registering-the-custom-driver)
- [Testing](#testing)
    - [Using FakeBroadcastManager](#using-fakebroadcastmanager)
    - [Assertion Helpers](#assertion-helpers)
- [Connection](#connection)
    - [Connection Lifecycle](#connection-lifecycle)
    - [Reconnection and Heartbeat](#reconnection-and-heartbeat)
    - [Deduplication](#deduplication)

<a name="introduction"></a>
## Introduction

Magic provides a Laravel Echo-equivalent broadcasting system that lets your Flutter app receive real-time events over WebSocket connections. The `Echo` facade mirrors the Laravel Echo JavaScript client API — if you know how to use Laravel Echo, you already know how to use this.

The broadcasting system is:
- **Pusher-compatible**: Works with Laravel Reverb, Soketi, and any Pusher-protocol server out of the box.
- **Resilient**: Automatic reconnection with exponential backoff, application-level heartbeat, and event deduplication.
- **Extensible**: Register custom drivers via `BroadcastManager.extend()`.
- **Testable**: `Echo.fake()` swaps the real driver for an in-memory fake with assertion helpers.

The `BroadcastServiceProvider` is **not** auto-registered. You must add it explicitly to your providers list.

<a name="configuration"></a>
## Configuration

Copy `defaultBroadcastingConfig` into your application config and register `BroadcastServiceProvider`:

```dart
// lib/config/broadcasting.dart
import 'package:magic/magic.dart';

final Map<String, dynamic> broadcastingConfig = {
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
        'dedup_buffer_size': 100,
      },
      'null': {'driver': 'null'},
    },
  },
};
```

Register the provider in `Magic.init()`:

```dart
await Magic.init(
  configFactories: [
    () => appConfig,
    () => broadcastingConfig,
  ],
  configs: [
    {
      'app': {
        'providers': [
          (app) => BroadcastServiceProvider(app),
        ],
      },
    },
  ],
);
```

<a name="connection-options"></a>
### Connection Options

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `driver` | `String` | — | Driver name (`reverb`, `null`, or custom) |
| `host` | `String` | `'localhost'` | WebSocket server hostname |
| `port` | `int` | `8080` | WebSocket server port |
| `scheme` | `String` | `'ws'` | Connection scheme (`ws` or `wss`) |
| `app_key` | `String` | `''` | Reverb/Pusher application key |
| `auth_endpoint` | `String` | `'/broadcasting/auth'` | HTTP endpoint for private/presence channel auth |
| `reconnect` | `bool` | `true` | Whether to auto-reconnect on unexpected disconnect |
| `max_reconnect_delay` | `int` | `30000` | Maximum backoff delay in milliseconds |
| `activity_timeout` | `int` | `120` | Seconds before a heartbeat ping is expected |
| `dedup_buffer_size` | `int` | `100` | Number of recent event fingerprints kept for deduplication |

<a name="environment-variables"></a>
### Environment Variables

```dotenv
BROADCAST_CONNECTION=reverb
REVERB_HOST=localhost
REVERB_PORT=8080
REVERB_SCHEME=ws
REVERB_APP_KEY=your-app-key
```

<a name="echo-facade"></a>
## Echo Facade

The `Echo` facade provides static access to the broadcasting system, proxying all calls to the bound `BroadcastManager`.

<a name="api-reference"></a>
### API Reference

| Method / Property | Returns | Description |
|:------------------|:--------|:------------|
| `Echo.channel(name)` | `BroadcastChannel` | Subscribe to a public channel |
| `Echo.private(name)` | `BroadcastChannel` | Subscribe to a private channel (auth required) |
| `Echo.join(name)` | `BroadcastPresenceChannel` | Join a presence channel (auth + member tracking) |
| `Echo.listen(channel, event, callback)` | `BroadcastChannel` | Shorthand: subscribe + listen in one call |
| `Echo.leave(name)` | `void` | Unsubscribe from a channel |
| `Echo.connect()` | `Future<void>` | Establish the WebSocket connection |
| `Echo.disconnect()` | `Future<void>` | Close the connection and release resources |
| `Echo.connection` | `BroadcastDriver` | The resolved default driver instance |
| `Echo.socketId` | `String?` | Server-assigned socket identifier, or `null` when disconnected |
| `Echo.connectionState` | `Stream<BroadcastConnectionState>` | Stream of connection lifecycle state changes |
| `Echo.onReconnect` | `Stream<void>` | Emits once each time the driver successfully reconnects |
| `Echo.addInterceptor(interceptor)` | `void` | Register an interceptor on the default connection |
| `Echo.manager` | `BroadcastManager` | The underlying manager (for `extend()` and advanced use) |
| `Echo.fake()` | `FakeBroadcastManager` | Swap to in-memory fake for testing |
| `Echo.unfake()` | `void` | Restore the real manager binding |

<a name="channels"></a>
## Channels

<a name="public-channels"></a>
### Public Channels

Public channels require no authentication. Any connected client may subscribe.

```dart
// Subscribe and listen for a specific event
Echo.channel('orders').listen('OrderShipped', (event) {
  final orderId = event.data['id'];
  print('Order $orderId has shipped!');
});

// Fluent chaining for multiple events on the same channel
Echo.channel('orders')
  .listen('OrderShipped', onShipped)
  .listen('OrderCancelled', onCancelled);

// Stop listening to a specific event
Echo.channel('orders').stopListening('OrderShipped');

// Leave the channel entirely
Echo.leave('orders');
```

The `BroadcastEvent` envelope provides full context for each received message:

| Property | Type | Description |
|:---------|:-----|:------------|
| `event` | `String` | Event name (e.g. `'App\\Events\\OrderShipped'`) |
| `channel` | `String` | Channel name the event arrived on |
| `data` | `Map<String, dynamic>` | Decoded JSON payload |
| `receivedAt` | `DateTime` | Local timestamp of receipt |

<a name="private-channels"></a>
### Private Channels

Private channels perform an HTTP auth handshake at `auth_endpoint` before subscribing. The driver sends the `socket_id` and `channel_name` to your server, which validates the request and returns an auth token.

```dart
// Subscribe to a private channel (driver adds 'private-' prefix automatically)
Echo.private('user.${Auth.user<User>()!.id}')
  .listen('ProfileUpdated', (event) {
    print('Profile updated: ${event.data}');
  });

// Convenience shorthand
Echo.listen('user.1', 'ProfileUpdated', (event) {
  print(event.data);
});
```

On the Laravel server side, the channel authorization lives in `routes/channels.php`:

```php
Broadcast::channel('user.{id}', function ($user, $id) {
    return (int) $user->id === (int) $id;
});
```

<a name="presence-channels"></a>
### Presence Channels

Presence channels extend private channels with real-time member tracking. The server returns member data on subscription success, and the driver emits `onJoin`/`onLeave` streams as membership changes.

```dart
final channel = Echo.join('room.1');

// Members currently in the channel
print('Online: ${channel.members.length}');

// React to member join/leave
channel.onJoin.listen((member) {
  print('${member['name']} joined the room');
});

channel.onLeave.listen((member) {
  print('${member['name']} left the room');
});

// Presence channels also support event listening
channel.listen('MessagePosted', (event) {
  print('New message: ${event.data['body']}');
});
```

`BroadcastPresenceChannel` API:

| Property | Type | Description |
|:---------|:-----|:------------|
| `members` | `List<Map<String, dynamic>>` | Current member list (immutable snapshot) |
| `onJoin` | `Stream<Map<String, dynamic>>` | Emits member payload on each new join |
| `onLeave` | `Stream<Map<String, dynamic>>` | Emits member payload on each leave |

<a name="interceptors"></a>
## Interceptors

`BroadcastInterceptor` hooks into the driver message pipeline — identical in spirit to `MagicNetworkInterceptor` in the HTTP layer. All three hook methods have pass-through default implementations; subclass only what you need.

| Method | Parameters | Returns | Description |
|:-------|:-----------|:--------|:------------|
| `onSend(message)` | `Map<String, dynamic>` | `Map<String, dynamic>` | Called before an outbound message is sent. Return modified map or empty map to suppress. |
| `onReceive(event)` | `BroadcastEvent` | `BroadcastEvent` | Called when an event arrives from the server. Return modified event to pass downstream. |
| `onError(error)` | `dynamic` | `dynamic` | Called when the driver encounters an error. Return original to propagate or a replacement to recover. |

<a name="creating-a-custom-interceptor"></a>
### Creating a Custom Interceptor

```dart
// lib/app/broadcasting/logging_broadcast_interceptor.dart
import 'package:magic/magic.dart';

class LoggingBroadcastInterceptor extends BroadcastInterceptor {
  @override
  BroadcastEvent onReceive(BroadcastEvent event) {
    Log.debug('Broadcast received', {
      'event': event.event,
      'channel': event.channel,
      'data': event.data,
    });
    return event;
  }

  @override
  dynamic onError(dynamic error) {
    Log.error('Broadcast error', {'error': error.toString()});
    return error;
  }
}
```

<a name="registering-interceptors"></a>
### Registering Interceptors

Register interceptors in a Service Provider's `boot()` phase, after the connection is established:

```dart
class BroadcastingServiceProvider extends ServiceProvider {
  BroadcastingServiceProvider(super.app);

  @override
  Future<void> boot() async {
    Echo.addInterceptor(LoggingBroadcastInterceptor());
  }
}
```

<a name="custom-drivers"></a>
## Custom Drivers

<a name="implementing-a-custom-driver"></a>
### Implementing a Custom Driver

Implement the `BroadcastDriver` abstract class:

```dart
// lib/app/broadcasting/pusher_broadcast_driver.dart
import 'package:magic/magic.dart';

class PusherBroadcastDriver implements BroadcastDriver {
  PusherBroadcastDriver(this._config);

  final Map<String, dynamic> _config;

  @override
  Future<void> connect() async {
    // Establish connection to Pusher.
  }

  @override
  Future<void> disconnect() async {
    // Close the connection.
  }

  @override
  String? get socketId => /* ... */;

  @override
  bool get isConnected => /* ... */;

  @override
  Stream<BroadcastConnectionState> get connectionState => /* ... */;

  @override
  Stream<void> get onReconnect => /* ... */;

  @override
  BroadcastChannel channel(String name) => /* ... */;

  @override
  BroadcastChannel private(String name) => /* ... */;

  @override
  BroadcastPresenceChannel join(String name) => /* ... */;

  @override
  void leave(String name) { /* ... */ }

  @override
  void addInterceptor(BroadcastInterceptor interceptor) { /* ... */ }
}
```

<a name="registering-the-custom-driver"></a>
### Registering the Custom Driver

Register your driver via `BroadcastManager.extend()` in a Service Provider's `boot()` phase:

```dart
class AppServiceProvider extends ServiceProvider {
  AppServiceProvider(super.app);

  @override
  Future<void> boot() async {
    BroadcastManager.extend('pusher', (config) => PusherBroadcastDriver(config));
  }
}
```

Then reference the driver name in config:

```dart
'connections': {
  'pusher': {
    'driver': 'pusher',
    'app_key': Env.get('PUSHER_APP_KEY'),
    'cluster': Env.get('PUSHER_CLUSTER', 'mt1'),
  },
},
```

This follows the same `extend()` pattern used by `Auth.manager.extend(...)` for custom auth guards and `LogManager.extend(...)` for custom log drivers.

<a name="testing"></a>
## Testing

<a name="using-fakebroadcastmanager"></a>
### Using FakeBroadcastManager

`Echo.fake()` swaps the real `BroadcastManager` binding with an in-memory `FakeBroadcastManager`. All channel operations are recorded but no WebSocket connection is opened.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

void main() {
  MagicTest.init();

  test('subscribes to orders channel on init', () async {
    final fake = Echo.fake();

    // Exercise code under test
    final controller = OrderController();
    await controller.onInit();

    // Assert
    fake.assertSubscribed('orders');
    fake.assertConnected();
  });
}
```

Always call `Echo.unfake()` in tearDown — or use `MagicTest.init()` which resets the container automatically.

<a name="assertion-helpers"></a>
### Assertion Helpers

`FakeBroadcastManager` exposes assertion methods that throw `AssertionError` with descriptive messages on failure:

| Method | Description |
|:-------|:------------|
| `assertConnected()` | Assert the fake driver is in a connected state |
| `assertDisconnected()` | Assert the fake driver is disconnected |
| `assertSubscribed(channel)` | Assert a channel name is in the subscribed list |
| `assertNotSubscribed(channel)` | Assert a channel name is NOT subscribed |
| `assertInterceptorAdded()` | Assert at least one interceptor has been registered |
| `reset()` | Clear all recorded state on the fake driver |

Access the underlying `FakeBroadcastDriver` via `fake.driver` for low-level inspection:

```dart
final fake = Echo.fake();

Echo.channel('orders');
Echo.private('user.1');

expect(fake.driver.subscribedChannels, contains('orders'));
expect(fake.driver.subscribedChannels, contains('private-user.1'));
expect(fake.driver.isConnected, isFalse);
```

Simulate received events by publishing directly to a channel in tests:

```dart
// Inject a fake event into the channel stream
final channel = Echo.channel('orders') as _FakeBroadcastChannel;
// ... or use fake.driver to inspect subscriptions and simulate state changes
```

<a name="connection"></a>
## Connection

<a name="connection-lifecycle"></a>
### Connection Lifecycle

`BroadcastConnectionState` tracks the lifecycle of the WebSocket connection:

| State | Description |
|:------|:------------|
| `connecting` | Establishing the connection |
| `connected` | Active, healthy connection |
| `disconnected` | Not connected, not attempting reconnect |
| `reconnecting` | Lost connection, attempting to re-establish |

Subscribe to `Echo.connectionState` to react to transitions in your UI:

```dart
Echo.connectionState.listen((state) {
  switch (state) {
    case BroadcastConnectionState.connected:
      showOnlineBadge();
    case BroadcastConnectionState.reconnecting:
      showReconnectingBanner();
    case BroadcastConnectionState.disconnected:
      showOfflineBanner();
    default:
      break;
  }
});
```

Re-subscribe to channels after a reconnect using `Echo.onReconnect`:

```dart
Echo.onReconnect.listen((_) {
  Echo.channel('orders').listen('OrderShipped', onShipped);
});
```

<a name="reconnection-and-heartbeat"></a>
### Reconnection and Heartbeat

`ReverbBroadcastDriver` implements automatic reconnection with **exponential backoff**:

- Formula: `min(500ms × 2^attempt, max_reconnect_delay)`
- Default `max_reconnect_delay` is 30,000 ms (30 seconds)
- Set `reconnect: false` in config to disable auto-reconnect

Pusher protocol error codes determine the reconnect strategy:

| Code Range | Action |
|:-----------|:-------|
| 4000–4099 | Fatal — do not reconnect |
| 4100–4199 | Reconnect immediately without backoff |
| 4200–4299 | Reconnect with exponential backoff |

The driver handles `pusher:ping` frames automatically, responding with `pusher:pong` to satisfy the server keepalive requirement.

<a name="deduplication"></a>
### Deduplication

The Reverb driver maintains a ring buffer of recently seen event fingerprints (channel + event name + raw data). Duplicate messages — which can arrive during reconnection — are silently dropped.

Configure the buffer size with `dedup_buffer_size` (default: `100`). A larger buffer consumes more memory but reduces false duplicate detection during high-throughput scenarios.
