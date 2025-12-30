/// Logging Configuration Defaults.
///
/// This config file is OPTIONAL. Only create it if you want to customize
/// the logging behavior. The default channel is 'stack' which logs to console.
Map<String, dynamic> defaultLoggingConfig = {
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
      // Future: file, daily, slack, etc.
    },
  },
};
