import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../../../core/api/api_endpoints.dart';

class TaskTitleNotifier extends Notifier<String> {
  @override
  String build() => 'All Task';

  void setTitle(String newTitle) {
    state = newTitle;
  }
}

final taskTitleProvider = NotifierProvider<TaskTitleNotifier, String>(() {
  return TaskTitleNotifier();
});

class TaskScreenState {
  final List<dynamic> tasks;
  final int currentPage;
  final int totalPages;
  final bool isLoading;
  final bool isLoadMore;
  final String search;

  TaskScreenState({
    this.tasks = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.isLoading = false,
    this.isLoadMore = false,
    this.search = '',
  });

  TaskScreenState copyWith({
    List<dynamic>? tasks,
    int? currentPage,
    int? totalPages,
    bool? isLoading,
    bool? isLoadMore,
    String? search,
  }) {
    return TaskScreenState(
      tasks: tasks ?? this.tasks,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      isLoadMore: isLoadMore ?? this.isLoadMore,
      search: search ?? this.search,
    );
  }
}

class TaskScreenNotifier extends Notifier<TaskScreenState> {
  @override
  TaskScreenState build() {
    return TaskScreenState();
  }

  Future<void> fetchTasks({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isLoading: true, currentPage: 1, tasks: []);
    } else {
      if (state.isLoadMore || state.isLoading) return;
      if (state.currentPage >= state.totalPages) return;
      state = state.copyWith(isLoadMore: true);
    }

    try {
      final apiService = ref.read(apiServiceProvider);
      final pageToLoad = refresh ? 1 : state.currentPage + 1;

      final Map<String, dynamic> queryParameters = {
        'page': pageToLoad,
        'limit': 10,
        'search': state.search,
      };

      final currentTitle = ref.read(taskTitleProvider);
      String endpoint = ApiEndpoints.getTasks;
      if (currentTitle == 'Customer Task' || currentTitle == 'Customer Tasks') {
        endpoint = ApiEndpoints.customerTasks;
      } else if (currentTitle == 'Team Task' || currentTitle == 'Team Tasks') {
        endpoint = ApiEndpoints.teamTasks;
      }

      final response = await apiService.get(
        endpoint,
        queryParameters: queryParameters,
      );
      final dynamic responseData = response.data;
      Map<String, dynamic> responseMap;
      if (responseData is Map) {
        responseMap = Map<String, dynamic>.from(responseData);
      } else {
        responseMap = {};
      }

      final isSuccess = responseMap['success'] == true ||
          responseMap['statusCode'] == 200 ||
          response.statusCode == 200;

      if (isSuccess) {
        final rawData = responseMap['data'];
        List<dynamic> loadedTasks = [];
        int totalPages = 1;
        int currentPage = pageToLoad;

        if (rawData is List) {
          loadedTasks = rawData;
          totalPages = 1;
          currentPage = 1;
        } else if (rawData is Map) {
          loadedTasks = rawData['tasks'] is List ? rawData['tasks'] : [];
          totalPages = rawData['totalPages'] ?? 1;
          currentPage = rawData['currentPage'] ?? pageToLoad;
        }

        final newTasksList = refresh
            ? loadedTasks
            : [...state.tasks, ...loadedTasks];

        state = state.copyWith(
          tasks: newTasksList,
          currentPage: currentPage,
          totalPages: totalPages,
          isLoading: false,
          isLoadMore: false,
        );
      } else {
        state = state.copyWith(isLoading: false, isLoadMore: false);
      }
    } catch (e) {
      debugPrint("Error fetching tasks: $e");
      state = state.copyWith(isLoading: false, isLoadMore: false);
    }
  }

  void setSearch(String search) {
    state = state.copyWith(search: search);
    fetchTasks(refresh: true);
  }
}

final taskScreenProvider =
    NotifierProvider<TaskScreenNotifier, TaskScreenState>(() {
      return TaskScreenNotifier();
    });

class TaskDetailsState {
  final Map<String, dynamic>? taskData;
  final bool isLoading;
  final String? error;
  final String? currentSlug;

  TaskDetailsState({
    this.taskData,
    this.isLoading = false,
    this.error,
    this.currentSlug,
  });

  TaskDetailsState copyWith({
    Map<String, dynamic>? taskData,
    bool? isLoading,
    String? error,
    String? currentSlug,
  }) {
    return TaskDetailsState(
      taskData: taskData ?? this.taskData,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentSlug: currentSlug ?? this.currentSlug,
    );
  }
}

class TaskDetailsNotifier extends Notifier<TaskDetailsState> {
  @override
  TaskDetailsState build() {
    return TaskDetailsState();
  }

  Future<void> fetchTaskDetails(String slug) async {
    if (slug.isEmpty) return;
    state = state.copyWith(isLoading: true, error: null, currentSlug: slug);

    try {
      final apiService = ref.read(apiServiceProvider);
      final endpoint = ApiEndpoints.getTaskDetails(slug);

      final response = await apiService.get(endpoint);
      final responseData = response.data;
      Map<String, dynamic> responseMap = {};
      if (responseData is Map) {
        responseMap = Map<String, dynamic>.from(responseData);
      }

      final isSuccess = (responseMap['success'] == true ||
              responseMap['statusCode'] == 200 ||
              response.statusCode == 200) &&
          responseMap['data'] != null;

      if (isSuccess) {
        final data = Map<String, dynamic>.from(responseMap['data']);
        state = state.copyWith(
          taskData: data,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: responseMap['message']?.toString() ?? 'Failed to load task details',
        );
      }
    } catch (e) {
      debugPrint("Error fetching task details: $e");
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

final taskDetailsProvider =
    NotifierProvider<TaskDetailsNotifier, TaskDetailsState>(() {
  return TaskDetailsNotifier();
});



