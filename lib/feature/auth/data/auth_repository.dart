import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_service.dart';
import '../model/login_model.dart';
abstract class AuthRepository {
  Future<LoginModel> login(String email, String password);
  Future<LoginModel> refreshToken(String refreshToken);
  Future<void> logout();
}
class AuthRepositoryImpl implements AuthRepository {
  final ApiService _apiService;
  AuthRepositoryImpl(this._apiService);
  @override
  Future<LoginModel> login(String email, String password) async {
    final response = await _apiService.post(
      ApiEndpoints.login,
      data: {
        'email': email,
        'password': password,
      },
    );
    return LoginModel.fromJson(response.data);
  }

  @override
  Future<LoginModel> refreshToken(String refreshToken) async {
    final response = await _apiService.post(
      ApiEndpoints.refreshToken,
      data: {
        'refreshToken': refreshToken,
      },
    );
    return LoginModel.fromJson(response.data);
  }

  @override
  Future<void> logout() async {
    await _apiService.post(ApiEndpoints.logout);
  }
}
