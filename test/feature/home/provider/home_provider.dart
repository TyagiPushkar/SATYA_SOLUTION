import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_service.dart';
import '../model/home_dashboard_model.dart';
class HomeState {
  final bool isLoading;
  final String? error;
  final HomeDashboardModel? data;
  HomeState({this.isLoading = false, this.error, this.data});
  HomeState copyWith({
    bool? isLoading,
    String? error,
    HomeDashboardModel? data,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      data: data ?? this.data,
    );
  }
}
class HomeNotifier extends Notifier<HomeState> {
  @override
  HomeState build() {
    // Optionally fetch data on initialization
    Future.microtask(() => getHomeData());
    return HomeState();
  }
  Future<void> getHomeData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get(ApiEndpoints.homeStats);
      
      if (response.data != null && response.data['success'] == true) {
        final data = HomeDashboardModel.fromJson(response.data['data']);
        state = state.copyWith(isLoading: false, data: data);
      } else {
        state = state.copyWith(
          isLoading: false, 
          error: response.data['message'] ?? 'Failed to fetch data'
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
final homeProvider = NotifierProvider<HomeNotifier, HomeState>(() {
  return HomeNotifier();
});
