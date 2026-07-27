import 'package:dio/dio.dart';
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
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            await LocalStorage.clear();

            AppRouter.router.go('/login');
          }
          return handler.next(e);
        },
      ),
    );
  }
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
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
          return TimeoutException();
        case DioExceptionType.badResponse:
          if (e.response?.statusCode == 401) {
            return UnauthorizedException();
          } else if (e.response?.statusCode != null && e.response!.statusCode! >= 500) {
            return ServerException();
          }
          return AppException(
              e.response?.data['message'] ?? 'An error occurred');
        default:
          return UnknownException();
      }
    }
    return UnknownException(e.toString());
  }
}
