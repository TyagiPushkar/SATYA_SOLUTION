import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../../../core/api/api_endpoints.dart';

final customerProvider =
    NotifierProvider<CustomerNotifier, AsyncValue<Map<String, String>?>>(() {
      return CustomerNotifier();
    });

class CustomerNotifier extends Notifier<AsyncValue<Map<String, String>?>> {
  @override
  AsyncValue<Map<String, String>?> build() {
    return const AsyncValue.data(null);
  }

  Future<void> createCustomer(Map<String, dynamic> payload) async {
    state = const AsyncValue.loading();
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post(
        ApiEndpoints.createCustomer,
        data: payload,
      );
      final dynamic data = response.data['data'];
      if (data != null && data is Map) {
        final id = (data['id'] ?? data['_id'] ?? '').toString();
        final name = (data['name'] ?? '').toString();
        
        state = AsyncValue.data({'id': id, 'name': name});
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      String errorMessage = e.toString();
      if (e is DioException &&
          e.response?.data != null &&
          e.response?.data is Map) {


        final backendMsg = e.response?.data['message']?.toString();
        if (backendMsg != null && backendMsg.isNotEmpty) {
          errorMessage = backendMsg;
        }
      }
      state = AsyncValue.error(errorMessage, st);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}
