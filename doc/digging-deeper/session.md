# Session & Flash Data

- [Introduction](#introduction)
- [Flashing Input](#flashing-input)
- [Flashing Errors](#flashing-errors)
- [Reading Old Input](#reading-old-input)
- [Automatic Flash in MagicFormData](#automatic-flash-in-magicformdata)
- [Advancing the Flash Bucket](#advancing-the-flash-bucket)
- [Testing](#testing)

<a name="introduction"></a>
## Introduction

The `Session` facade provides Laravel-style flash data that survives exactly one navigation hop. Use it to repopulate a form after a failed submit and a back navigation without wiring temporary state through controllers, the router, or global singletons.

The store has two buckets: the **current** bucket (readable by the view being built right now) and the **next** bucket (being collected by the currently-active handler). A call to `Session.tick()` promotes `next` into `current`, so flashed data is visible on exactly one frame.

<a name="flashing-input"></a>
## Flashing Input

Flash a map of values before navigating away:

```dart
Session.flash({
  'name': 'John',
  'email': 'john@test.com',
});
MagicRoute.back();
```

<a name="flashing-errors"></a>
## Flashing Errors

Flash per-field error messages:

```dart
Session.flashErrors({
  'email': ['The email has already been taken.'],
});
```

<a name="reading-old-input"></a>
## Reading Old Input

In the form view, repopulate via the `old()` helper:

```dart
WFormInput(
  initialValue: old('email') ?? '',
);

if (Session.hasError('email'))
  WText(Session.error('email')!, className: 'text-red-500');
```

`Session.oldRaw(field)` returns the original typed value (booleans, numbers, custom objects) instead of stringifying it.

<a name="automatic-flash-in-magicformdata"></a>
## Automatic Flash in MagicFormData

`MagicFormData.validate()` automatically flashes the current form data when validation fails, so you never need to wire it manually:

```dart
void _submit() {
  if (!form.validate()) return; // form data is auto-flashed on failure
  controller.register(form.data);
}
```

After a back navigation and a `Session.tick()`, `old('email')` returns the last-submitted value.

<a name="advancing-the-flash-bucket"></a>
## Advancing the Flash Bucket

Flash data survives exactly one navigation. Advance the bucket only when the router location actually changes. Do **not** wire `Session.tick` directly to the router delegate listener: the delegate can notify for more than real navigation (redirect re-evaluation, notifier rebuilds) and would expire flash data prematurely.

```dart
var lastLocation = MagicRouter.instance.currentLocation;

MagicRouter.instance.routerConfig.routerDelegate.addListener(() {
  final currentLocation = MagicRouter.instance.currentLocation;
  if (currentLocation == lastLocation) return;
  lastLocation = currentLocation;
  Session.tick();
});
```

Place this in a `ServiceProvider.boot()` after `Magic.init()` completes.

<a name="testing"></a>
## Testing

In tests, always reset the store in `setUp()`:

```dart
setUp(() {
  MagicApp.reset();
  Magic.flush();
  Session.reset();
});
```

Swap the backing store with a custom `SessionStore` via `Session.setStore(store)` if you need isolated buckets per test group.
