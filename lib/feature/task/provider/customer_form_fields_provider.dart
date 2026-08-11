import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../../../core/api/api_endpoints.dart';

class CustomerFormFieldOption {
  final String label;
  final String value;

  CustomerFormFieldOption({required this.label, required this.value});

  factory CustomerFormFieldOption.fromJson(Map<String, dynamic> json) {
    return CustomerFormFieldOption(
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );
  }
}

class CustomerFormField {
  final String name;
  final String label;
  final String type;
  final String placeholder;
  final bool required;
  final String section;
  final List<CustomerFormFieldOption>? options;

  CustomerFormField({
    required this.name,
    required this.label,
    required this.type,
    required this.placeholder,
    required this.required,
    required this.section,
    this.options,
  });

  factory CustomerFormField.fromJson(Map<String, dynamic> json) {
    final optionsList = json['options'] as List<dynamic>?;
    return CustomerFormField(
      name: json['name'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: json['type'] as String? ?? '',
      placeholder: json['placeholder'] as String? ?? '',
      required: json['required'] as bool? ?? false,
      section: json['section'] as String? ?? 'General Information',
      options: optionsList
          ?.map(
            (e) => CustomerFormFieldOption.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

final customerFormFieldsProvider =
    FutureProvider.autoDispose<List<CustomerFormField>>((ref) async {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get(ApiEndpoints.getCustomerForm);

      final data = response.data;
      List<dynamic> fieldsData = [];

      if (data is Map<String, dynamic>) {
        if (data['data'] != null && data['data']['fields'] != null) {
          fieldsData = data['data']['fields'] as List<dynamic>;
        } else if (data['fields'] != null) {
          fieldsData = data['fields'] as List<dynamic>;
        } else if (data['data'] is List) {
          fieldsData = data['data'] as List<dynamic>;
        }
      } else if (data is List) {
        fieldsData = data;
      }

      return fieldsData
          .map((e) => CustomerFormField.fromJson(e as Map<String, dynamic>))
          .toList();
    });

final groupedCustomerFormFieldsProvider =
    Provider.autoDispose<AsyncValue<Map<String, List<CustomerFormField>>>>((
      ref,
    ) {
      final fieldsAsync = ref.watch(customerFormFieldsProvider);
      return fieldsAsync.whenData((fields) {
        final Map<String, List<CustomerFormField>> grouped = {};

        for (final field in fields) {
          final sec = field.section.isNotEmpty
              ? field.section
              : 'General Information';
          grouped.putIfAbsent(sec, () => []);
          grouped[sec]!.add(field);
        }
        return grouped;
      });
    });
