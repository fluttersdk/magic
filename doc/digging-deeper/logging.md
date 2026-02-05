# Logging

- [Introduction](#introduction)
- [Configuration](#configuration)
    - [Available Channels](#available-channels)
    - [Minimum Log Level](#minimum-log-level)
    - [Stack Channel](#stack-channel)
- [Writing Log Messages](#writing-log-messages)
    - [Log Levels](#log-levels)
    - [Contextual Information](#contextual-information)
- [Creating Custom Channels](#creating-custom-channels)
    - [Implementing a Custom Driver](#implementing-a-custom-driver)
    - [Registering the Custom Driver](#registering-the-custom-driver)

<a name="introduction"></a>
## Introduction

Magic provides a robust, Laravel-style logging system based on RFC 5424 severity levels. The `Log` facade provides a simple interface for writing log messages to various destinations (console, files, remote services).

The logging system is:
- **Channel-Based**: Route logs to specific destinations using named channels.
- **Extensible**: Create custom drivers to send logs anywhere (Sentry, Slack, Firebase, etc.).
- **Level-Aware**: Filter messages based on severity threshold.

<a name="configuration"></a>
## Configuration

Configure logging in `lib/config/logging.dart`:

```dart
// lib/config/logging.dart
final Map<String, dynamic> logging = {
  // Default channel used by Log facade
  'default': 'console',

  // Channel configurations
  'channels': {
    'console': {
      'driver': 'console',
      'level': 'debug',
    },

    'production': {
      'driver': 'console',
      'level': 'warning',  // Only warning and above in production
    },

    'stack': {
      'driver': 'stack',
      'channels': ['console', 'sentry'],
    },

    'sentry': {
      'driver': 'sentry',
      'dsn': Config.get('SENTRY_DSN'),
      'level': 'error',
    },
  },
};
```

<a name="available-channels"></a>
### Available Channels

Magic includes these built-in drivers:

| Driver | Description |
|--------|-------------|
| `console` | Pretty-prints to debug console with colors and emojis |
| `stack` | Broadcasts to multiple channels simultaneously |

<a name="minimum-log-level"></a>
### Minimum Log Level

Each channel can specify a minimum `level`. Messages below this threshold are ignored:

```dart
'channels': {
  'production': {
    'driver': 'console',
    'level': 'warning',  // Ignores debug, info, notice
  },
}
```

**Levels by priority** (RFC 5424):
| Level | Priority | Description |
|-------|----------|-------------|
| `emergency` | 0 | System is unusable |
| `alert` | 1 | Action must be taken immediately |
| `critical` | 2 | Critical conditions |
| `error` | 3 | Runtime errors |
| `warning` | 4 | Warning conditions |
| `notice` | 5 | Normal but significant |
| `info` | 6 | Informational |
| `debug` | 7 | Detailed debug information |

<a name="stack-channel"></a>
### Stack Channel

Use the `stack` driver to send logs to multiple channels at once:

```dart
'stack': {
  'driver': 'stack',
  'channels': ['console', 'sentry', 'slack'],
}
```

When you log to the `stack` channel, the message is forwarded to `console`, `sentry`, and `slack` simultaneously.

<a name="writing-log-messages"></a>
## Writing Log Messages

<a name="log-levels"></a>
### Log Levels

Use the `Log` facade to write messages at any RFC 5424 level:

```dart
Log.emergency('System is unusable');
Log.alert('Action must be taken immediately');
Log.critical('Critical condition');
Log.error('Runtime error');
Log.warning('Warning condition');
Log.notice('Normal but significant condition');
Log.info('Informational message');
Log.debug('Debug-level message');
```

For dynamic level selection:

```dart
Log.log('info', 'User logged in');
```

<a name="contextual-information"></a>
### Contextual Information

Pass additional data as the second argument:

```dart
Log.error('Payment failed', {
  'user_id': user.id,
  'amount': 50.00,
  'error': e.toString(),
  'stack_trace': stackTrace.toString(),
});
```

This context is formatted and displayed alongside the message.

<a name="creating-custom-channels"></a>
## Creating Custom Channels

Magic's logging system is fully extensible. You can create custom drivers to send logs to any destination.

<a name="implementing-a-custom-driver"></a>
### Implementing a Custom Driver

Create a class that extends `LoggerDriver`:

```dart
// lib/app/logging/sentry_logger_driver.dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class SentryLoggerDriver extends LoggerDriver {
  final String dsn;
  final String minLevel;

  SentryLoggerDriver({
    required this.dsn,
    this.minLevel = 'error',
  });

  @override
  void log(String level, String message, [dynamic context]) {
    // Only log if level is at or above minLevel
    if (!_shouldLog(level)) return;

    Sentry.captureMessage(
      message,
      level: _sentryLevel(level),
      withScope: (scope) {
        if (context is Map) {
          context.forEach((key, value) {
            scope.setExtra(key.toString(), value);
          });
        }
      },
    );
  }

  bool _shouldLog(String level) {
    const levels = ['emergency', 'alert', 'critical', 'error', 'warning', 'notice', 'info', 'debug'];
    final levelIndex = levels.indexOf(level);
    final minIndex = levels.indexOf(minLevel);
    return levelIndex <= minIndex;
  }

  SentryLevel _sentryLevel(String level) {
    switch (level) {
      case 'emergency':
      case 'alert':
      case 'critical':
        return SentryLevel.fatal;
      case 'error':
        return SentryLevel.error;
      case 'warning':
        return SentryLevel.warning;
      default:
        return SentryLevel.info;
    }
  }
}
```

<a name="registering-the-custom-driver"></a>
### Registering the Custom Driver

Register your driver in a Service Provider:

```dart
// lib/app/providers/logging_service_provider.dart
class LoggingServiceProvider extends ServiceProvider {
  @override
  void register() {
    // Extend LogManager to support custom drivers
    app.extend('log', (manager) {
      final logManager = manager as LogManager;
      
      // Register custom driver factory
      logManager.registerDriver('sentry', (config) {
        return SentryLoggerDriver(
          dsn: config['dsn'] ?? '',
          minLevel: config['level'] ?? 'error',
        );
      });
      
      return logManager;
    });
  }
}
```

> [!NOTE]
> The `registerDriver` method is a convention. If `LogManager` doesn't support it natively, you can extend it or customize resolution logic.

Then use it in your config:

```dart
'channels': {
  'sentry': {
    'driver': 'sentry',
    'dsn': 'https://your-sentry-dsn',
    'level': 'error',
  },
}
```

And log to it:

```dart
Log.channel('sentry').error('Something went wrong', {
  'user_id': user.id,
});
```

---

## Example: Slack Notifications

Here's a complete example for Slack webhook logging:

```dart
class SlackLoggerDriver extends LoggerDriver {
  final String webhookUrl;
  final String channel;
  
  SlackLoggerDriver({required this.webhookUrl, this.channel = '#alerts'});
  
  @override
  void log(String level, String message, [dynamic context]) {
    final payload = {
      'channel': channel,
      'username': 'Magic Bot',
      'icon_emoji': _emoji(level),
      'text': '[$level] $message',
      'attachments': context != null ? [{'text': context.toString()}] : null,
    };
    
    Http.post(webhookUrl, data: payload);
  }
  
  String _emoji(String level) {
    switch (level) {
      case 'emergency':
      case 'critical': return ':fire:';
      case 'error': return ':x:';
      case 'warning': return ':warning:';
      default: return ':information_source:';
    }
  }
}
```
