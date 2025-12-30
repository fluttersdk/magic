/// Magic Network Request.
///
/// Driver-agnostic request options for HTTP requests.
class MagicRequest {
  /// Request URL.
  String url;

  /// HTTP method (GET, POST, PUT, DELETE, etc.).
  String method;

  /// Request headers.
  Map<String, dynamic> headers;

  /// Request body data.
  dynamic data;

  /// Query parameters.
  Map<String, dynamic>? queryParameters;

  MagicRequest({
    required this.url,
    this.method = 'GET',
    this.headers = const {},
    this.data,
    this.queryParameters,
  });
}

/// Magic Network Error.
///
/// Driver-agnostic error wrapper for failed HTTP requests.
class MagicError {
  /// The original request.
  final MagicRequest? request;

  /// The response (if any).
  final MagicResponse? response;

  /// Error message.
  final String? message;

  /// HTTP status code (if available).
  int get statusCode => response?.statusCode ?? 0;

  /// Is this a 401 Unauthorized error?
  bool get isUnauthorized => statusCode == 401;

  MagicError({
    this.request,
    this.response,
    this.message,
  });
}

/// The Magic Network Response wrapper.
///
/// This class wraps all HTTP responses, providing a consistent interface
/// regardless of the underlying HTTP client. It mimics Laravel's
/// `Illuminate\Http\Client\Response`.
class MagicResponse {
  /// The raw response data.
  final dynamic data;

  /// The HTTP status code.
  final int statusCode;

  /// The response headers.
  final Map<String, dynamic> headers;

  /// An optional message (useful for errors).
  final String? message;

  /// Creates a new MagicResponse instance.
  MagicResponse({
    required this.data,
    required this.statusCode,
    this.headers = const {},
    this.message,
  });

  /// Check if the response was successful (2xx status code).
  bool get successful => statusCode >= 200 && statusCode < 300;

  /// Check if the response failed (4xx or 5xx status code).
  bool get failed => statusCode >= 400;

  /// Check if the response was a client error (4xx).
  bool get clientError => statusCode >= 400 && statusCode < 500;

  /// Check if the response was a server error (5xx).
  bool get serverError => statusCode >= 500;

  /// Check if the response was unauthorized (401).
  bool get unauthorized => statusCode == 401;

  /// Check if the response was forbidden (403).
  bool get forbidden => statusCode == 403;

  /// Check if the response was not found (404).
  bool get notFound => statusCode == 404;

  /// Check if the response is a validation error (422).
  bool get isValidationError => statusCode == 422;

  // ---------------------------------------------------------------------------
  // Validation Error Helpers
  // ---------------------------------------------------------------------------

  /// Get the validation errors map from a 422 response.
  Map<String, List<String>> get errors {
    if (data is! Map<String, dynamic>) return {};

    final errorsData = (data as Map<String, dynamic>)['errors'];
    if (errorsData is! Map<String, dynamic>) return {};

    final result = <String, List<String>>{};
    for (final entry in errorsData.entries) {
      if (entry.value is List) {
        result[entry.key] = (entry.value as List).cast<String>();
      }
    }
    return result;
  }

  /// Get all validation error messages as a flat list.
  List<String> get errorsList {
    final allErrors = <String>[];
    for (final fieldErrors in errors.values) {
      allErrors.addAll(fieldErrors);
    }
    return allErrors;
  }

  /// Get the first validation error message.
  String? get firstError {
    final allErrors = errorsList;
    if (allErrors.isNotEmpty) return allErrors.first;
    if (data is Map<String, dynamic>) {
      return (data as Map<String, dynamic>)['message'] as String?;
    }
    return message;
  }

  /// Get the main error message.
  String? get errorMessage {
    if (data is Map<String, dynamic>) {
      return (data as Map<String, dynamic>)['message'] as String?;
    }
    return message;
  }

  /// Cast the data to a specific type.
  T dataAs<T>() => data as T;

  /// Get a value from the data map by key.
  dynamic operator [](String key) {
    if (data is Map) return (data as Map)[key];
    return null;
  }

  @override
  String toString() =>
      'MagicResponse(status: $statusCode, message: $message, data: $data)';
}
