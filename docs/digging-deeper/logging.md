# Logging

## Introduction

Magic provides a robust logging system inspired by Laravel. Logs can be sent to the console, multiple channels simultaneously (stack), or custom destinations.

## Configuration

```dart
// config/logging.dart
Map<String, dynamic> get loggingConfig => {
  'logging': {
    'default': 'stack',
    'channels': {
      'stack': {
        'driver': 'stack',
        'channels': ['console'],
      },
      'console': {
        'driver': 'console',
        'level': 'debug',
      },
    },
  },
};
```

## Writing Log Messages

```dart
Log.info('User logged in');
Log.error('Payment failed');
Log.debug('Request completed');
```

### With Context

```dart
Log.info('User logged in', {'id': userId, 'email': email});
Log.error('API failed', {'url': url, 'status': 500});
```

## Log Levels

Magic supports all RFC 5424 log levels:

| Method | Description |
|--------|-------------|
| `Log.emergency()` | System is unusable |
| `Log.alert()` | Action must be taken immediately |
| `Log.critical()` | Critical conditions |
| `Log.error()` | Runtime errors |
| `Log.warning()` | Exceptional occurrences |
| `Log.notice()` | Normal but significant events |
| `Log.info()` | Interesting events |
| `Log.debug()` | Detailed debug information |

## Channels

### Console Channel

Pretty-prints logs with color-coded output:

```dart
'console': {
  'driver': 'console',
  'level': 'debug',
},
```

### Stack Channel

Sends logs to multiple channels:

```dart
'stack': {
  'driver': 'stack',
  'channels': ['console', 'file'],
},
```

## Custom Drivers

```dart
class SlackLoggerDriver extends LoggerDriver {
  @override
  void log(String level, String message, [dynamic context]) {
    // Send to Slack webhook
  }
}
```
