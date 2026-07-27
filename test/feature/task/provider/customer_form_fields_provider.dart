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
  final List<CustomerFormFieldOption>? options;
  CustomerFormField({
    required this.name,
    required this.label,
    required this.type,
    required this.placeholder,
    required this.required,
    this.options,
  });
  factory CustomerFormField.fromJson(Map<String, dynamic> json) {
    final optionsList = json['options'] as List<dynamic>?;
    final name = json['name'] as String? ?? '';
    final requiredFields = {
      'name',
      'email',
      'phone',
      'location',
      'district',
      'state',
      'sub_state',
      'branch_code',
      'branch',
      'center',
      'center_code',
      'loanType',
      'loanNo',
      'oldLoanNo',
      'oldCustomerNo',
      'loanDisbDate',
      'lastDueDate',
      'lastPaidTrxDate',
      'maturityDate',
      'closedDate',
    };
    final isRequired = requiredFields.contains(name) || (json['required'] as bool? ?? false);
    return CustomerFormField(
      name: name,
      label: json['label'] as String? ?? '',
      type: json['type'] as String? ?? '',
      placeholder: json['placeholder'] as String? ?? '',
      required: isRequired,
      options: optionsList?.map((e) => CustomerFormFieldOption.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
final customerFormFieldsProvider = FutureProvider.autoDispose<List<CustomerFormField>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final response = await apiService.get(ApiEndpoints.getCustomerForm);
  if (response.data['success'] == true) {
    final List<dynamic> fieldsData = response.data['data']['fields'] ?? [];
    return fieldsData.map((e) => CustomerFormField.fromJson(e as Map<String, dynamic>)).toList();
  } else {
    throw Exception(response.data['message'] ?? 'Failed to fetch customer form fields');
  }
});
