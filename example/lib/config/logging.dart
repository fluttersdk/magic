/// Logging Configuration
///
/// Defines the logging channels and levels for the application.
final Map<String, dynamic> loggingConfig = {
  'logging': {
    'default': 'stack',
    'channels': {
      'stack': {
        'driver': 'stack',
        'channels': ['console'],
      },
      'console': {'driver': 'console', 'level': 'debug'},
    },
  },
};
