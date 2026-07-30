import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/api/api_service.dart';
import '../../../core/storage/local_storage.dart';
import '../data/auth_repository.dart';
import '../model/employee_model.dart';
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.read(apiServiceProvider));
});
final splashProvider = FutureProvider<bool>((ref) async {
  final token = await LocalStorage.getToken();
  if (token != null) {
    return true;
  }
  return false;
});

final currentUserProvider = FutureProvider<EmployeeModel?>((ref) async {
  final jsonStr = await LocalStorage.getEmployeeData();
  if (jsonStr != null && jsonStr.isNotEmpty) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return EmployeeModel.fromJson(map);
    } catch (_) {}
  }
  return null;
});

final loginPasswordVisibilityProvider = StateProvider.autoDispose<bool>((ref) => true);

final loginProvider = NotifierProvider<LoginNotifier, AsyncValue<void>>(() {
  return LoginNotifier();
});

class LoginNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }
  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final result = await ref.read(authRepositoryProvider).login(email, password);
      
      if (result.success && result.data != null) {
        if (result.data!.accessToken != null) {
          await LocalStorage.saveToken(result.data!.accessToken!);
        }
        if (result.data!.refreshToken != null) {
          await LocalStorage.saveRefreshToken(result.data!.refreshToken!);
        }
        if (result.data!.employee != null) {
          await LocalStorage.saveEmployeeData(jsonEncode(result.data!.employee!.toJson()));
        }
        ref.invalidate(currentUserProvider);
        state = const AsyncValue.data(null);
      } else {
        state = AsyncValue.error(result.message, StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (e) {
      // Ignore API errors during logout
    } finally {
      await LocalStorage.clear();
      state = const AsyncValue.data(null);
    }
  }
}
