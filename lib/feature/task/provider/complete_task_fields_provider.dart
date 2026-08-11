import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_service.dart';
import '../../../core/api/api_endpoints.dart';

class CompleteTaskFormFieldOption {
  final String label;
  final String value;

  CompleteTaskFormFieldOption({
    required this.label,
    required this.value,
  });

  factory CompleteTaskFormFieldOption.fromJson(Map<String, dynamic> json) {
    return CompleteTaskFormFieldOption(
      label: json['label']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
    );
  }
}

class CompleteTaskFormField {
  final String name;
  final String label;
  final String type;
  final String placeholder;
  final bool required;
  final String? defaultValue;
  final List<CompleteTaskFormFieldOption>? options;

  CompleteTaskFormField({
    required this.name,
    required this.label,
    required this.type,
    required this.placeholder,
    required this.required,
    this.defaultValue,
    this.options,
  });

  factory CompleteTaskFormField.fromJson(Map<String, dynamic> json) {
    final optionsList = json['options'] as List<dynamic>?;
    final nameStr = json['name']?.toString() ?? '';
    final labelStr = json['label']?.toString() ?? nameStr;
    final typeStr = json['type']?.toString() ?? 'text';
    final placeholderStr =
        json['placeholder']?.toString() ?? 'Enter $labelStr';

    return CompleteTaskFormField(
      name: nameStr,
      label: labelStr,
      type: typeStr,
      placeholder: placeholderStr,
      required: json['required'] == true,
      defaultValue: json['defaultValue']?.toString() ?? json['value']?.toString(),
      options: optionsList
          ?.map((e) =>
              CompleteTaskFormFieldOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

final completeTaskFieldsProvider =
    FutureProvider.autoDispose<List<CompleteTaskFormField>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final response = await apiService.get(
    ApiEndpoints.getCompleteBehalfFields,
    options: Options(
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  final responseData = response.data;
  if (responseData is Map &&
      responseData['success'] == true &&
      responseData['data'] is List) {
    final List<dynamic> fieldsData = responseData['data'];
    return fieldsData
        .map((e) => CompleteTaskFormField.fromJson(e as Map<String, dynamic>))
        .toList();
  } else {
    throw Exception(
      responseData is Map && responseData['message'] != null
          ? responseData['message']
          : 'Failed to fetch form fields',
    );
  }
});
