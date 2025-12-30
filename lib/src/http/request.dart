import '../routing/magic_router.dart';

/// The Request Facade.
///
/// Access request data like route parameters, query strings, and
/// (eventually) form input from anywhere in your application.
///
/// ## Route Parameters
///
/// For a route `/users/:id` navigating to `/users/42`:
///
/// ```dart
/// final userId = Request.route('id'); // '42'
/// ```
///
/// ## Query Parameters
///
/// For a URL `/search?q=flutter&page=2`:
///
/// ```dart
/// final query = Request.query('q');     // 'flutter'
/// final page = Request.query('page');   // '2'
/// ```
///
/// ## All Parameters
///
/// ```dart
/// final allRouteParams = Request.routeParams;
/// final allQueryParams = Request.queryParams;
/// ```
class Request {
  // Prevent instantiation
  Request._();

  // ---------------------------------------------------------------------------
  // Route Parameters
  // ---------------------------------------------------------------------------

  /// Get a path parameter from the current route.
  ///
  /// For route `/users/:id` accessing `/users/42`:
  ///
  /// ```dart
  /// final id = Request.route('id'); // '42'
  /// ```
  static String? route(String key) {
    return MagicRouter.instance.pathParameter(key);
  }

  /// Get all path parameters as a Map.
  ///
  /// ```dart
  /// // Route: /posts/:category/:id → /posts/tech/42
  /// final params = Request.routeParams;
  /// // {'category': 'tech', 'id': '42'}
  /// ```
  static Map<String, String> get routeParams {
    return MagicRouter.instance.pathParameters;
  }

  // ---------------------------------------------------------------------------
  // Query Parameters
  // ---------------------------------------------------------------------------

  /// Get a query parameter from the current URL.
  ///
  /// For URL `/search?q=flutter`:
  ///
  /// ```dart
  /// final query = Request.query('q'); // 'flutter'
  /// ```
  static String? query(String key) {
    return MagicRouter.instance.queryParameter(key);
  }

  /// Get all query parameters as a Map.
  ///
  /// ```dart
  /// // URL: /search?q=flutter&sort=desc
  /// final params = Request.queryParams;
  /// // {'q': 'flutter', 'sort': 'desc'}
  /// ```
  static Map<String, String> get queryParams {
    return MagicRouter.instance.queryParameters;
  }

  // ---------------------------------------------------------------------------
  // Combined Access
  // ---------------------------------------------------------------------------

  /// Get all parameters (route + query) merged.
  ///
  /// Route parameters take precedence over query parameters.
  ///
  /// ```dart
  /// final all = Request.all();
  /// ```
  static Map<String, String> all() {
    return {
      ...queryParams,
      ...routeParams, // Route params override query params
    };
  }

  /// Check if a parameter exists (in route or query).
  static bool has(String key) {
    return routeParams.containsKey(key) || queryParams.containsKey(key);
  }

  /// Get a parameter from either route or query.
  ///
  /// Checks route parameters first, then query parameters.
  static String? input(String key) {
    return route(key) ?? query(key);
  }
}
