# Events

- [Introduction](#introduction)
- [Configuration](#configuration)
- [Defining Events](#defining-events)
- [Defining Listeners](#defining-listeners)
- [Registering Events & Listeners](#registering-events--listeners)
- [Dispatching Events](#dispatching-events)
- [Inline Listeners](#inline-listeners)
- [Framework Events](#framework-events)

<a name="introduction"></a>
## Introduction

Magic provides a simple observer implementation, allowing you to subscribe and listen for various events that occur in your application. Events serve as a great way to decouple various aspects of your application, since a single event can have multiple listeners that do not depend on each other.

```dart
// Dispatch an event when an order ships
await Event.dispatch(OrderShipped(order));

// Listeners react to the event (send email, update analytics, etc.)
```

<a name="configuration"></a>
## Configuration

### Enabling Event Support

Add `EventServiceProvider` to your providers in `config/app.dart`:

```dart
'providers': [
  (app) => EventServiceProvider(app),
  (app) => AppEventServiceProvider(app),  // Your custom events
  // ... other providers
],
```

Create the event directories:

```
lib/app/
├── events/
│   └── order_shipped.dart
└── listeners/
    └── send_shipment_notification.dart
```

<a name="defining-events"></a>
## Defining Events

An event class is a simple data container holding information related to the event:

```dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';
import '../models/order.dart';

class OrderShipped extends MagicEvent {
  final Order order;
  final String trackingNumber;

  OrderShipped(this.order, {required this.trackingNumber});
}
```

Events are simple data classes—they don't contain any logic. The listener is responsible for processing the event.

<a name="defining-listeners"></a>
## Defining Listeners

Event listeners receive the event instance in their `handle` method:

```dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';
import '../events/order_shipped.dart';

class SendShipmentNotification extends MagicListener<OrderShipped> {
  @override
  Future<void> handle(OrderShipped event) async {
    // Send push notification
    await NotificationService.send(
      to: event.order.user,
      title: 'Order Shipped!',
      body: 'Your order #${event.order.id} is on its way.',
    );
  }
}

class UpdateAnalytics extends MagicListener<OrderShipped> {
  @override
  Future<void> handle(OrderShipped event) async {
    await Analytics.track('order_shipped', {
      'order_id': event.order.id,
      'value': event.order.total,
    });
  }
}
```

<a name="registering-events--listeners"></a>
## Registering Events & Listeners

Register mappings in your `AppEventServiceProvider`:

```dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';
import '../events/order_shipped.dart';
import '../events/user_registered.dart';
import '../listeners/send_shipment_notification.dart';
import '../listeners/update_analytics.dart';
import '../listeners/send_welcome_email.dart';

class AppEventServiceProvider extends EventServiceProvider {
  AppEventServiceProvider(super.app);

  @override
  Map<Type, List<MagicListener Function()>> get listen => {
    // An event can have multiple listeners
    OrderShipped: [
      () => SendShipmentNotification(),
      () => UpdateAnalytics(),
    ],
    UserRegistered: [
      () => SendWelcomeEmail(),
    ],
  };
}
```

<a name="dispatching-events"></a>
## Dispatching Events

Use the `Event` facade to dispatch events:

```dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';
import '../events/order_shipped.dart';

class OrderController extends MagicController {
  Future<void> shipOrder(Order order) async {
    // Update order status
    order.status = 'shipped';
    await order.save();
    
    // Dispatch event - listeners handle the rest
    await Event.dispatch(OrderShipped(
      order,
      trackingNumber: generateTrackingNumber(),
    ));
    
    Magic.success('Shipped', 'Order has been shipped!');
  }
}
```



<a name="framework-events"></a>
## Framework Events

Magic fires several system events automatically.

### Authentication Events

| Event | Fired When |
|-------|------------|
| `AuthLogin` | User successfully logs in |
| `AuthLogout` | User logs out |
| `AuthFailed` | Authentication attempt fails |

```dart
Event.listen<AuthLogin>((event) {
  Log.info('User logged in: ${event.user.email}');
});
```

### Model Lifecycle Events

| Event | Fired When |
|-------|------------|
| `ModelSaving` | Before model is saved |
| `ModelSaved` | After model is saved |
| `ModelCreating` | Before new model is created |
| `ModelCreated` | After new model is created |
| `ModelUpdating` | Before existing model is updated |
| `ModelUpdated` | After existing model is updated |
| `ModelDeleted` | After model is deleted |

```dart
Event.listen<ModelCreated>((event) {
  if (event.model is User) {
    final user = event.model as User;
    Log.info('New user registered: ${user.email}');
  }
});
```

### Gate Events

| Event | Fired When |
|-------|------------|
| `GateAbilityDefined` | Ability registered with `Gate.define()` |
| `GateAccessChecked` | After any ability check |
| `GateAccessDenied` | When access is denied |

```dart
// Log denied access attempts
Event.listen<GateAccessDenied>((event) {
  Log.warning('Access denied: ${event.ability} for user ${event.user?.id}');
});
```

### Database Events

| Event | Fired When |
|-------|------------|
| `DatabaseConnected` | Database connection established |
| `QueryExecuted` | After query execution (if enabled) |

> [!TIP]
> Use events to decouple your application logic. Instead of calling multiple services directly, dispatch an event and let listeners handle it independently.
