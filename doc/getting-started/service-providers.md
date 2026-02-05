# Service Providers

- [Introduction](#introduction)
- [Writing Service Providers](#writing-service-providers)
    - [The Register Method](#the-register-method)
    - [The Boot Method](#the-boot-method)
- [Registering Providers](#registering-providers)
- [Deferred Providers](#deferred-providers)
- [Built-in Providers](#built-in-providers)

<a name="introduction"></a>
## Introduction

Service providers are the central place of all Magic application bootstrapping. Your own application, as well as all of Magic's core services, are bootstrapped via service providers.

But, what do we mean by "bootstrapped"? In general, we mean **registering** things, including registering service container bindings, event listeners, middleware, and even routes. Service providers are the central place to configure your application.

If you open the `config/app.dart` file included with Magic, you will see a `providers` array. These are all of the service provider classes that will be loaded for your application.

<a name="writing-service-providers"></a>
## Writing Service Providers

All service providers extend the `ServiceProvider` class. Most service providers contain a `register` and a `boot` method. Within the `register` method, you should **only bind things into the service container**. Within the `boot` method, you may do anything else—register routes, event listeners, or any other functionality.

```dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

class PaymentServiceProvider extends ServiceProvider {
  PaymentServiceProvider(super.app);

  @override
  void register() {
    // Bind services into the container
    app.singleton('payment.gateway', () => StripeGateway());
    app.bind('payment.processor', () => PaymentProcessor());
  }

  @override
  Future<void> boot() async {
    // Called after all providers are registered
    final gateway = app.make<StripeGateway>('payment.gateway');
    await gateway.initialize();
  }
}
```

<a name="the-register-method"></a>
### The Register Method

Within the `register` method, you should only bind things into the service container. You should never attempt to register any event listeners, routes, or any other piece of functionality within the `register` method.

This is because you may accidentally use a service from another provider that has not been loaded yet.

```dart
@override
void register() {
  // ✅ Good: Only bind services
  app.singleton('analytics', () => AnalyticsService());
  app.bind('report', () => ReportGenerator());
  
  // ❌ Bad: Don't use other services here
  // final auth = Auth.instance; // May not be ready!
}
```

#### Binding Types

The service container supports two types of bindings:

| Method | Description |
|--------|-------------|
| `app.bind(key, closure)` | Creates a new instance each time |
| `app.singleton(key, closure)` | Creates a single shared instance |

```dart
// New instance every time
app.bind('report', () => ReportGenerator());

// Same instance every time (singleton)
app.singleton('database', () => DatabaseConnection());
```

<a name="the-boot-method"></a>
### The Boot Method

The `boot` method is called after **all** other service providers have been registered, meaning you have access to all services that have been registered by the framework:

```dart
@override
Future<void> boot() async {
  // ✅ Safe to access any registered service
  final config = Config.get('payment');
  final auth = Auth.instance;
  
  // Register event listeners
  Event.listen<UserLoggedIn>((event) {
    Log.info('User logged in: ${event.user.email}');
  });
  
  // Perform async initialization
  await initializePaymentGateway();
}
```

> [!NOTE]
> The `boot` method supports `async` operations. You may perform asynchronous initialization here.

<a name="registering-providers"></a>
## Registering Providers

All service providers are registered in your `config/app.dart` configuration file using the `providers` key. Each provider is a factory function that receives the application instance:

```dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

Map<String, dynamic> get appConfig => {
  'app': {
    'name': 'My App',
    'providers': [
      // Framework Providers
      (app) => CacheServiceProvider(app),
      (app) => NetworkServiceProvider(app),
      (app) => AuthServiceProvider(app),
      
      // Application Providers
      (app) => AppServiceProvider(app),
      (app) => PaymentServiceProvider(app),
    ],
  },
};
```

### Provider Loading Order

Providers are loaded in the order they are listed:

1. **Register Phase**: `register()` is called on each provider in order
2. **Boot Phase**: `boot()` is called on each provider in order

> [!TIP]
> Place framework providers first, then your custom providers. If Provider B depends on Provider A, ensure A comes before B in the list.

<a name="deferred-providers"></a>
## Deferred Providers

If your provider is **only** registering bindings in the service container without any boot logic, you can make it simpler by returning early from boot:

```dart
class SimpleServiceProvider extends ServiceProvider {
  SimpleServiceProvider(super.app);

  @override
  void register() {
    app.singleton('simple', () => SimpleService());
  }

  @override
  Future<void> boot() async {
    // No boot logic needed
  }
}
```

<a name="built-in-providers"></a>
## Built-in Providers

Magic includes several built-in service providers for core functionality:

| Provider | Purpose |
|----------|---------|
| `CacheServiceProvider` | Cache stores and drivers |
| `NetworkServiceProvider` | HTTP client configuration |
| `AuthServiceProvider` | Authentication guards and state |
| `LocalizationServiceProvider` | Language and locale support |
| `VaultServiceProvider` | Secure storage |
| `DatabaseServiceProvider` | Database connections |
| `EventServiceProvider` | Event dispatching |
| `GateServiceProvider` | Authorization gates and policies |

These providers are typically registered in your `config/app.dart` to enable framework features.
