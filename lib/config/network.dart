/// Network Configuration
///
/// Define your API connections here. Each driver represents a distinct
/// API endpoint with its own base URL, headers, and interceptors.
Map<String, dynamic> defaultNetworkConfig = {
  'network': {
    'default': 'api',
    'drivers': {
      'api': {
        'driver': 'dio',
        'base_url': 'https://api.example.com/v1',
        'timeout': 10000,
        'interceptors': [
          // User-defined interceptor class names or factory functions
          // 'AuthInterceptor',
        ],
        'headers': {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      },
    },
  },
};
