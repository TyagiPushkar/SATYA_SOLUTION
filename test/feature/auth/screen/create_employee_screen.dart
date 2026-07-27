import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text.dart';
import '../../../core/widgets/app_sizebox.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/location_picker_dialog.dart';
import '../provider/employee_form_fields_provider.dart';
import '../provider/employee_list_provider.dart';

class CreateEmployeeScreen extends ConsumerStatefulWidget {
  const CreateEmployeeScreen({super.key});

  @override
  ConsumerState<CreateEmployeeScreen> createState() =>
      _CreateEmployeeScreenState();
}

class _CreateEmployeeScreenState extends ConsumerState<CreateEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final fieldsAsync = ref.watch(employeeFormFieldsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(
        title: 'Create Employee',
        backgroundColor: AppColors.primary,
        textColor: AppColors.white,
      ),
      body: SafeArea(
        child: fieldsAsync.when(
          data: (fields) => _buildFormBody(fields),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: AppText(
                'Failed to load form fields: $err',
                color: Colors.red,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormBody(List<EmployeeFormField> fields) {
    // Group fields by section
    final Map<String, List<EmployeeFormField>> sections = {};
    for (var f in fields) {
      final sectionName = f.section.isNotEmpty
          ? f.section
          : 'Employee Information';
      sections.putIfAbsent(sectionName, () => []).add(f);
    }

    // Check if Advance Settings is enabled
    bool isAdvanceSettingsEnabled = false;
    _formData.forEach((key, val) {
      if (key.toLowerCase().contains('advance') && val == true) {
        isAdvanceSettingsEnabled = true;
      }
    });

    final alwaysVisibleSections = {
      'create employee',
      'tag details',
      'advance settings',
      'advance setting',
      'employee information',
      'override shift timing',
      'overtime shift timing',
      'overtime shift timings',
      'override shift timings',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var entry in sections.entries) ...[
              if (isAdvanceSettingsEnabled ||
                  alwaysVisibleSections.contains(
                    entry.key.toLowerCase().trim(),
                  )) ...[
                _buildSectionHeader(entry.key),
                const AppSizeBox.h(14),
                _buildSectionFields(entry.value),
                const AppSizeBox.h(20),
              ],
            ],
            const AppSizeBox.h(16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submitForm,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const AppText(
                        'Save Employee',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
              ),
            ),
            const AppSizeBox.h(24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const AppSizeBox.w(8),
            AppText(
              title,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ],
        ),
        const AppSizeBox.h(8),
        Divider(color: Colors.grey.shade200, height: 1, thickness: 1),
      ],
    );
  }

  Widget _buildSectionFields(List<EmployeeFormField> fields) {
    EmployeeFormField? countryCodeField;
    try {
      countryCodeField = fields.firstWhere(
        (f) => f.name == 'mobileCountryCode',
      );
    } catch (_) {
      try {
        final allFields = ref.read(employeeFormFieldsProvider).value;
        if (allFields != null) {
          countryCodeField = allFields.firstWhere(
            (f) => f.name == 'mobileCountryCode',
          );
        }
      } catch (_) {}
    }

    bool hasPasswordField = fields.any(
      (f) =>
          f.name.toLowerCase() == 'password' ||
          f.label.toLowerCase() == 'password' ||
          f.type == 'password',
    );
    bool hasPasswordSwitchField = fields.any(
      (f) =>
          (f.name.toLowerCase().contains('password') ||
              f.label.toLowerCase().contains('password')) &&
          (f.name.toLowerCase().contains('switch') ||
              f.label.toLowerCase().contains('switch') ||
              f.type == 'switch'),
    );

    List<EmployeeFormField> fieldsToRender = List.from(fields);
    if (hasPasswordSwitchField && !hasPasswordField) {
      fieldsToRender.add(
        EmployeeFormField(
          name: 'password',
          label: 'Password',
          type: 'password',
          placeholder: 'Enter Password',
          required: false,
          section: fields.isNotEmpty ? fields.first.section : 'Create Employee',
        ),
      );
    }

    List<Widget> fieldWidgets = [];
    for (int i = 0; i < fieldsToRender.length; i++) {
      final field = fieldsToRender[i];
      if (field.name == 'mobileCountryCode') {
        continue;
      }
      if ((field.name == 'mobile' ||
              field.name == 'mobileNumber' ||
              field.name == 'phone') &&
          countryCodeField != null) {
        fieldWidgets.add(_buildCombinedMobileField(countryCodeField, field));
      } else {
        fieldWidgets.add(_buildFormField(field));
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 550;
        if (isWideScreen) {
          List<Widget> rows = [];
          for (int i = 0; i < fieldWidgets.length; i += 2) {
            final w1 = fieldWidgets[i];
            final w2 = (i + 1 < fieldWidgets.length)
                ? fieldWidgets[i + 1]
                : null;

            rows.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: w1),
                    const AppSizeBox.w(16),
                    Expanded(child: w2 ?? const SizedBox.shrink()),
                  ],
                ),
              ),
            );
          }
          return Column(children: rows);
        } else {
          return Column(
            children: fieldWidgets
                .map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: w,
                  ),
                )
                .toList(),
          );
        }
      },
    );
  }

  Widget _buildCombinedMobileField(
    EmployeeFormField countryCodeField,
    EmployeeFormField mobileField,
  ) {
    final initialCode = countryCodeField.options.isNotEmpty
        ? (countryCodeField.options
              .firstWhere(
                (o) => o.value == '+91' || o.code == 'IN',
                orElse: () => countryCodeField.options.first,
              )
              .value)
        : '+91';

    if (!_formData.containsKey(countryCodeField.name)) {
      _formData[countryCodeField.name] = initialCode;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${mobileField.label}${mobileField.required ? ' *' : ''}',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const AppSizeBox.h(6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _formData[countryCodeField.name] as String?,
                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                    items: countryCodeField.options.map((opt) {
                      return DropdownMenuItem<String>(
                        value: opt.value,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (opt.flag != null && opt.flag!.isNotEmpty) ...[
                              Image.network(
                                opt.flag!,
                                width: 22,
                                height: 16,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, st) => Text(
                                  opt.code ?? opt.value,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const AppSizeBox.w(6),
                            ] else if (opt.code != null) ...[
                              Text(
                                opt.code!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const AppSizeBox.w(4),
                            ],
                            Text(
                              opt.value,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _formData[countryCodeField.name] = val;
                      });
                    },
                  ),
                ),
              ),
              const AppSizeBox.w(8),
              Expanded(
                child: TextFormField(
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: mobileField.placeholder.isNotEmpty
                        ? mobileField.placeholder
                        : 'Enter mobile number',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSaved: (val) {
                    _formData[mobileField.name] = val?.trim();
                  },
                  validator: (val) {
                    if (mobileField.required &&
                        (val == null || val.trim().isEmpty)) {
                      return 'Please enter ${mobileField.label}';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage(String fieldName) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          setState(() {
            _formData[fieldName] = path;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Widget _buildFormField(EmployeeFormField field) {
    final fieldNameLower = field.name.toLowerCase();
    final fieldLabelLower = field.label.toLowerCase();

    final isPasswordSwitch =
        (fieldNameLower.contains('password') &&
            (fieldNameLower.contains('switch') ||
                fieldNameLower.contains('toggle') ||
                fieldNameLower.contains('enable'))) ||
        (fieldLabelLower.contains('password') &&
            (fieldLabelLower.contains('switch') ||
                fieldLabelLower.contains('toggle') ||
                fieldLabelLower.contains('enable')));

    if (isPasswordSwitch) {
      return const SizedBox.shrink();
    }

    final isRegionOrBranch =
        fieldNameLower.contains('region') ||
        fieldLabelLower.contains('region') ||
        fieldNameLower.contains('branch') ||
        fieldLabelLower.contains('branch');

    if (isRegionOrBranch) {
      dynamic stateVal;
      _formData.forEach((key, val) {
        if (key.toLowerCase().contains('state')) {
          stateVal = val;
        }
      });

      if (stateVal == null ||
          stateVal.toString().trim().isEmpty ||
          stateVal.toString() == 'null' ||
          stateVal.toString().toLowerCase().contains('select')) {
        return const SizedBox.shrink();
      }
    }

    final isTrackerWebsite =
        (fieldNameLower.contains('tracker') &&
            fieldNameLower.contains('website')) ||
        (fieldLabelLower.contains('tracker') &&
            fieldLabelLower.contains('website'));

    if (isTrackerWebsite) {
      bool isTrackerEnabled = false;
      _formData.forEach((key, val) {
        final keyLower = key.toLowerCase();
        if (keyLower.contains('tracker') &&
            !keyLower.contains('website') &&
            val == true) {
          isTrackerEnabled = true;
        }
      });

      if (!isTrackerEnabled) {
        return const SizedBox.shrink();
      }
    }

    final isImageUploadField =
        field.type == 'file' ||
        field.type == 'image' ||
        field.name.toLowerCase().contains('thumbnail') ||
        field.name.toLowerCase().contains('image') ||
        field.name.toLowerCase().contains('photo') ||
        field.name.toLowerCase().contains('avatar');

    if (isImageUploadField) {
      final filePath = _formData[field.name] as String?;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${field.label}${field.required ? ' *' : ''}',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const AppSizeBox.h(6),
          InkWell(
            onTap: () => _pickImage(field.name),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: filePath != null
                      ? AppColors.primary
                      : Colors.grey.shade300,
                ),
              ),
              child: filePath != null && filePath.isNotEmpty
                  ? Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(
                            File(filePath),
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, st) => Container(
                              width: 44,
                              height: 44,
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.image,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        const AppSizeBox.w(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                filePath.split('/').last.split('\\').last,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const AppSizeBox.h(2),
                              Text(
                                'Tap to change image',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _formData.remove(field.name);
                            });
                          },
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 24,
                          color: Colors.grey.shade600,
                        ),
                        const AppSizeBox.w(8),
                        Text(
                          'Click to upload ${field.label}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      );
    }

    final isSwitchType =
        field.type == 'switch' ||
        field.type == 'checkbox' ||
        field.type == 'toggle' ||
        field.name.toLowerCase().contains('switch');

    if (isSwitchType) {
      final currentVal = _formData[field.name] as bool? ?? false;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                '${field.label}${field.required ? ' *' : ''}',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const AppSizeBox.w(12),
            Switch(
              value: currentVal,
              activeTrackColor: AppColors.primary,
              onChanged: (val) {
                _updateFieldValue(field.name, val);
              },
            ),
          ],
        ),
      );
    }

    final isMultiSelectField =
        field.type == 'multiselect' ||
        field.type == 'multi-select' ||
        field.type == 'array' ||
        field.section.toLowerCase().contains('geo fence') ||
        field.section.toLowerCase().contains('geofence') ||
        fieldNameLower.contains('geofence') ||
        fieldLabelLower.contains('geofence') ||
        fieldNameLower.contains('fence') ||
        fieldLabelLower.contains('fence');

    if (isMultiSelectField ||
        (field.type == 'select' &&
            (fieldNameLower.contains('fence') ||
                fieldLabelLower.contains('fence')))) {
      List<String> currentSelected = [];
      final rawVal = _formData[field.name];
      if (rawVal is List) {
        currentSelected = List<String>.from(rawVal);
      } else if (rawVal is String && rawVal.isNotEmpty) {
        currentSelected = rawVal
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }

      return MultiSelectFormField(
        field: field,
        selectedValues: currentSelected,
        onChanged: (newList) {
          _updateFieldValue(field.name, newList);
        },
      );
    }

    final isColorField =
        field.type == 'color' ||
        fieldNameLower.contains('color') ||
        fieldLabelLower.contains('color') ||
        fieldNameLower.contains('colour') ||
        fieldLabelLower.contains('colour') ||
        fieldNameLower.contains('hex') ||
        fieldLabelLower.contains('hex') ||
        fieldNameLower == 'label' ||
        fieldLabelLower == 'label' ||
        (field.section.toLowerCase().contains('tag') &&
            (fieldNameLower.contains('label') ||
                fieldLabelLower.contains('label')));

    if (isColorField) {
      final initialColorHex = _formData[field.name] as String? ?? '#4547B5';
      if (!_formData.containsKey(field.name)) {
        _formData[field.name] = initialColorHex;
      }

      return ColorPickerFormField(
        field: field,
        selectedColorHex: _formData[field.name] as String? ?? '#4547B5',
        onChanged: (hex) {
          _updateFieldValue(field.name, hex);
        },
      );
    }

    final isDateField =
        field.type == 'date' ||
        fieldNameLower.contains('date') ||
        fieldLabelLower.contains('date') ||
        fieldNameLower.contains('dob') ||
        fieldLabelLower.contains('dob') ||
        fieldNameLower.contains('birth') ||
        fieldLabelLower.contains('birth') ||
        fieldNameLower.contains('joining') ||
        fieldLabelLower.contains('joining');

    if (isDateField) {
      final dateStr = _formData[field.name] as String? ?? '';
      final dateController = TextEditingController(text: dateStr);

      Future<void> selectDate() async {
        DateTime initial = DateTime.now();
        if (dateStr.isNotEmpty) {
          try {
            initial = DateTime.parse(dateStr);
          } catch (_) {}
        }
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(1950),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  onSurface: Colors.black87,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          final formatted =
              "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
          _updateFieldValue(field.name, formatted);
        }
      }

      return InkWell(
        onTap: selectDate,
        borderRadius: BorderRadius.circular(6),
        child: IgnorePointer(
          child: TextFormField(
            controller: dateController,
            decoration: InputDecoration(
              labelText: '${field.label}${field.required ? ' *' : ''}',
              labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              hintText: field.placeholder.isNotEmpty
                  ? field.placeholder
                  : 'YYYY-MM-DD',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              suffixIcon: const Icon(
                Icons.calendar_today_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
            validator: (val) {
              if (field.required && dateStr.isEmpty) {
                return 'Please select ${field.label}';
              }
              return null;
            },
          ),
        ),
      );
    }

    final isTimeField =
        field.type == 'time' ||
        fieldNameLower.contains('time') ||
        fieldLabelLower.contains('time') ||
        fieldNameLower.contains('shift') ||
        fieldLabelLower.contains('shift') ||
        fieldNameLower.contains('punch') ||
        fieldLabelLower.contains('punch');

    if (isTimeField) {
      final timeStr = _formData[field.name] as String? ?? '';
      final timeController = TextEditingController(text: timeStr);

      Future<void> selectTime() async {
        final result = await showDialog<String>(
          context: context,
          builder: (ctx) => CustomTimePickerDialog(initialTime: timeStr),
        );
        if (result != null) {
          _updateFieldValue(field.name, result);
        }
      }

      return InkWell(
        onTap: selectTime,
        borderRadius: BorderRadius.circular(6),
        child: IgnorePointer(
          child: TextFormField(
            controller: timeController,
            decoration: InputDecoration(
              labelText: '${field.label}${field.required ? ' *' : ''}',
              labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              hintText: field.placeholder.isNotEmpty
                  ? field.placeholder
                  : 'Please select time',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              suffixIcon: Icon(
                Icons.access_time,
                color: Colors.grey.shade400,
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
            validator: (val) {
              if (field.required && timeStr.isEmpty) {
                return 'Please select ${field.label}';
              }
              return null;
            },
          ),
        ),
      );
    }

    if (field.type == 'select') {
      final isStateField =
          field.name.toLowerCase().contains('state') ||
          field.label.toLowerCase().contains('state');

      final initialVal = field.options.isNotEmpty
          ? (isStateField ? null : field.options.first.value)
          : null;

      if (!_formData.containsKey(field.name) && initialVal != null) {
        _formData[field.name] = initialVal;
      }

      return DropdownButtonFormField<String>(
        initialValue: _formData[field.name] as String?,
        decoration: InputDecoration(
          labelText: '${field.label}${field.required ? ' *' : ''}',
          labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          filled: true,
          fillColor: const Color(0xFFFAFAFA),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
        items: field.options.map((opt) {
          return DropdownMenuItem<String>(
            value: opt.value,
            child: Text(opt.label, style: const TextStyle(fontSize: 14)),
          );
        }).toList(),
        onChanged: (val) {
          setState(() {
            _formData[field.name] = val;
          });
        },
        validator: (val) {
          if (field.required && (val == null || val.isEmpty)) {
            return 'Please select ${field.label}';
          }
          return null;
        },
      );
    }

    TextInputType keyboardType = TextInputType.text;
    bool isPassword = false;
    if (field.type == 'email') {
      keyboardType = TextInputType.emailAddress;
    } else if (field.type == 'number' || field.type == 'tel') {
      keyboardType = TextInputType.phone;
    } else if (field.type == 'password' ||
        fieldNameLower == 'password' ||
        fieldLabelLower == 'password') {
      isPassword = true;
    }

    final isHomeLocation =
        fieldNameLower.contains('home_location') ||
        fieldNameLower.contains('homelocation') ||
        fieldLabelLower.contains('home location');

    TextEditingController? controller;
    if (isHomeLocation) {
      controller = TextEditingController(
        text: _formData[field.name] as String? ?? '',
      );
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    }

    if (isPassword) {
      bool obscureText = true;
      return StatefulBuilder(
        builder: (context, setStateSB) {
          return TextFormField(
            controller: controller,
            initialValue: controller == null
                ? (_formData[field.name] as String?)
                : null,
            obscureText: obscureText,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              labelText: '${field.label}${field.required ? ' *' : ''}',
              labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              hintText: field.placeholder.isNotEmpty ? field.placeholder : null,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                onPressed: () {
                  setStateSB(() {
                    obscureText = !obscureText;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
            onSaved: (val) {
              _formData[field.name] = val?.trim();
            },
            validator: (val) {
              if (field.required && (val == null || val.trim().isEmpty)) {
                return 'Please enter ${field.label}';
              }
              return null;
            },
          );
        },
      );
    }

    return TextFormField(
      controller: controller,
      initialValue: controller == null
          ? (_formData[field.name] as String?)
          : null,
      obscureText: false,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: '${field.label}${field.required ? ' *' : ''}',
        labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        hintText: field.placeholder.isNotEmpty ? field.placeholder : null,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        suffixIcon: isHomeLocation
            ? IconButton(
                icon: Icon(
                  (_formData[field.name] as String? ?? '').isNotEmpty
                      ? Icons.location_on
                      : Icons.add,
                  color: (_formData[field.name] as String? ?? '').isNotEmpty
                      ? const Color(0xFF0E73D3)
                      : Colors.black54,
                  size: 24,
                ),
                onPressed: () async {
                  dynamic stateVal;
                  _formData.forEach((key, val) {
                    if (key.toLowerCase().contains('state') &&
                        val != null &&
                        val.toString().trim().isNotEmpty) {
                      stateVal = val;
                    }
                  });
                  final result = await showDialog<String>(
                    context: context,
                    builder: (ctx) => LocationPickerDialog(
                      initialValue: _formData[field.name] as String?,
                      selectedState: stateVal?.toString(),
                    ),
                  );
                  if (result != null) {
                    setState(() {
                      _formData[field.name] = result;
                    });
                  }
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      onSaved: (val) {
        _formData[field.name] = val?.trim();
      },
      validator: (val) {
        if (field.required && (val == null || val.trim().isEmpty)) {
          return 'Please enter ${field.label}';
        }
        return null;
      },
    );
  }

  void _updateFieldValue(String key, dynamic val) {
    setState(() {
      _formData[key] = val;
    });
    ref.read(createEmployeeFormProvider.notifier).updateField(key, val);
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isSubmitting = true);

      final riverpodFormData = ref.read(createEmployeeFormProvider);
      final finalPayload = {..._formData, ...riverpodFormData};

      final errorMsg = await ref
          .read(employeeListProvider.notifier)
          .addEmployee(finalPayload);

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (errorMsg == null) {
          ref.read(createEmployeeFormProvider.notifier).resetForm();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Employee Created Successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

class MultiSelectFormField extends StatefulWidget {
  final EmployeeFormField field;
  final List<String> selectedValues;
  final ValueChanged<List<String>> onChanged;

  const MultiSelectFormField({
    super.key,
    required this.field,
    required this.selectedValues,
    required this.onChanged,
  });

  @override
  State<MultiSelectFormField> createState() => _MultiSelectFormFieldState();
}

class _MultiSelectFormFieldState extends State<MultiSelectFormField> {
  void _openMultiSelectSheet() {
    List<EmployeeFormOption> options = widget.field.options;
    if (options.isEmpty) {
      options = [
        EmployeeFormOption(label: 'Vedanta Tech1', value: 'Vedanta Tech1'),
        EmployeeFormOption(label: 'Vedanta Tech2', value: 'Vedanta Tech2'),
        EmployeeFormOption(label: 'Vedanta Tech3', value: 'Vedanta Tech3'),
        EmployeeFormOption(label: 'Vedanta Tech4', value: 'Vedanta Tech4'),
        EmployeeFormOption(label: 'Vedanta Tech5', value: 'Vedanta Tech5'),
      ];
    }

    List<String> tempSelected = List.from(widget.selectedValues);
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          backgroundColor: Colors.white,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final filteredOptions = options.where((opt) {
                return opt.label.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ) ||
                    opt.value.toLowerCase().contains(searchQuery.toLowerCase());
              }).toList();

              return Container(
                height: MediaQuery.of(context).size.height * 0.65,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select ${widget.field.label}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search ${widget.field.label}...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFFAFAFA),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        onChanged: (val) {
                          setSheetState(() {
                            searchQuery = val;
                          });
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              tempSelected = options.map((e) => e.value).toList();
                            });
                          },
                          child: const Text('Select All'),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              tempSelected.clear();
                            });
                          },
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filteredOptions.length,
                        separatorBuilder: (ctx, i) =>
                            Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (ctx, index) {
                          final opt = filteredOptions[index];
                          final isChecked = tempSelected.contains(opt.value);
                          return CheckboxListTile(
                            dense: true,
                            activeColor: AppColors.primary,
                            title: Text(
                              opt.label,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            value: isChecked,
                            onChanged: (bool? val) {
                              setSheetState(() {
                                if (val == true) {
                                  if (!tempSelected.contains(opt.value)) {
                                    tempSelected.add(opt.value);
                                  }
                                } else {
                                  tempSelected.remove(opt.value);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          widget.onChanged(tempSelected);
                          Navigator.pop(context);
                        },
                        child: Text(
                          tempSelected.isEmpty
                              ? 'Confirm'
                              : 'Select (${tempSelected.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<EmployeeFormOption> options = widget.field.options;
    if (options.isEmpty) {
      options = [
        EmployeeFormOption(label: 'Vedanta Tech1', value: 'Vedanta Tech1'),
        EmployeeFormOption(label: 'Vedanta Tech2', value: 'Vedanta Tech2'),
        EmployeeFormOption(label: 'Vedanta Tech3', value: 'Vedanta Tech3'),
        EmployeeFormOption(label: 'Vedanta Tech4', value: 'Vedanta Tech4'),
        EmployeeFormOption(label: 'Vedanta Tech5', value: 'Vedanta Tech5'),
      ];
    }

    String getLabelForValue(String val) {
      for (final opt in options) {
        if (opt.value.toString() == val.toString()) {
          return opt.label;
        }
      }
      return val;
    }

    return InkWell(
      onTap: _openMultiSelectSheet,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.field.label}${widget.field.required ? ' *' : ''}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  if (widget.selectedValues.isEmpty)
                    Text(
                      widget.field.placeholder.isNotEmpty
                          ? widget.field.placeholder
                          : 'Select ${widget.field.label}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: widget.selectedValues.map((val) {
                        final labelText = getLabelForValue(val);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                labelText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  final newList = List<String>.from(
                                    widget.selectedValues,
                                  )..remove(val);
                                  widget.onChanged(newList);
                                },
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class ColorPickerFormField extends StatefulWidget {
  final EmployeeFormField field;
  final String selectedColorHex;
  final ValueChanged<String> onChanged;

  const ColorPickerFormField({
    super.key,
    required this.field,
    required this.selectedColorHex,
    required this.onChanged,
  });

  @override
  State<ColorPickerFormField> createState() => _ColorPickerFormFieldState();
}

class _ColorPickerFormFieldState extends State<ColorPickerFormField> {
  bool _isExpanded = false;
  late HSVColor _currentHsv;
  late TextEditingController _hexController;
  late TextEditingController _rController;
  late TextEditingController _gController;
  late TextEditingController _bController;

  static Color _hexToColor(String hexString) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFF4547B5);
    }
  }

  static String _colorToHex(Color color) {
    return '#${(color.a * 255).round().toRadixString(16).padLeft(2, '0')}${(color.r * 255).round().toRadixString(16).padLeft(2, '0')}${(color.g * 255).round().toRadixString(16).padLeft(2, '0')}${(color.b * 255).round().toRadixString(16).padLeft(2, '0')}'
        .substring(2)
        .toUpperCase();
  }

  final List<String> _presetColors = [
    '#4547B5',
    '#5C6BC0',
    '#EF5350',
    '#26A69A',
    '#FFA726',
    '#42A5F5',
    '#EC407A',
    '#26C6DA',
    '#AB47BC',
  ];

  @override
  void initState() {
    super.initState();
    final color = _hexToColor(widget.selectedColorHex);
    _currentHsv = HSVColor.fromColor(color);
    _hexController = TextEditingController(text: _colorToHex(color));
    _rController = TextEditingController(
      text: (color.r * 255).round().toString(),
    );
    _gController = TextEditingController(
      text: (color.g * 255).round().toString(),
    );
    _bController = TextEditingController(
      text: (color.b * 255).round().toString(),
    );
  }

  @override
  void didUpdateWidget(covariant ColorPickerFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedColorHex != widget.selectedColorHex) {
      final color = _hexToColor(widget.selectedColorHex);
      _currentHsv = HSVColor.fromColor(color);
      _updateControllers(color);
    }
  }

  void _updateControllers(Color color) {
    _hexController.text = _colorToHex(color);
    _rController.text = (color.r * 255).round().toString();
    _gController.text = (color.g * 255).round().toString();
    _bController.text = (color.b * 255).round().toString();
  }

  void _updateFromHsv(HSVColor hsv) {
    setState(() {
      _currentHsv = hsv;
      final color = hsv.toColor();
      _updateControllers(color);
    });
    widget.onChanged(_colorToHex(hsv.toColor()));
  }

  void _updateFromRgb() {
    final r = (int.tryParse(_rController.text) ?? 0).clamp(0, 255);
    final g = (int.tryParse(_gController.text) ?? 0).clamp(0, 255);
    final b = (int.tryParse(_bController.text) ?? 0).clamp(0, 255);
    final color = Color.fromRGBO(r, g, b, 1.0);
    setState(() {
      _currentHsv = HSVColor.fromColor(color);
      _hexController.text = _colorToHex(color);
    });
    widget.onChanged(_colorToHex(color));
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _currentHsv.toColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          '${widget.field.label}${widget.field.required ? ' *' : ''}',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),

        // Main Bar Box: [ Color Preview & Hex ] + Preset Color Dots
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isExpanded ? AppColors.primary : Colors.grey.shade300,
              width: _isExpanded ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Left button: Color Box + Hex text
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: activeColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _colorToHex(activeColor),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Right: Preset Color Dots Row
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _presetColors.map((hexStr) {
                      final c = _hexToColor(hexStr);
                      final isSelected =
                          _colorToHex(activeColor).toUpperCase() ==
                          hexStr.toUpperCase();
                      return GestureDetector(
                        onTap: () {
                          final newC = _hexToColor(hexStr);
                          _updateFromHsv(HSVColor.fromColor(newC));
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: Colors.black87,
                                      width: 2.5,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Expandable Popover Color Picker Card
        if (_isExpanded) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                // 1. 2D Color Spectrum Box (Saturation-Value Picker)
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final width = constraints.maxWidth;
                    const height = 160.0;

                    final sat = _currentHsv.saturation;
                    final val = _currentHsv.value;
                    final dx = sat * width;
                    final dy = (1.0 - val) * height;

                    void handlePan(Offset localPos) {
                      final clampX = localPos.dx.clamp(0.0, width);
                      final clampY = localPos.dy.clamp(0.0, height);
                      final newSat = clampX / width;
                      final newVal = 1.0 - (clampY / height);
                      _updateFromHsv(
                        HSVColor.fromAHSV(1.0, _currentHsv.hue, newSat, newVal),
                      );
                    }

                    return GestureDetector(
                      onPanDown: (details) => handlePan(details.localPosition),
                      onPanUpdate: (details) =>
                          handlePan(details.localPosition),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: width,
                          height: height,
                          child: Stack(
                            children: [
                              // Hue Background
                              Container(
                                color: HSVColor.fromAHSV(
                                  1.0,
                                  _currentHsv.hue,
                                  1.0,
                                  1.0,
                                ).toColor(),
                              ),
                              // Saturation Gradient (White to Transparent)
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.white, Colors.transparent],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                ),
                              ),
                              // Value Gradient (Transparent to Black)
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.transparent, Colors.black],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                              // Draggable Selection Circle ⭕
                              Positioned(
                                left: dx - 10,
                                top: dy - 10,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black45,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // 2. Eyedropper + Color Circle Preview + Rainbow Hue Slider
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Icon(
                        Icons.colorize,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFF0000),
                              Color(0xFFFFFF00),
                              Color(0xFF00FF00),
                              Color(0xFF00FFFF),
                              Color(0xFF0000FF),
                              Color(0xFFFF00FF),
                              Color(0xFFFF0000),
                            ],
                          ),
                        ),
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 14,
                            activeTrackColor: Colors.transparent,
                            inactiveTrackColor: Colors.transparent,
                            thumbColor: Colors.white,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 9,
                              elevation: 3,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14,
                            ),
                          ),
                          child: Slider(
                            value: _currentHsv.hue,
                            min: 0.0,
                            max: 360.0,
                            onChanged: (newHue) {
                              _updateFromHsv(
                                HSVColor.fromAHSV(
                                  1.0,
                                  newHue,
                                  _currentHsv.saturation,
                                  _currentHsv.value,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 3. RGB Numeric Input Text Fields [ 69 ] [ 71 ] [ 181 ]
                Row(
                  children: [
                    Expanded(child: _buildRgbInputBox('R', _rController)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildRgbInputBox('G', _gController)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildRgbInputBox('B', _bController)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRgbInputBox(String label, TextEditingController ctrl) {
    return Column(
      children: [
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (val) => _updateFromRgb(),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class CustomTimePickerDialog extends StatefulWidget {
  final String? initialTime;
  const CustomTimePickerDialog({super.key, this.initialTime});

  @override
  State<CustomTimePickerDialog> createState() => _CustomTimePickerDialogState();
}

class _CustomTimePickerDialogState extends State<CustomTimePickerDialog> {
  late int _selectedHour;
  late int _selectedMinute;
  late String _selectedPeriod;

  final List<int> _hours = List.generate(12, (i) => i == 0 ? 12 : i);
  final List<int> _minutes = List.generate(60, (i) => i);
  final List<String> _periods = ['AM', 'PM'];

  @override
  void initState() {
    super.initState();
    _parseInitialTime();
  }

  void _parseInitialTime() {
    final now = DateTime.now();
    int h = now.hour;
    int m = now.minute;
    String p = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;

    if (widget.initialTime != null && widget.initialTime!.isNotEmpty) {
      try {
        final str = widget.initialTime!.trim().toLowerCase();
        final isPm = str.contains('pm');
        p = isPm ? 'PM' : 'AM';
        final clean = str.replaceAll('am', '').replaceAll('pm', '').trim();
        final parts = clean.split(':');
        if (parts.length >= 2) {
          final parsedH = int.tryParse(parts[0]);
          final parsedM = int.tryParse(parts[1]);
          if (parsedH != null) h = parsedH;
          if (parsedM != null) m = parsedM;
        }
      } catch (_) {}
    }

    _selectedHour = h;
    _selectedMinute = m;
    _selectedPeriod = p;
  }

  void _setNow() {
    final now = DateTime.now();
    int h = now.hour;
    int m = now.minute;
    String p = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;
    setState(() {
      _selectedHour = h;
      _selectedMinute = m;
      _selectedPeriod = p;
    });
  }

  String _formatResult() {
    final hStr = _selectedHour.toString().padLeft(2, '0');
    final mStr = _selectedMinute.toString().padLeft(2, '0');
    final pStr = _selectedPeriod.toLowerCase();
    return '$hStr:$mStr $pStr';
  }

  @override
  Widget build(BuildContext context) {
    final hourStr = _selectedHour.toString().padLeft(2, '0');
    final minStr = _selectedMinute.toString().padLeft(2, '0');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      backgroundColor: Colors.white,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        hourStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        minStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        _selectedPeriod,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: _hours.length,
                      itemBuilder: (ctx, i) {
                        final val = _hours[i];
                        final isSel = val == _selectedHour;
                        return InkWell(
                          onTap: () => setState(() => _selectedHour = val),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Center(
                              child: Text(
                                val.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSel
                                      ? AppColors.primary
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(width: 1, color: Colors.grey.shade200),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _minutes.length,
                      itemBuilder: (ctx, i) {
                        final val = _minutes[i];
                        final isSel = val == _selectedMinute;
                        return InkWell(
                          onTap: () => setState(() => _selectedMinute = val),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Center(
                              child: Text(
                                val.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSel
                                      ? AppColors.primary
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(width: 1, color: Colors.grey.shade200),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _periods.length,
                      itemBuilder: (ctx, i) {
                        final val = _periods[i];
                        final isSel = val == _selectedPeriod;
                        return InkWell(
                          onTap: () => setState(() => _selectedPeriod = val),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                val,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSel
                                      ? AppColors.primary
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _setNow,
                  child: const Text(
                    'Now',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context, _formatResult());
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
