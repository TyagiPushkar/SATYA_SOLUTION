import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_service.dart';
import '../api/api_endpoints.dart';
import '../models/permission_model.dart';

final permissionProvider = FutureProvider<UserPermission>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  try {
    final response = await apiService.get(ApiEndpoints.getPermissions);
    final responseData = response.data;
    if (responseData['success'] == true && responseData['data'] != null) {
      final data = responseData['data'] as Map<String, dynamic>;
      final permissionJson = data['permission'] as Map<String, dynamic>?;
      return UserPermission.fromJson(permissionJson);
    }
  } catch (e) {
    print('Failed to fetch permissions: $e');
  }
  // Return a completely restricted permission model if failed
  return UserPermission.fromJson(null);
});
