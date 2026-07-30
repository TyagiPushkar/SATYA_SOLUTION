import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text.dart';
import '../../../core/widgets/app_sizebox.dart';
import '../../../core/widgets/app_textfield.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/widgets/app_form_skeleton.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../provider/customers_list_provider.dart';
import '../provider/task_form_fields_provider.dart';
import '../provider/task_provider.dart';
import '../provider/task_types_provider.dart';
import '../provider/task_creation_provider.dart';

class CreateTaskScreen extends ConsumerStatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  String? _selectedCustomer;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _formValues = {};
  final Map<String, String?> _errors = {};

  Widget _buildErrorText(String fieldName) {
    final error = _errors[fieldName];
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 4.0),
      child: AppText(error, color: Colors.red, fontSize: 12),
    );
  }

  Future<void> _submitTask() async {
    final fieldsAsync = ref.read(taskFormFieldsProvider);
    if (!fieldsAsync.hasValue) return;
    final fields = fieldsAsync.value!;

    bool isValid = true;
    final Map<String, String?> newErrors = {};

    for (final field in fields) {
      if (field.required) {
        String? value;
        if (field.name == 'customerId' || field.name == 'taskType') {
          value = _formValues[field.name]?.toString();
        } else {
          value = _controllers[field.name]?.text;
        }

        if (value == null || value.trim().isEmpty) {
          newErrors[field.name] = '${field.label} is required';
          isValid = false;
        }
      }
    }

    if (!isValid) {
      setState(() {
        _errors.clear();
        _errors.addAll(newErrors);
      });
      return;
    }

    final payload = <String, dynamic>{};
    for (final field in fields) {
      if (field.name == 'customerId' || field.name == 'taskType') {
        payload[field.name] = _formValues[field.name]?.toString();
      } else {
        final text = _controllers[field.name]?.text ?? '';
        if (field.name == 'payment_type') {
          payload[field.name] = int.tryParse(text) ?? 1;
        } else {
          payload[field.name] = text;
        }
      }
    }

    await ref.read(taskCreationProvider.notifier).createTask(payload);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showCustomerPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: SafeArea(
            child: Consumer(
              builder: (context, ref, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: AppText(
                      'Select Customer',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 1),
                  ref
                      .watch(customersListProvider)
                      .when(
                        data: (customers) {
                          if (customers.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Center(
                                child: AppText(
                                  'No customers found',
                                  color: AppColors.grey,
                                ),
                              ),
                            );
                          }
                          return ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.4,
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: customers.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  title: AppText(customers[index].name),
                                  onTap: () {
                                    setState(() {
                                      _selectedCustomer = customers[index].name;
                                      _formValues['customerId'] =
                                          customers[index].id;
                                      _errors['customerId'] = null;
                                    });
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                          );
                        },
                        loading: () => const TimeoutShimmerLoader(
                          fallbackText: 'No customers found',
                          timeout: Duration(seconds: 5),
                        ),
                        error: (e, st) => Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Center(
                            child: AppText(
                              'Failed to load customers: $e',
                              color: AppColors.grey,
                            ),
                          ),
                        ),
                      ),
                  const Divider(height: 1),
                  InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await context.push('/add-customer');

                      if (result != null && result is Map) {
                        final customerMap = Map<String, String>.from(result);
                        setState(() {
                          _selectedCustomer = customerMap['name'];
                          _formValues['customerId'] = customerMap['id'];
                          _errors['customerId'] = null;
                        });
                        ref.invalidate(customersListProvider);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add, color: AppColors.primary),
                          AppSizeBox.w(8),
                          AppText(
                            'Add New',
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(taskCreationProvider, (previous, next) {
      if (previous?.isLoading == true && !next.isLoading) {
        next.when(
          data: (_) {
            AppSnackbar.show(context, 'Task created successfully!');
            ref.invalidate(taskScreenProvider);
            context.pop(true);
            ref.read(taskCreationProvider.notifier).reset();
          },
          error: (error, stackTrace) {
            AppSnackbar.show(
              context,
              'Failed to create task: $error',
              isError: true,
            );
          },
          loading: () {},
        );
      }
    });

    final isCreating = ref.watch(taskCreationProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Create Task'),
      body: ref
          .watch(taskFormFieldsProvider)
          .when(
            data: (fields) {
              return Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(taskFormFieldsProvider);
                        await ref.read(taskFormFieldsProvider.future);
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: fields
                              .map((field) => _buildDynamicField(field))
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                  _buildBottomActions(isCreating),
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
                      onTap: () => ref.invalidate(taskFormFieldsProvider),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildDynamicField(TaskFormField field) {
    final isRequired = field.required;
    final labelText = '${field.label}${isRequired ? ' *' : ''}';

    if (field.name == 'taskType') {
      return ref
          .watch(taskTypesProvider)
          .when(
            data: (types) {
              if (types.isEmpty) {
                return const SizedBox.shrink();
              }
              final typeNames = types.map((t) => t.name).toList();

              if (_formValues[field.name] == null ||
                  !typeNames.contains(_formValues[field.name])) {
                _formValues[field.name] = typeNames.first;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel(labelText),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _errors[field.name] != null
                            ? Colors.red
                            : AppColors.borderGrey,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.white,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _formValues[field.name],
                        isExpanded: true,
                        hint: AppText(
                          field.placeholder.isNotEmpty
                              ? field.placeholder
                              : 'Select task type',
                          color: AppColors.grey,
                        ),
                        items: typeNames.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: AppText(type),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _formValues[field.name] = val;
                            _errors[field.name] = null;
                          });
                        },
                      ),
                    ),
                  ),
                  _buildErrorText(field.name),
                  const AppSizeBox.h(16),
                ],
              );
            },
            loading: () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel(labelText),
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    height: 48,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const AppSizeBox.h(16),
              ],
            ),
            error: (e, st) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel(labelText),
                AppText('Failed to load task types: $e', color: Colors.red),
                const AppSizeBox.h(16),
              ],
            ),
          );
    }


    if (field.name == 'customerId') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(labelText),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _showCustomerPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _errors[field.name] != null
                            ? Colors.red
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: AppText(
                            _selectedCustomer ??
                                (field.placeholder.isNotEmpty
                                    ? field.placeholder
                                    : 'Select Customer'),
                            color: _selectedCustomer == null
                                ? Colors.black38
                                : AppColors.black,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF8E8E93),
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () async {
                  final result = await context.push('/add-customer');
                  if (result != null && result is Map) {
                    final customerMap = Map<String, String>.from(result);
                    setState(() {
                      _selectedCustomer = customerMap['name'];
                      _formValues['customerId'] = customerMap['id'];
                      _errors['customerId'] = null;
                    });
                    ref.invalidate(customersListProvider);
                  }
                },
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0066D4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.assignment_ind,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          _buildErrorText(field.name),
          const AppSizeBox.h(16),
        ],
      );
    }

    if (field.name == 'payment_type') {
      final controller = _controllers.putIfAbsent(field.name, () {
        final c = TextEditingController();
        c.addListener(() {
          if (_errors[field.name] != null) {
            setState(() {
              _errors[field.name] = null;
            });
          }
        });
        return c;
      });
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: AppText(
                  labelText,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black.withValues(alpha: 0.8),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Tooltip(
                  message:
                      'For a base amount of 100, the allowed\nentry range is between 30 and 180.',
                  triggerMode: TooltipTriggerMode.tap,
                  showDuration: const Duration(seconds: 3),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(12),
                  textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.grey,
                  ),
                ),
              ),
            ],
          ),
          const AppSizeBox.h(4),
          AppTextField(
            controller: controller,
            hint: field.placeholder,
            fillColor: AppColors.white,
            borderColor: _errors[field.name] != null ? Colors.red : null,
            keyboardType: TextInputType.number,
            prefixIcon: const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text(
                '₹',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          _buildErrorText(field.name),
          const AppSizeBox.h(24),
        ],
      );
    }

    // Default text/number/textarea fields
    final controller = _controllers.putIfAbsent(field.name, () {
      final c = TextEditingController();
      c.addListener(() {
        if (_errors[field.name] != null) {
          setState(() {
            _errors[field.name] = null;
          });
        }
      });
      return c;
    });
    final isTextArea = field.type == 'textarea';
    final isNumber = field.type == 'number';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(labelText),
        AppTextField(
          controller: controller,
          hint: field.placeholder,
          fillColor: AppColors.white,
          borderColor: _errors[field.name] != null ? Colors.red : null,
          maxLines: isTextArea ? 4 : 1,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        ),
        _buildErrorText(field.name),
        const AppSizeBox.h(16),
      ],
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

  Widget _buildBottomActions(bool isCreating) {
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
              fontSize: 13,
              padding: EdgeInsets.zero,
              onTap: () => context.pop(),
            ),
          ),
          AppSizeBox.w(8),
          Expanded(
            child: AppButton(
              text: 'Create Task',
              color: AppColors.primary,
              fontSize: 13,
              isLoading: isCreating,
              padding: EdgeInsets.zero,
              onTap: _submitTask,
            ),
          ),
          AppSizeBox.w(8),
          Expanded(
            child: AppButton(
              text: 'Start Task',
              color: AppColors.primaryOrange,
              fontSize: 13,
              isLoading: isCreating,
              padding: EdgeInsets.zero,
              onTap: _submitTask,
            ),
          ),
        ],
      ),
    );
  }
}

class TimeoutShimmerLoader extends ConsumerStatefulWidget {
  final String fallbackText;
  final Duration timeout;

  const TimeoutShimmerLoader({
    super.key,
    this.fallbackText = 'No data found',
    this.timeout = const Duration(seconds: 5),
  });

  @override
  ConsumerState<TimeoutShimmerLoader> createState() => _TimeoutShimmerLoaderState();
}

class _TimeoutShimmerLoaderState extends ConsumerState<TimeoutShimmerLoader> {
  bool _showFallback = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.timeout, () {
      if (mounted) {
        setState(() {
          _showFallback = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showFallback) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: AppText(widget.fallbackText, color: AppColors.grey),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (index) => ListTile(
              title: Container(
                height: 16,
                width: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
