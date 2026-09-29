import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../contracts/network_driver.dart';
import '../contracts/magic_network_interceptor.dart';
import '../magic_response.dart';

/// The Dio-based Network Driver.
///
/// Translates between Dio types and Magic types for interceptors.
class DioNetworkDriver implements NetworkDriver {
  /// Where a request's id travels in [RequestOptions.extra], so every hop
  /// that only sees Dio's options (an error, a response) can still name it.
  static const String _requestIdKey = 'magic.request_id';

  /// Process-wide rather than per driver: two drivers must never hand the
  /// same id to two different requests a consumer is pairing.
  static int _lastRequestId = 0;

  late final Dio _dio;
  final String baseUrl;
  final int timeout;
  final Map<String, String> defaultHeaders;

  DioNetworkDriver({
    required this.baseUrl,
    this.timeout = 10000,
    this.defaultHeaders = const {},
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: Duration(milliseconds: timeout),
        receiveTimeout: Duration(milliseconds: timeout),
        headers: defaultHeaders,
        // Dio defaults this to false, so the IO adapter lowercases every
        // header key on the wire (e.g. `User-Agent` -> `user-agent`). A
        // case-sensitive consumer (ExoPlayer's header lookup) silently gets
        // the wrong value instead of an error, so preserve the caller's
        // casing rather than let Dio normalise it away.
        preserveHeaderCase: true,
      ),
    );

