import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_service.dart';
import '../api/api_endpoints.dart';
import '../models/permission_model.dart';

Map<String, dynamic>? _toMap(dynamic item) {
  if (item == null) return null;
  if (item is Map<String, dynamic>) return item;
  if (item is Map) {
    return item.map((k, v) => MapEntry(k.toString(), v));
  }
  return null;
}

final permissionProvider = FutureProvider<UserPermission>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  try {
    final response = await apiService.get(ApiEndpoints.getPermissions);
    final responseData = _toMap(response.data);
    if (responseData != null) {
      final isSuccess = responseData['success'] == true ||
          responseData['statusCode'] == 200 ||
          responseData['status'] == 'success';
      if (isSuccess && responseData['data'] != null) {
        final data = _toMap(responseData['data']);
        final permissionJson = _toMap(data?['permission']);
        if (permissionJson != null) {
          return UserPermission.fromJson(permissionJson);
        }
      }
    }
  } catch (e, stack) {
    print('Failed to fetch permissions: $e\n$stack');
  }
  // Return a completely restricted permission model if failed
  return UserPermission.fromJson(null);
});
