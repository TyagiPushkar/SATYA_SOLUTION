import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../../../core/api/api_endpoints.dart';

class TaskTypeModel {
  final int id;
  final String name;

  TaskTypeModel({required this.id, required this.name});

  factory TaskTypeModel.fromJson(Map<String, dynamic> json) {
    return TaskTypeModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
    );
  }
}

final taskTypesProvider = FutureProvider.autoDispose<List<TaskTypeModel>>((
  ref,
) async {
  final apiService = ref.read(apiServiceProvider);
  final response = await apiService.get(ApiEndpoints.getTaskTypes);

  debugPrint("getTaskTypes raw data type: ${response.data.runtimeType}");
  debugPrint("getTaskTypes raw response: ${response.data}");

  final dynamic responseData = response.data;
  Map<String, dynamic> responseMap;
  if (responseData is String) {
    responseMap = jsonDecode(responseData) as Map<String, dynamic>;
  } else if (responseData is Map) {
    responseMap = Map<String, dynamic>.from(responseData);
  } else {
    responseMap = {};
  }

  final isSuccess =
      responseMap['success'] == true || responseMap['statusCode'] == 200;
  if (isSuccess) {
    final data = responseMap['data'];
    final List<dynamic> taskTypesData =
        (data is Map ? data['taskTypes'] : null) ?? [];
    debugPrint("Parsed task types count: ${taskTypesData.length}");
    return taskTypesData
        .map((e) => TaskTypeModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  } else {
    throw Exception(responseMap['message'] ?? 'Failed to fetch task types');
  }
});
