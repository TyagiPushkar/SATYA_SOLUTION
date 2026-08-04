import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_service.dart';
import '../model/employee_model.dart';

class EmployeeListState {
  final List<EmployeeModel> employees;
  final int currentPage;
  final int totalPages;
  final bool isLoading;
  final bool isLoadMore;
  final String search;

  EmployeeListState({
    this.employees = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.isLoading = false,
    this.isLoadMore = false,
    this.search = '',
  });

  EmployeeListState copyWith({
    List<EmployeeModel>? employees,
    int? currentPage,
    int? totalPages,
    bool? isLoading,
    bool? isLoadMore,
    String? search,
  }) {
    return EmployeeListState(
      employees: employees ?? this.employees,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      isLoadMore: isLoadMore ?? this.isLoadMore,
      search: search ?? this.search,
    );
  }
}
class EmployeeListNotifier extends Notifier<EmployeeListState> {
  @override
  EmployeeListState build() {
    return EmployeeListState();
  }
  Future<void> fetchEmployees({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isLoading: true, currentPage: 1, employees: []);
    } else {
      if (state.isLoadMore || state.isLoading) return;
      if (state.currentPage >= state.totalPages) return;
      state = state.copyWith(isLoadMore: true);
    }
    try {
      final apiService = ref.read(apiServiceProvider);
      final pageToLoad = refresh ? 1 : state.currentPage + 1;

      final Map<String, dynamic> queryParams = {
        'page': pageToLoad,
        'limit': 10,
      };
      if (state.search.isNotEmpty) {
        queryParams['search'] = state.search;
      }
      final response = await apiService.get(
        ApiEndpoints.getEmployees,
        queryParameters: queryParams,
      );
      final dynamic responseData = response.data;
      Map<String, dynamic> responseMap = {};
      if (responseData is Map) {
        responseMap = Map<String, dynamic>.from(responseData);
      }
      List<EmployeeModel> loadedList = [];
      int totalPages = 1;
      int currentPage = pageToLoad;
      if (responseMap['success'] == true || responseMap['data'] != null) {
        final data = responseMap['data'] ?? responseMap;
        final rawList = (data['employees'] ?? data['users'] ?? []) as List;
        loadedList = rawList
            .map((e) => EmployeeModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        totalPages = data['totalPages'] ?? 1;
        currentPage = data['currentPage'] ?? pageToLoad;
      }
      final newEmployees = refresh
          ? loadedList
          : [...state.employees, ...loadedList];
      state = state.copyWith(
        employees: newEmployees,
        currentPage: currentPage,
        totalPages: totalPages,
        isLoading: false,
        isLoadMore: false,
      );
    } catch (e) {
      debugPrint("Error fetching employees: $e");
      state = state.copyWith(isLoading: false, isLoadMore: false);
    }
  }
  void setSearch(String search) {
    state = state.copyWith(search: search);
    fetchEmployees(refresh: true);
  }
  Future<String?> addEmployee(Map<String, dynamic> data) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      List<int> parseArray(dynamic val) {
        if (val is List) {
          return val
              .map((e) => int.tryParse(e.toString()) ?? 1)
              .where((e) => e > 0)
              .toList();
        }
        if (val is String && val.isNotEmpty) {
          return val
              .split(',')
              .map((e) => int.tryParse(e.trim()) ?? 1)
              .where((e) => e > 0)
              .toList();
        }
        return [1];
      }
      final emailVal = data['email']?.toString().trim();
      final nameVal = data['name']?.toString().trim() ?? 'employee';
      final cleanName = nameVal
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toLowerCase();
      final validEmail =
          (emailVal != null && emailVal.contains('@') && emailVal.contains('.'))
          ? emailVal
          : '${cleanName.isNotEmpty ? cleanName : 'employee'}${DateTime.now().millisecondsSinceEpoch}@company.com';
      final payload = <String, dynamic>{
        "name": nameVal,
        "identity": data['identity']?.toString() ?? nameVal,
        "email": validEmail,
        "password": data['password']?.toString() ?? r'Pa$$w0rd!',
        "mobile": data['mobile']?.toString() ?? '9999999999',
        "address":
            data['address']?.toString() ??
            data['location']?.toString() ??
            'Lucknow',
        "branch_id": int.tryParse(data['branch_id']?.toString() ?? '1') ?? 1,
        "region_id": int.tryParse(data['region_id']?.toString() ?? '1') ?? 1,
        "state_id": int.tryParse(data['state_id']?.toString() ?? '1') ?? 1,
        "role_id": int.tryParse(data['role_id']?.toString() ?? '2') ?? 2,
        "type": int.tryParse(data['type']?.toString() ?? '2') ?? 2,
        "status": data['status']?.toString() ?? "Active",
        "business_unit": data['business_unit']?.toString() ?? "Core",
        "cost_center": data['cost_center']?.toString() ?? "CC-101",
        "department": data['department']?.toString() ?? "Engineering",
        "designations": data['designations']?.toString() ?? "Staff",
        "emp_type": data['emp_type']?.toString() ?? "Full Time",
        "license": data['license']?.toString() ?? "Full Access License",
        "date_of_birth":
            data['date_of_birth']?.toString() ??
            DateTime.now().toIso8601String(),
        "date_of_joining":
            data['date_of_joining']?.toString() ??
            DateTime.now().toIso8601String(),
        "location":
            data['location']?.toString() ??
            data['home_location']?.toString() ??
            "Noida, UP, India",
        "work_location":
            data['work_location']?.toString() ??
            data['home_location']?.toString() ??
            "Noida, UP, India",
        "last_location":
            data['last_location']?.toString() ??
            data['home_location']?.toString() ??
            "Noida, UP, India",
        "work_shift":
            data['work_shift']?.toString() ?? "General Shift (9 AM - 6 PM)",
        "app_version": "1.0.0",
        "desktop_version": "1.0.0",
        "last_Sync_mobile": DateTime.now().toIso8601String(),
        "last_Sync_desktop_at": DateTime.now().toIso8601String(),
        "last_desktop_started_at": DateTime.now().toIso8601String(),
        "entryAlerts": parseArray(
          data['entryAlerts'] ??
              data['entryAlertGeoFence'] ??
              data['entry_alert_geo_fence'] ??
              [2, 1, 3],
        ),
        "exitAlerts": parseArray(
          data['exitAlerts'] ??
              data['exitAlertGeoFence'] ??
              data['exit_alert_geo_fence'] ??
              [1, 2],
        ),
        "punchIn": parseArray(
          data['punchIn'] ??
              data['punchInGeoFence'] ??
              data['punch_in_geo_fence'] ??
              [2, 1],
        ),
        "punchOut": parseArray(
          data['punchOut'] ??
              data['punchOutGeoFence'] ??
              data['punch_out_geo_fence'] ??
              [1, 3, 2],
        ),
      };
      final response = await apiService.post(
        ApiEndpoints.createEmployee,
        data: payload,
      );
      debugPrint('Create Employee API Response: ${response.data}');
      await fetchEmployees(refresh: true);
      return null;
    } catch (e) {
      debugPrint('Error creating employee via API: $e');
      if (e is DioException && e.response?.data != null) {
        final resData = e.response!.data;
        if (resData is Map && resData['message'] != null) {
          return resData['message'].toString();
        }
      }
      return e.toString();
    }
  }
}
final employeeListProvider =
    NotifierProvider<EmployeeListNotifier, EmployeeListState>(() {
      return EmployeeListNotifier();
    });
