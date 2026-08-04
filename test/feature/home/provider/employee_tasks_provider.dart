import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../../../core/api/api_endpoints.dart';

class EmployeeTasksState {
  final List<dynamic> tasks;
  final bool isLoading;
  final String? error;

  EmployeeTasksState({
    this.tasks = const [],
    this.isLoading = false,
    this.error,
  });

  EmployeeTasksState copyWith({
    List<dynamic>? tasks,
    bool? isLoading,
    String? error,
  }) {
    return EmployeeTasksState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class EmployeeTasksNotifier extends Notifier<EmployeeTasksState> {
  @override
  EmployeeTasksState build() {
    Future.microtask(() => fetchEmployeeTasks());
    return EmployeeTasksState();
  }

  Future<void> fetchEmployeeTasks() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get(ApiEndpoints.employeeTasks);

      final dynamic responseData = response.data;
      Map<String, dynamic> responseMap = {};
      if (responseData is Map) {
        responseMap = Map<String, dynamic>.from(responseData);
      }

      final isSuccess = responseMap['success'] == true ||
          responseMap['statusCode'] == 200 ||
          response.statusCode == 200;

      if (isSuccess) {
        final rawData = responseMap['data'];
        List<dynamic> loadedTasks = [];

        if (rawData is List) {
          loadedTasks = rawData;
        } else if (rawData is Map) {
          loadedTasks = rawData['tasks'] is List ? rawData['tasks'] : [];
        }

        state = state.copyWith(
          tasks: loadedTasks,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: responseMap['message']?.toString() ?? 'Failed to fetch tasks',
        );
      }
    } catch (e) {
      debugPrint("Error fetching employee tasks: $e");
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

final employeeTasksProvider =
    NotifierProvider<EmployeeTasksNotifier, EmployeeTasksState>(() {
  return EmployeeTasksNotifier();
});
