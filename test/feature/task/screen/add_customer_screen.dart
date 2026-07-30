import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text.dart';
import '../../../core/widgets/app_sizebox.dart';
import '../../../core/widgets/app_textfield.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_form_skeleton.dart';
import '../../../core/widgets/location_picker_dialog.dart';
import '../provider/customer_provider.dart';
import '../provider/customer_form_fields_provider.dart';
import '../provider/customer_form_state_provider.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  Future<void> _selectDate(
    TextEditingController controller,
    String fieldName,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        controller.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
      ref.read(customerFormStateProvider.notifier).clearFieldError(fieldName);
    }
  }

  Future<void> _pickFile(
    TextEditingController controller,
    String fieldName,
  ) async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles();
      if (result != null) {
        setState(() {
          controller.text = result.files.single.name;
        });
        ref.read(customerFormStateProvider.notifier).clearFieldError(fieldName);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          'Error picking file: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  Future<void> _saveCustomer() async {
    try {
      final fields = ref.read(customerFormFieldsProvider).value ?? [];
      final isValid = ref
          .read(customerFormStateProvider.notifier)
          .validate(fields);
      if (!isValid) {
        return;
      }

      final payload = ref.read(customerFormStateProvider.notifier).getPayload();
      await ref.read(customerProvider.notifier).createCustomer(payload);
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          'Failed to save customer: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Map<String, String>?>>(customerProvider, (
      previous,
      next,
    ) {
      if (previous?.isLoading == true && !next.isLoading) {
        next.when(
          data: (customerData) {
            if (customerData != null) {
              AppSnackbar.show(context, 'Customer saved successfully!');
              context.pop(customerData);
              ref.read(customerProvider.notifier).reset();
            }
          },
          error: (error, stackTrace) {
            AppSnackbar.show(
              context,
              'Failed to save customer: $error',
              isError: true,
            );
          },
          loading: () {},
        );
      }
    });

    final isLoading = ref.watch(customerProvider).isLoading;
    final formState = ref.watch(customerFormStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Add New Customer'),
      body: ref
          .watch(groupedCustomerFormFieldsProvider)
          .when(
            data: (grouped) {
              return Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(customerFormFieldsProvider);
                        await ref.read(customerFormFieldsProvider.future);
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: grouped.entries.map((entry) {
                            final sectionName = entry.key;
                            final sectionFields = entry.value;
                            if (sectionFields.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader(sectionName),
                                ...sectionFields.map(
                                  (field) =>
                                      _buildDynamicField(field, ref, formState),
                                ),
                                const AppSizeBox.h(8),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  _buildBottomActions(isLoading),
                ],
              );
            },
            loading: () => const AppFormSkeleton(),
            error: (e, st) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppText(
                      'Failed to load form fields: $e',
                      color: AppColors.grey,
                    ),
                    AppSizeBox.h(16),
                    AppButton(
                      text: 'Retry',
                      color: AppColors.primary,
                      onTap: () => ref.invalidate(customerFormFieldsProvider),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            title,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
          const SizedBox(height: 4),
          Container(height: 2, width: 40, color: AppColors.primaryOrange),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: AppText(
        text,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.black.withValues(alpha: 0.8),
      ),
    );
  }

  Widget _buildErrorText(String fieldName, CustomerFormState formState) {
    final error = formState.errors[fieldName];
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: AppText(error, color: Colors.red, fontSize: 12),
    );
  }

  Widget _buildDynamicField(
    CustomerFormField field,
    WidgetRef ref,
    CustomerFormState formState,
  ) {
    final isRequired = field.required;
    final labelText = '${field.label}${isRequired ? ' *' : ''}';

    if (field.name == 'location') {
      final controller = ref
          .read(customerFormStateProvider.notifier)
          .getController(field.name);
      final hasLocation = controller.text.trim().isNotEmpty;

      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel(labelText),
            AppTextField(
              controller: controller,
              hint: field.placeholder.isNotEmpty
                  ? field.placeholder
                  : 'Enter location',
              fillColor: AppColors.white,
              readOnly: true,
              onTap: () async {
                final result = await showDialog<String>(
                  context: context,
                  builder: (ctx) => LocationPickerDialog(
                    initialValue: controller.text,
                    selectedState: formState.formValues['state']?.toString(),
                  ),
                );
                if (result != null && result.isNotEmpty) {
                  setState(() {
                    controller.text = result;
                  });
                  ref
                      .read(customerFormStateProvider.notifier)
                      .updateFormValue('location', result);
                  ref
                      .read(customerFormStateProvider.notifier)
                      .clearFieldError('location');
                }
              },
              suffixIcon: GestureDetector(
                onTap: () async {
                  final result = await showDialog<String>(
                    context: context,
                    builder: (ctx) => LocationPickerDialog(
                      initialValue: controller.text,
                      selectedState: formState.formValues['state']?.toString(),
                    ),
                  );
                  if (result != null && result.isNotEmpty) {
                    setState(() {
                      controller.text = result;
                    });
                    ref
                        .read(customerFormStateProvider.notifier)
                        .updateFormValue('location', result);
                    ref
                        .read(customerFormStateProvider.notifier)
                        .clearFieldError('location');
                  }
                },
                child: Icon(
                  hasLocation ? Icons.location_on : Icons.add,
                  color: hasLocation ? AppColors.primary : AppColors.black,
                  size: hasLocation ? 24 : 22,
                ),
              ),
            ),
            _buildErrorText(field.name, formState),
          ],
        ),
      );
    }

    if (field.name == 'image') {
      final controller = ref
          .read(customerFormStateProvider.notifier)
          .getController(field.name, initialText: 'No file chosen');
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel(labelText),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _pickFile(controller, field.name),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lightGrey,
                    foregroundColor: AppColors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: AppColors.borderGrey),
                    ),
                  ),
                  child: const Text('Choose File'),
                ),
                AppSizeBox.w(12),
                Expanded(
                  child: AppText(
                    controller.text,
                    color: AppColors.grey,
                    fontSize: 14,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            _buildErrorText(field.name, formState),
          ],
        ),
      );
    }

    if (field.type == 'date') {
      final controller = ref
          .read(customerFormStateProvider.notifier)
          .getController(field.name);
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel(labelText),
            AppTextField(
              controller: controller,
              hint: field.placeholder.isNotEmpty
                  ? field.placeholder
                  : 'Select Date',
              fillColor: AppColors.white,
              readOnly: true,
              onTap: () => _selectDate(controller, field.name),
              suffixIcon: const Icon(
                Icons.calendar_today,
                color: AppColors.grey,
                size: 20,
              ),
            ),
            _buildErrorText(field.name, formState),
          ],
        ),
      );
    }

    if (field.type == 'select') {
      final options = field.options ?? [];
      final selectedValue =
          formState.formValues[field.name] ??
          (options.isNotEmpty ? options.first.value : null);

      if (formState.formValues[field.name] == null && options.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref
              .read(customerFormStateProvider.notifier)
              .updateFormValue(field.name, options.first.value);
        });
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel(labelText),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderGrey),
                borderRadius: BorderRadius.circular(8),
                color: AppColors.white,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedValue,
                  isExpanded: true,
                  hint: AppText(
                    field.placeholder.isNotEmpty
                        ? field.placeholder
                        : 'Select option',
                    color: AppColors.grey,
                  ),
                  items: options.map((opt) {
                    return DropdownMenuItem(
                      value: opt.value,
                      child: AppText(opt.label),
                    );
                  }).toList(),
                  onChanged: (val) {
                    ref
                        .read(customerFormStateProvider.notifier)
                        .updateFormValue(field.name, val);
                  },
                ),
              ),
            ),
            _buildErrorText(field.name, formState),
          ],
        ),
      );
    }

    // Default text/number fields
    final controller = ref
        .read(customerFormStateProvider.notifier)
        .getController(field.name);
    final isIrrRate =
        field.name == 'irrRate' || field.name.toLowerCase().contains('irr');
    final isNumber = field.type == 'number' || isIrrRate;
    final isEmail = field.type == 'email';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(labelText),
          AppTextField(
            controller: controller,
            hint: field.placeholder.isNotEmpty
                ? field.placeholder
                : 'Enter ${field.label}',
            fillColor: AppColors.white,
            keyboardType: isNumber
                ? TextInputType.number
                : (isEmail ? TextInputType.emailAddress : TextInputType.text),
            maxLength: isIrrRate ? 2 : null,
            inputFormatters: isIrrRate
                ? [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ]
                : null,
          ),
          _buildErrorText(field.name, formState),
        ],
      ),
    );
  }

  Widget _buildBottomActions(bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: AppButton(
              text: 'Cancel',
              color: AppColors.white,
              textColor: AppColors.black,
              onTap: () => context.pop(),
            ),
          ),
          const AppSizeBox.w(12),
          Expanded(
            child: AppButton(
              text: isLoading ? 'Saving...' : 'Save Customer',
              color: AppColors.primary,
              onTap: isLoading ? () {} : _saveCustomer,
            ),
          ),
        ],
      ),
    );
  }
}
