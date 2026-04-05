/// Broadcasting Configuration.
///
/// ## Connections
///
/// - `reverb` — Laravel Reverb WebSocket server (default driver)
/// - `null` — No-op driver; drops all broadcast events silently
///
/// ## Reverb Options
///
/// - `host` / `port` / `scheme` — WebSocket endpoint coordinates
/// - `app_key` — Reverb application key (matches server config)
/// - `auth_endpoint` — HTTP endpoint for private/presence channel auth
/// - `reconnect` — Auto-reconnect on unexpected disconnect
/// - `max_reconnect_delay` — Maximum back-off delay in milliseconds
/// - `activity_timeout` — Seconds of inactivity before ping is sent
/// - `dedup_buffer_size` — Number of recent event IDs kept for deduplication
final Map<String, dynamic> defaultBroadcastingConfig = {
  'broadcasting': {
    // -------------------------------------------------------------------------
    // Default Connection
    // -------------------------------------------------------------------------
    'default': 'null',

    // -------------------------------------------------------------------------
    // Connections
    // -------------------------------------------------------------------------
    'connections': {
      'reverb': {
        'driver': 'reverb',
        'host': 'localhost',
        'port': 8080,
        'scheme': 'ws',
        'app_key': '',
        'auth_endpoint': '/broadcasting/auth',
        'reconnect': true,
        'max_reconnect_delay': 30000,
        'activity_timeout': 120,
        'dedup_buffer_size': 100,
      },
      'null': {'driver': 'null'},
    },
  },
};
