# Events

## Introduction

Magic provides a simple observer implementation, allowing you to subscribe and listen for various events that occur in your application. Event classes are stored in `lib/app/events`, while listeners are stored in `lib/app/listeners`.

## Enabling Event Support

By default, the event service provider is **not enabled**. You can enable it using the Magic CLI:

```bash
magic init:event
```

This command will:
- Create `lib/app/providers/event_service_provider.dart`
- Add `EventServiceProvider` to your providers
- Create the `events/` and `listeners/` directories

### Manual Setup

Alternatively, add the provider manually to your `config/app.dart`:

```dart
'providers': [
  (app) => AppEventServiceProvider(app),
],
```

## Defining Events

An event class is a data container holding information related to the event:

```dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

class OrderShipped extends MagicEvent {
  final Order order;

  OrderShipped(this.order);
}
```

## Defining Listeners

Event listeners receive the event instance in their `handle` method:

```dart
class SendShipmentNotification extends MagicListener<OrderShipped> {
  @override
  Future<void> handle(OrderShipped event) async {
    print('Order shipped: ${event.order.id}');
  }
}
```

## Registering Events & Listeners

Register mappings in `AppEventServiceProvider`:

```dart
class AppEventServiceProvider extends EventServiceProvider {
  AppEventServiceProvider(super.app);

  @override
  Map<Type, List<MagicListener Function()>> get listen => {
    OrderShipped: [
      () => SendShipmentNotification(),
    ],
  };
}
```

## Dispatching Events

```dart
await Event.dispatch(OrderShipped(order));
```

## Framework Events

Magic fires several system events automatically.

### Authentication Events

| Event | Description |
|-------|-------------|
| `AuthLogin` | User successfully logs in |
| `AuthLogout` | User logs out |
| `AuthFailed` | Authentication attempt fails |

### Database Events

| Event | Description |
|-------|-------------|
| `DatabaseConnected` | Database connection established |
| `QueryExecuted` | Query execution (if enabled) |

### Model Lifecycle Events

| Event | Description |
|-------|-------------|
| `ModelSaving` | Before model is saved |
| `ModelSaved` | After model is saved |
| `ModelCreating` | Before new model is created |
| `ModelCreated` | After new model is created |
| `ModelUpdating` | Before existing model is updated |
| `ModelUpdated` | After existing model is updated |
| `ModelDeleted` | After model is deleted |

### Gate Events

| Event | Description |
|-------|-------------|
| `GateAbilityDefined` | Ability registered with `Gate.define()` |
| `GateAccessChecked` | After any ability check |
| `GateAccessDenied` | When access is denied |

### Example: Listening for New Users

```dart
class LogNewUser extends MagicListener<ModelCreated> {
  @override
  Future<void> handle(ModelCreated event) async {
    if (event.model is User) {
       print('New user joined: ${(event.model as User).name}');
    }
  }
}
```
