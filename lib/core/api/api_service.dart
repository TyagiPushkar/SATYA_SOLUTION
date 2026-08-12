import 'dart:async';
import 'package:dio/dio.dart';
import './api_endpoints.dart';
import './dio_client.dart';
import '../exception/app_exception.dart';
import '../network/network_checker.dart';
import '../storage/local_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../router/app_router.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

class ApiService {
  late final Dio _dio;
  bool _isRefreshing = false;
  Completer<String?>? _refreshTokenCompleter;

  ApiService() {
    _dio = DioClient.getInstance();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!await NetworkChecker.hasInternetAccess()) {
            return handler.reject(
              DioException(
                requestOptions: options,
                error: NetworkException(),
              ),
            );
          }

          final token = await LocalStorage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            final refreshToken = await LocalStorage.getRefreshToken();
            if (refreshToken != null && refreshToken.isNotEmpty) {
              options.headers['Cookie'] =
                  'accessToken=$token; refreshToken=$refreshToken';
            } else {
              options.headers['Cookie'] = 'accessToken=$token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            final path = e.requestOptions.path;
            final isRetry = e.requestOptions.extra['isRetry'] == true;

            // If this request was already retried or is login/refresh-token itself, fail & redirect to login
            if (isRetry ||
                path.contains(ApiEndpoints.refreshToken) ||
                path.contains(ApiEndpoints.login)) {
              await LocalStorage.clear();
              AppRouter.router.go('/login');
              return handler.next(e);
            }

            final newToken = await _tryRefreshToken();
            if (newToken != null && newToken.isNotEmpty) {
              try {
                final options = e.requestOptions;
                options.extra['isRetry'] = true;
                options.headers['Authorization'] = 'Bearer $newToken';
                final currentRefreshToken = await LocalStorage.getRefreshToken();
                if (currentRefreshToken != null && currentRefreshToken.isNotEmpty) {
                  options.headers['Cookie'] =
                      'accessToken=$newToken; refreshToken=$currentRefreshToken';
                } else {
                  options.headers['Cookie'] = 'accessToken=$newToken';
                }

                final response = await _dio.fetch(options);
                return handler.resolve(response);
              } catch (retryError) {
                if (retryError is DioException) {
                  return handler.next(retryError);
                }
                return handler.next(e);
              }
            } else {
              await LocalStorage.clear();
              AppRouter.router.go('/login');
              return handler.next(e);
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  Future<String?> _tryRefreshToken() async {
    if (_isRefreshing) {
      return await _refreshTokenCompleter?.future;
    }

    _isRefreshing = true;
    _refreshTokenCompleter = Completer<String?>();

    try {
      final refreshToken = await LocalStorage.getRefreshToken();
      final accessToken = await LocalStorage.getToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshTokenCompleter?.complete(null);
        _isRefreshing = false;
        return null;
      }

      final refreshDio = Dio(
        BaseOptions(
          baseUrl: ApiEndpoints.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      final headers = <String, dynamic>{
        'Content-Type': 'application/json',
      };

      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
        headers['Cookie'] = 'accessToken=$accessToken; refreshToken=$refreshToken';
      } else {
        headers['Cookie'] = 'refreshToken=$refreshToken';
      }

      final response = await refreshDio.post(
        ApiEndpoints.refreshToken,
        data: {
          'refreshToken': refreshToken,
        },
        options: Options(headers: headers),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        String? newAccessToken;
        String? newRefreshToken;

        if (response.data is Map<String, dynamic>) {
          final resMap = response.data as Map<String, dynamic>;
          final dataMap = resMap['data'];
          if (dataMap is Map<String, dynamic>) {
            newAccessToken = dataMap['accessToken']?.toString() ?? dataMap['token']?.toString();
            newRefreshToken = dataMap['refreshToken']?.toString();
          } else {
            newAccessToken = resMap['accessToken']?.toString() ?? resMap['token']?.toString();
            newRefreshToken = resMap['refreshToken']?.toString();
          }
        }

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          await LocalStorage.saveToken(newAccessToken);
          if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
            await LocalStorage.saveRefreshToken(newRefreshToken);
          }
          _refreshTokenCompleter?.complete(newAccessToken);
          _isRefreshing = false;
          return newAccessToken;
        }
      }

      _refreshTokenCompleter?.complete(null);
      _isRefreshing = false;
      return null;
    } catch (e) {
      _refreshTokenCompleter?.complete(null);
      _isRefreshing = false;
      return null;
    }
  }

  Future<Response> get(String path,
      {Map<String, dynamic>? queryParameters, Options? options}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters, options: options);
    } catch (e) {
      throw _handleException(e);
    }
  }
  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } catch (e) {
      throw _handleException(e);
    }
  }
  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } catch (e) {
      throw _handleException(e);
    }
  }
  Future<Response> delete(String path, {dynamic data}) async {
    try {
      return await _dio.delete(path, data: data);
    } catch (e) {
      throw _handleException(e);
    }
  }
  AppException _handleException(dynamic e) {
    if (e is DioException) {
      if (e.error is AppException) {
        return e.error as AppException;
      }
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return TimeoutException('Server connection timed out (${ApiEndpoints.socketUrl})');
        case DioExceptionType.connectionError:
          return NetworkException('Server is offline or unreachable (${ApiEndpoints.socketUrl})');
        case DioExceptionType.badResponse:
          if (e.response?.statusCode == 401) {
            return UnauthorizedException();
          } else if (e.response?.statusCode != null && e.response!.statusCode! >= 500) {
            return ServerException();
          }
          return AppException(
              e.response?.data['message'] ?? 'An error occurred');
        default:
          final errDetail = e.error?.toString() ?? e.message ?? '';
          if (errDetail.contains('Connection refused') || errDetail.contains('SocketException')) {
            return NetworkException('Server is offline or unreachable (${ApiEndpoints.socketUrl})');
          }
          return UnknownException(errDetail.isNotEmpty ? errDetail : 'An error occurred');
      }
    }
    return UnknownException(e.toString());
  }
}