    // Added first so every interceptor after it, and every response or
    // error the request produces, sees the id. `putIfAbsent` keeps it when
    // Dio re-runs the same options through the chain.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          options.extra.putIfAbsent(_requestIdKey, () => ++_lastRequestId);
          handler.next(options);
        },
      ),
    );
  }

  @override
  void addInterceptor(MagicNetworkInterceptor interceptor) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Convert Dio RequestOptions to MagicRequest
          final magicRequest = MagicRequest(
            url: options.path,
            method: options.method,
            headers: Map<String, dynamic>.from(options.headers),
            data: options.data,
            queryParameters: options.queryParameters,
            id: _requestId(options),
          );

          final result = await interceptor.onRequest(magicRequest);

          if (result is MagicRequest) {
            // Apply changes back to Dio options
            options.path = result.url;
            options.method = result.method;
            options.headers.addAll(result.headers);
            options.data = result.data;
            if (result.queryParameters != null) {
              options.queryParameters = result.queryParameters!;
            }
          }

          handler.next(options);
        },
        onResponse: (response, handler) async {
          // Convert Dio Response to MagicResponse and call interceptor
          final magicResponse = _toMagicResponse(response);
          await interceptor.onResponse(magicResponse);
          handler.next(response);
        },
        onError: (error, handler) async {
          // Convert DioException to MagicError
          final magicRequest = MagicRequest(
            url: error.requestOptions.path,
            method: error.requestOptions.method,
            headers: Map<String, dynamic>.from(error.requestOptions.headers),
            data: error.requestOptions.data,
            queryParameters: error.requestOptions.queryParameters,
            id: _requestId(error.requestOptions),
          );

          MagicResponse? magicResponse;
          if (error.response != null) {
            magicResponse = _toMagicResponse(error.response!);
          }

          final magicError = MagicError(
            request: magicRequest,
            response: magicResponse,
            message: error.message,
          );

          final result = await interceptor.onError(magicError);

          if (result is MagicResponse) {
            // Interceptor resolved the error (e.g., after retry)
            handler.resolve(
              Response(
                requestOptions: error.requestOptions,
                data: result.data,
                statusCode: result.statusCode,
                headers: Headers.fromMap(
                  result.headers.map((k, v) => MapEntry(k, [v.toString()])),
                ),
              ),
            );
          } else {
            // Continue with error
            handler.next(error);
          }
        },
      ),
    );
  }

  /// Configure the underlying Dio instance directly.
  ///
  /// Use this for SDK integrations that need raw Dio access
  /// (e.g., `sentry_dio`, certificate pinning, custom adapters).
  ///
  /// ```dart
  /// final driver = Magic.make<DioNetworkDriver>('network');
  /// driver.configureDriver((dio) {
  ///   dio.addSentry();
  /// });
  /// ```
  void configureDriver(void Function(Dio dio) configurator) {
    configurator(_dio);
  }

  // ---------------------------------------------------------------------------
  // RESTful Resource Methods
  // ---------------------------------------------------------------------------

  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) async {
    return get('/$resource', query: filters, headers: headers);
  }

  @override
  Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async {
    return get('/$resource/$id', headers: headers);
  }

  @override
  Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async {
    return post('/$resource', data: data, headers: headers);
  }

  @override
  Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async {
    return put('/$resource/$id', data: data, headers: headers);
  }

  @override
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async {
    return delete('/$resource/$id', headers: headers);
  }

  // ---------------------------------------------------------------------------
  // Raw HTTP Methods
  // ---------------------------------------------------------------------------

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.get(
        url,
        queryParameters: query,
        options: Options(headers: headers),
      );
      return _toMagicResponse(response);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.post(
        url,
        data: data,
        options: Options(headers: headers),
      );
      return _toMagicResponse(response);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.put(
        url,
        data: data,
        options: Options(headers: headers),
      );
      return _toMagicResponse(response);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.delete(
        url,
        options: Options(headers: headers),
      );
      return _toMagicResponse(response);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) async {
    try {
      final processedFiles = await _processFiles(files);
      final formData = FormData.fromMap({...data, ...processedFiles});

      final response = await _dio.post(
        url,
        data: formData,
        options: Options(
          headers: {...?headers, 'Content-Type': 'multipart/form-data'},
        ),
      );
      return _toMagicResponse(response);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Process files map to handle various input types.
  Future<Map<String, dynamic>> _processFiles(Map<String, dynamic> files) async {
    final result = <String, dynamic>{};

    for (final entry in files.entries) {
      result[entry.key] = await _toMultipartFile(entry.key, entry.value);
    }

    return result;
  }

  /// Convert various file types to MultipartFile.
  Future<MultipartFile> _toMultipartFile(
    String fieldName,
    dynamic value,
  ) async {
    if (value is MultipartFile) return value;

    if (value is String) {
      return MultipartFile.fromFileSync(value);
    }

    if (value is Uint8List) {
      return MultipartFile.fromBytes(value, filename: fieldName);
    }

    if (value is List<int>) {
      return MultipartFile.fromBytes(value, filename: fieldName);
    }

    if (_isMagicFile(value)) {
      final bytes = await value.readAsBytes();
      if (bytes == null) {
        throw ArgumentError('MagicFile has no bytes to upload');
      }
      return MultipartFile.fromBytes(
        bytes,
        filename: value.name ?? fieldName,
        contentType: value.mimeType != null
            ? DioMediaType.parse(value.mimeType!)
            : null,
      );
    }

    if (_isXFile(value)) {
      final bytes = await value.readAsBytes();
      return MultipartFile.fromBytes(
        bytes,
        filename: value.name ?? fieldName,
        contentType: value.mimeType != null
            ? DioMediaType.parse(value.mimeType!)
            : null,
      );
    }

    throw ArgumentError(
      'Unsupported file type: ${value.runtimeType}. '
      'Expected String (path), MagicFile, XFile, Uint8List, or List<int>.',
    );
  }

  bool _isMagicFile(dynamic value) {
    try {
      value.name;
      value.readAsBytes;
      value.mimeType;
      return value.runtimeType.toString() == 'MagicFile';
    } catch (_) {
      return false;
    }
  }

  bool _isXFile(dynamic value) {
    try {
      value.name;
      value.readAsBytes;
      value.path;
      return value.runtimeType.toString() == 'XFile';
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  int? _requestId(RequestOptions options) =>
      options.extra[_requestIdKey] as int?;

  MagicResponse _toMagicResponse(Response response) {
    return MagicResponse(
      data: response.data,
      statusCode: response.statusCode ?? 0,
      headers: response.headers.map.map((k, v) => MapEntry(k, v.join(', '))),
      message: response.statusMessage,
      id: _requestId(response.requestOptions),
    );
  }

  MagicResponse _handleError(DioException e) {
    return MagicResponse(
      data: e.response?.data,
      statusCode: e.response?.statusCode ?? 0,
      headers:
          e.response?.headers.map.map((k, v) => MapEntry(k, v.join(', '))) ??
          {},
      message: e.message,
      id: _requestId(e.requestOptions),
    );
  }
}
