import '../src/cache/drivers/file_store.dart';

/// Default Cache Configuration.
Map<String, dynamic> defaultCacheConfig = {
  'cache': {
    'driver': FileStore(),
    'ttl': 3600,
  },
};
