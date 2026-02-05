/// Auth Configuration
///
/// This file customizes the authentication settings for your application.
/// It overrides the default settings from the Magic framework.
///
/// ## API Endpoints
///
/// Customize the endpoints to match your backend API structure.
/// By default, Magic expects Laravel Breeze/Fortify-style endpoints.
///
/// ## Response Parser
///
/// If your API returns a different format, implement `AuthResponseParser`
/// and set it in the config.
///
/// ## Expected Response Format
///
/// ```json
/// {
///   "data": {
///     "user": { "id": 1, "name": "John", "email": "john@example.com" },
///     "token": "plain-text-token"
///   },
///   "message": "Login successful"
/// }
/// ```
Map<String, dynamic> get authConfig => {
      'auth': {
        'defaults': {'guard': 'api', 'passwords': 'users'},
        'guards': {
          'api': {'driver': 'sanctum', 'provider': 'users'},
        },
        'providers': {
          'users': {'driver': 'eloquent', 'model': 'User'},
        },
        // -----------------------------------------------------------------------
        // Customize your API endpoints here
        // -----------------------------------------------------------------------
        'endpoints': {
          'login': '/api/login',
          'logout': '/api/logout',
          'register': '/api/register',
          'user': '/api/user',
          'refresh': '/api/refresh',
          'forgot_password': '/api/forgot-password',
          'reset_password': '/api/reset-password',
        },
        // -----------------------------------------------------------------------
        // Token Configuration
        // -----------------------------------------------------------------------
        'token': {'key': 'auth_token', 'refresh_key': 'refresh_token'},
        // -----------------------------------------------------------------------
        // Device Name (optional)
        // -----------------------------------------------------------------------
        // 'device_name': 'My Flutter App',
        // -----------------------------------------------------------------------
        // Auto-login on app restart
        // -----------------------------------------------------------------------
        'auto_refresh': true,
      },
    };
