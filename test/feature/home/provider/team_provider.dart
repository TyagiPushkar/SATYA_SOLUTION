import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_service.dart';
import '../model/team_employee_model.dart';
final teamProvider = FutureProvider.autoDispose<TeamEmployee>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  final response = await apiService.get(ApiEndpoints.myTeam);
  final data = response.data;
  if (data != null && data['data'] != null) {
    return TeamEmployee.fromJson(data['data']);
  } else {
    throw Exception('Invalid data format received from server');
  }
});
