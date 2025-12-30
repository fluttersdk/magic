# Service Providers

## Introduction

Service providers are the central place of all Magic application bootstrapping. Your own application, as well as all of Magic's core services, are bootstrapped via service providers.

But, what do we mean by "bootstrapped"? In general, we mean **registering** things, including registering service container bindings, event listeners, middleware, and even routes. Service providers are the central place to configure your application.

## Writing Service Providers

All service providers extend the `ServiceProvider` class. Most service providers contain a `register` and a `boot` method. Within the `register` method, you should **only bind things into the service container**. Within the `boot` method, you may do anything else: register routes, event listeners, or any other functionality:

```dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

class UserServiceProvider extends ServiceProvider {
  UserServiceProvider(super.app);

  @override
  void register() {
    // Bind services into the container
    app.singleton('user.service', () => UserService());
  }

  @override
  Future<void> boot() async {
    // Called after all providers are registered
    final userService = app.make<UserService>('user.service');
    await userService.initialize();
  }
}
```

## Registering Providers

All service providers are registered in your `config/app.dart` configuration file. You may register your providers using the `providers` key:

```dart
final appConfig = {
  'app': {
    'providers': [
      // Framework Providers
      (app) => RouteServiceProvider(app),
      (app) => AuthServiceProvider(app),
      
      // Application Providers
      (app) => UserServiceProvider(app),
      (app) => PaymentServiceProvider(app),
    ],
  }
};
```

## The Register Method

Within the `register` method, you should only bind things into the service container. You should never attempt to register any event listeners, routes, or any other piece of functionality within the `register` method:

```dart
@override
void register() {
  app.singleton('payment.gateway', () => StripeGateway());
  
  app.bind('report.generator', () => ReportGenerator());
}
```

## The Boot Method

This method is called after all other service providers have been registered, meaning you have access to all other services that have been registered by the framework:

```dart
@override
Future<void> boot() async {
  // Access services registered by other providers
  final auth = Auth.instance;
  
  // Register routes, event listeners, etc.
  Event.listen<UserLoggedIn>((event) {
    Log.info('User logged in: ${event.user.email}');
  });
}
```

> **Note**  
> The `boot` method supports `async` operations. You may perform asynchronous initialization here.
