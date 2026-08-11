import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../../../core/api/api_endpoints.dart';

class TaskFormField {
  final String name;
  final String label;
  final String type;
  final String placeholder;
  final bool required;

  TaskFormField({
    required this.name,
    required this.label,
    required this.type,
    required this.placeholder,
    required this.required,
  });

  factory TaskFormField.fromJson(Map<String, dynamic> json) {
    return TaskFormField(
      name: json['name'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: json['type'] as String? ?? '',
      placeholder: json['placeholder'] as String? ?? '',
      required: json['required'] as bool? ?? false,
    );
  }
}

final taskFormFieldsProvider = FutureProvider.autoDispose<List<TaskFormField>>((
  ref,
) async {
  final apiService = ref.read(apiServiceProvider);
  final response = await apiService.get(ApiEndpoints.getCreateTaskForm);

  if (response.data['success'] == true) {
    final List<dynamic> fieldsData = response.data['data']['fields'] ?? [];
    return fieldsData
        .map((e) => TaskFormField.fromJson(e as Map<String, dynamic>))
        .toList();
  } else {
    throw Exception(
      response.data['message'] ?? 'Failed to fetch task form fields',
    );
  }
});
