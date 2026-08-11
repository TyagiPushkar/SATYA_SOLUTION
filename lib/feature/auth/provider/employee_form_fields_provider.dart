import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../../../core/api/api_endpoints.dart';

class EmployeeFormOption {
  final String label;
  final String value;
  final String? code;
  final String? flag;

  EmployeeFormOption({
    required this.label,
    required this.value,
    this.code,
    this.flag,
  });

  factory EmployeeFormOption.fromJson(Map<String, dynamic> json) {
    return EmployeeFormOption(
      label: json['label']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      code: json['code']?.toString(),
      flag: json['flag']?.toString(),
    );
  }
}

class EmployeeFormField {
  final String name;
  final String label;
  final String type;
  final String placeholder;
  final bool required;
  final String section;
  final List<EmployeeFormOption> options;
  EmployeeFormField({
    required this.name,
    required this.label,
    required this.type,
    required this.placeholder,
    required this.required,
    required this.section,
    this.options = const [],
  });

  factory EmployeeFormField.fromJson(Map<String, dynamic> json) {
    List<EmployeeFormOption> opts = [];
    if (json['options'] != null && json['options'] is List) {
      opts = (json['options'] as List)
          .map((e) => EmployeeFormOption.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return EmployeeFormField(
      name: json['name']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      placeholder: json['placeholder']?.toString() ?? '',
      required: json['required'] as bool? ?? false,
      section: json['section']?.toString() ?? 'Create Employee',
      options: opts,
    );
  }
}

final employeeFormFieldsProvider =
    FutureProvider.autoDispose<List<EmployeeFormField>>((ref) async {
      try {
        final apiService = ref.read(apiServiceProvider);
        final response = await apiService.get(
          ApiEndpoints.getCreateEmployeeForm,
        );

        dynamic responseData = response.data;
        Map<String, dynamic> responseMap = {};
        if (responseData is Map) {
          responseMap = Map<String, dynamic>.from(responseData);
        }

        if (responseMap['success'] == true || responseMap['data'] != null) {
          final data = responseMap['data'] ?? responseMap;
          final List<dynamic> fieldsData = data['fields'] ?? [];
          return fieldsData
              .map(
                (e) => EmployeeFormField.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList();
        } else {
          return _getFallbackFields();
        }
      } catch (e) {
        return _getFallbackFields();
      }
    });

class CreateEmployeeFormNotifier extends Notifier<Map<String, dynamic>> {
  @override
  Map<String, dynamic> build() {
    return {};
  }

  void updateField(String key, dynamic value) {
    state = {...state, key: value};
  }

  void removeField(String key) {
    final newState = Map<String, dynamic>.from(state);
    newState.remove(key);
    state = newState;
  }

  void resetForm() {
    state = {};
  }
}

final createEmployeeFormProvider = NotifierProvider.autoDispose<
    CreateEmployeeFormNotifier, Map<String, dynamic>>(() {
  return CreateEmployeeFormNotifier();
});

List<EmployeeFormField> _getFallbackFields() {
  return [
    EmployeeFormField(
      name: 'name',
      label: 'Name',
      type: 'text',
      placeholder: 'Enter Name',
      required: true,
      section: 'Create Employee',
    ),
    EmployeeFormField(
      name: 'identity',
      label: 'Identifier',
      type: 'text',
      placeholder: 'Enter Identifier',
      required: true,
      section: 'Create Employee',
    ),
    EmployeeFormField(
      name: 'loginId',
      label: 'Login Id',
      type: 'text',
      placeholder: 'Enter Login Id',
      required: true,
      section: 'Create Employee',
    ),
    EmployeeFormField(
      name: 'password',
      label: 'Password',
      type: 'password',
      placeholder: 'Enter Password',
      required: false,
      section: 'Create Employee',
    ),
    EmployeeFormField(
      name: 'mobileCountryCode',
      label: 'Country Code',
      type: 'select',
      placeholder: 'Select Country Code',
      required: false,
      section: 'Create Employee',
      options: [
        EmployeeFormOption(label: 'IN +91', value: '+91', code: 'IN'),
        EmployeeFormOption(label: 'UM +1', value: '+1', code: 'UM'),
        EmployeeFormOption(label: 'GB +44', value: '+44', code: 'GB'),
      ],
    ),
    EmployeeFormField(
      name: 'mobile',
      label: 'Mobile Number',
      type: 'text',
      placeholder: 'Enter Mobile Number',
      required: true,
      section: 'Create Employee',
    ),
    EmployeeFormField(
      name: 'email',
      label: 'Email',
      type: 'email',
      placeholder: 'Enter Email',
      required: true,
      section: 'Create Employee',
    ),
  ];
}
