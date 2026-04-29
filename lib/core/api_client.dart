import 'package:dio/dio.dart';
import 'constants/api_constants.dart';

/// Singleton Dio HTTP client for all API calls.
class ApiClient {
  ApiClient._();

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      sendTimeout: ApiConstants.sendTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  )..interceptors.addAll([
      _LoggingInterceptor(),
      _RetryInterceptor(),
    ]);

  static Dio get instance => _dio;

  /// Update the base URL at runtime (e.g., from settings).
  static void updateBaseUrl(String newUrl) {
    _dio.options.baseUrl = newUrl;
  }
}

/// Logs requests and responses for debugging.
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // ignore: avoid_print
    print('[API] → ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // ignore: avoid_print
    print('[API] ← ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // ignore: avoid_print
    print('[API] ✗ ${err.type} ${err.requestOptions.uri}: ${err.message}');
    handler.next(err);
  }
}

/// Retries failed requests up to 2 times with exponential backoff.
class _RetryInterceptor extends Interceptor {
  static const _maxRetries = 2;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = err.requestOptions.extra['_retryCount'] as int? ?? 0;

    // Only retry on connection/timeout errors, not on 4xx/5xx
    final shouldRetry = retryCount < _maxRetries &&
        (err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.receiveTimeout ||
            err.type == DioExceptionType.connectionError);

    if (shouldRetry) {
      final nextRetry = retryCount + 1;
      final delay = Duration(milliseconds: 500 * nextRetry);

      // ignore: avoid_print
      print('[API] ↻ Retry $nextRetry/$_maxRetries after ${delay.inMilliseconds}ms');
      await Future.delayed(delay);

      try {
        err.requestOptions.extra['_retryCount'] = nextRetry;
        final response = await ApiClient.instance.fetch(err.requestOptions);
        handler.resolve(response);
      } catch (e) {
        handler.next(err);
      }
    } else {
      handler.next(err);
    }
  }
}
