import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;

/// 네트워크 재시도 설정
class RetryConfig {
  final int maxRetries;
  final Duration baseDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  final List<int> retryableStatusCodes;

  const RetryConfig({
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 10),
    this.retryableStatusCodes = const [408, 500, 502, 503, 504],
  });
}

/// 재시도 결과
class RetryResult<T> {
  final T? data;
  final Exception? error;
  final int attemptCount;
  final bool isSuccess;

  const RetryResult({
    this.data,
    this.error,
    required this.attemptCount,
    required this.isSuccess,
  });
}

/// 네트워크 재시도 서비스
class NetworkRetryService {
  static const RetryConfig _defaultConfig = RetryConfig();

  /// HTTP GET 요청 with 재시도
  static Future<RetryResult<http.Response>> retryHttpGet(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
    RetryConfig config = _defaultConfig,
  }) async {
    return _executeWithRetry<http.Response>(
      () async {
        final response = await http.get(
          Uri.parse(url),
          headers: headers,
        ).timeout(timeout ?? const Duration(seconds: 15));
        
        // HTTP 상태 코드 확인
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        } else if (config.retryableStatusCodes.contains(response.statusCode)) {
          throw HttpException('HTTP ${response.statusCode}: ${response.reasonPhrase}');
        } else {
          throw HttpException('HTTP ${response.statusCode}: ${response.reasonPhrase} (non-retryable)');
        }
      },
      config: config,
      errorDescription: 'HTTP GET $url',
    );
  }

  /// HTTP HEAD 요청 with 재시도  
  static Future<RetryResult<http.Response>> retryHttpHead(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
    RetryConfig config = _defaultConfig,
  }) async {
    return _executeWithRetry<http.Response>(
      () async {
        final response = await http.head(
          Uri.parse(url),
          headers: headers,
        ).timeout(timeout ?? const Duration(seconds: 10));
        
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        } else if (config.retryableStatusCodes.contains(response.statusCode)) {
          throw HttpException('HTTP ${response.statusCode}: ${response.reasonPhrase}');
        } else {
          throw HttpException('HTTP ${response.statusCode}: ${response.reasonPhrase} (non-retryable)');
        }
      },
      config: config,
      errorDescription: 'HTTP HEAD $url',
    );
  }

  /// 일반적인 비동기 작업 재시도
  static Future<RetryResult<T>> retryAsync<T>(
    Future<T> Function() operation, {
    RetryConfig config = _defaultConfig,
    String? operationDescription,
  }) async {
    return _executeWithRetry<T>(
      operation,
      config: config,
      errorDescription: operationDescription ?? 'Async operation',
    );
  }

  /// 재시도 로직 핵심 구현
  static Future<RetryResult<T>> _executeWithRetry<T>(
    Future<T> Function() operation, {
    required RetryConfig config,
    required String errorDescription,
  }) async {
    Exception? lastError;
    
    for (int attempt = 1; attempt <= config.maxRetries + 1; attempt++) {
      try {
        final result = await operation();
        
        if (attempt > 1) {
          print('✅ $errorDescription 성공 (시도: $attempt/${config.maxRetries + 1})');
        }
        
        return RetryResult<T>(
          data: result,
          isSuccess: true,
          attemptCount: attempt,
        );
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        
        // 마지막 시도인 경우
        if (attempt > config.maxRetries) {
          print('❌ $errorDescription 최종 실패 (시도: $attempt/${config.maxRetries + 1}) - $e');
          break;
        }

        // 재시도 불가능한 에러인지 확인
        if (!_isRetryableError(e)) {
          print('❌ $errorDescription 재시도 불가능한 에러 - $e');
          break;
        }

        // 재시도 대기
        final delay = _calculateDelay(attempt - 1, config);
        print('⏳ $errorDescription 재시도 $attempt/${config.maxRetries + 1} (${delay.inMilliseconds}ms 후) - $e');
        
        await Future.delayed(delay);
      }
    }

    return RetryResult<T>(
      error: lastError,
      isSuccess: false,
      attemptCount: config.maxRetries + 1,
    );
  }

  /// 재시도 가능한 에러인지 확인
  static bool _isRetryableError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // 재시도 가능한 에러 패턴들
    return errorString.contains('timeoutexception') ||
           errorString.contains('socketexception') ||
           errorString.contains('handshakeexception') ||
           errorString.contains('connection') ||
           errorString.contains('network') ||
           errorString.contains('timeout') ||
           (error is HttpException && !errorString.contains('(non-retryable)'));
  }

  /// Exponential backoff 지연 시간 계산
  static Duration _calculateDelay(int attemptIndex, RetryConfig config) {
    final baseDelayMs = config.baseDelay.inMilliseconds;
    final exponentialDelay = baseDelayMs * pow(config.backoffMultiplier, attemptIndex);
    
    // Jitter 추가 (±25%)
    final random = Random();
    final jitterFactor = 0.75 + (random.nextDouble() * 0.5); // 0.75 ~ 1.25
    final finalDelay = (exponentialDelay * jitterFactor).round();
    
    // 최대 지연시간 제한
    final clampedDelay = min(finalDelay, config.maxDelay.inMilliseconds);
    
    return Duration(milliseconds: clampedDelay);
  }
}

/// HTTP 예외 클래스
class HttpException implements Exception {
  final String message;
  
  const HttpException(this.message);
  
  @override
  String toString() => 'HttpException: $message';
}