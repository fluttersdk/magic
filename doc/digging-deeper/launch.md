# Launch

- [Introduction](#introduction)
- [Configuration](#configuration)
- [URL Launching](#url-launching)
- [Email](#email)
- [Phone](#phone)
- [SMS](#sms)
- [Checking Availability](#checking-availability)

<a name="introduction"></a>
## Introduction

The `Launch` facade provides a context-free, static API for opening URLs, triggering email clients, initiating phone calls, and composing SMS messages. It wraps the `url_launcher` package and adds consistent error handling — all methods return `false` on failure and log errors via `Log`. They never throw.

<a name="configuration"></a>
## Configuration

### Registering LaunchServiceProvider

`LaunchServiceProvider` is not auto-registered. Add it explicitly to your providers in `config/app.dart`:

```dart
'providers': [
  (app) => LaunchServiceProvider(app),
  // ... other providers
],
```

This registers a `LaunchService` singleton in the Magic IoC container under the key `'launch'`. The `Launch` facade resolves this singleton on every call.

<a name="url-launching"></a>
## URL Launching

Open a URL using the `Launch.url()` method:

```dart
final opened = await Launch.url('https://flutter.dev');
```

### LaunchMode Options

The optional `mode` parameter controls how the URL is opened. It maps directly to `url_launcher`'s `LaunchMode` enum:

| Mode | Behavior |
|------|----------|
| `LaunchMode.externalApplication` | Opens in the default external app (browser, app, etc.) — **default** |
| `LaunchMode.inAppWebView` | Opens inside a WebView within the app |
| `LaunchMode.inAppBrowserView` | Opens in an in-app browser with browser chrome |
| `LaunchMode.externalNonBrowserApplication` | Opens in an external non-browser app |
| `LaunchMode.platformDefault` | Uses the platform's default behavior |

```dart
// Open in the default external browser or app
await Launch.url('https://flutter.dev');

// Open inside an in-app WebView
await Launch.url(
  'https://flutter.dev',
  mode: LaunchMode.inAppWebView,
);

// Open in an in-app browser with navigation controls
await Launch.url(
  'https://flutter.dev',
  mode: LaunchMode.inAppBrowserView,
);
```

> [!TIP]
> Prefer `LaunchMode.externalApplication` for links that users expect to open in their browser. Use `LaunchMode.inAppWebView` only when you want to keep the user inside your app.

### Return Value

`Launch.url()` returns `Future<bool>`. It returns `false` immediately for empty strings and `false` on any URI parse error or launch failure (errors are logged via `Log.error`).

<a name="email"></a>
## Email

Open the device's email client pre-addressed to a recipient:

```dart
// Basic — address only
await Launch.email('hello@example.com');

// With subject and body
await Launch.email(
  'support@example.com',
  subject: 'Bug Report',
  body: 'I found an issue with the login screen.',
);
```

Special characters in `subject` and `body` are automatically URI-encoded. The method returns `false` immediately for an empty address.

<a name="phone"></a>
## Phone

Open the device's phone dialer pre-filled with a number:

```dart
await Launch.phone('+1234567890');
```

The method returns `false` immediately for an empty number string.

> [!TIP]
> Always use the full international format (e.g. `+1234567890`) for phone numbers to ensure portability across regions.

<a name="sms"></a>
## SMS

Open the device's SMS app addressed to a number, with an optional pre-filled message body:

```dart
// Number only
await Launch.sms('+1234567890');

// With pre-filled body
await Launch.sms('+1234567890', body: 'On my way!');
```

Special characters in `body` are automatically URI-encoded. The method returns `false` immediately for an empty number string.

<a name="checking-availability"></a>
## Checking Availability

Before launching, you can check whether the device can handle a given URL scheme using `Launch.canLaunch()`:

```dart
if (await Launch.canLaunch('tel:+1234567890')) {
  await Launch.phone('+1234567890');
} else {
  // Phone calls not supported on this device
}
```

This works for any URL scheme — `https://`, `mailto:`, `tel:`, `sms:`, or custom deep-link schemes:

```dart
// Check before opening a deep link
if (await Launch.canLaunch('myapp://profile/42')) {
  await Launch.url('myapp://profile/42');
}
```

`Launch.canLaunch()` returns `false` for empty strings and malformed URLs.

> [!TIP]
> On **iOS 9+** and **Android 11+**, querying URL scheme availability requires declaring the relevant schemes in the native app manifest. See the [`url_launcher` documentation](https://pub.dev/packages/url_launcher) for platform-specific setup instructions.
