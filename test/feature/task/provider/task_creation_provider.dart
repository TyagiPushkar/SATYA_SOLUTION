import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../../../core/api/api_endpoints.dart';
final taskCreationProvider = NotifierProvider<TaskCreationNotifier, AsyncValue<void>>(() {
  return TaskCreationNotifier();
});
class TaskCreationNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }
  Future<void> createTask(Map<String, dynamic> payload) async {
    state = const AsyncValue.loading();
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.post(ApiEndpoints.createTask, data: payload);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
    }
  }
  void reset() {
    state = const AsyncValue.data(null);
  }
}
