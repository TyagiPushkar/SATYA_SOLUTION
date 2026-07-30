import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../helper/complete_task_helper.dart';
import '../provider/complete_task_fields_provider.dart';
import '../provider/complete_task_form_state_provider.dart';

class CompleteTaskScreen extends ConsumerStatefulWidget {
  final dynamic taskExtra;
  const CompleteTaskScreen({super.key, this.taskExtra});

  @override
  ConsumerState<CompleteTaskScreen> createState() => _CompleteTaskScreenState();
}

class _CompleteTaskScreenState extends ConsumerState<CompleteTaskScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CompleteTaskHelper.checkLostData(ref);
    });
  }

  String _getTaskId() {
    if (widget.taskExtra == null) return '';
    if (widget.taskExtra is String) return widget.taskExtra as String;
    if (widget.taskExtra is Map) {
      final map = widget.taskExtra as Map;
      return map['taskId']?.toString() ??
          map['task_id']?.toString() ??
          map['id']?.toString() ??
          map['slug']?.toString() ??
          '';
    }
    return widget.taskExtra.toString();
  }

  @override
  Widget build(BuildContext context) {
    final fieldsAsync = ref.watch(completeTaskFieldsProvider);
    final formState = ref.watch(completeTaskFormStateProvider);
    final notifier = ref.read(completeTaskFormStateProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: CustomAppBar(
        title: "Complete Task",
        backgroundColor: AppColors.primary,
        textColor: AppColors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: fieldsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Failed to load form fields: $err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.refresh(completeTaskFieldsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (fields) {
          final nowStr = CompleteTaskHelper.formatDateTime(DateTime.now());
          for (final field in fields) {
            final defaultVal = field.defaultValue ?? '';
            final controller = notifier.getController(
              field.name,
              initialText: field.type == 'datetime-local' ? nowStr : defaultVal,
            );
            if (field.type == 'datetime-local' && controller.text.isEmpty) {
              controller.text = nowStr;
            }
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0066D4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Task Completion Form',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2B2B2B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ...fields
                          .where((field) => notifier.isFieldVisible(field))
                          .map(
                            (field) =>
                                _buildDynamicField(field, formState, notifier),
                          ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: formState.isSubmitting
                          ? null
                          : () => CompleteTaskHelper.submitForm(
                              context,
                              ref,
                              fields,
                              _getTaskId(),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0066D4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                      child: formState.isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Submit Task',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDynamicField(
    CompleteTaskFormField field,
    CompleteTaskFormState formState,
    CompleteTaskFormNotifier notifier,
  ) {
    final name = field.name;
    final label = field.label;
    final type = field.type;
    final placeholder = field.placeholder;
    final required = field.required;
    final options = field.options ?? [];
    final error = formState.errors[name];

    final isOnlinePaymentType =
        (name.toLowerCase().contains('paymenttype') ||
            name.toLowerCase().contains('paymentmode') ||
            label.toLowerCase().contains('payment type') ||
            label.toLowerCase().contains('payment mode')) &&
        (formState.selectedValues[name]?.toString().toLowerCase().contains(
                  'online',
                ) ==
                true ||
            formState.selectedValues[name]?.toString().toLowerCase().contains(
                  'digital',
                ) ==
                true);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: error != null ? Colors.red.shade400 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              if (required)
                const Text(
                  ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (type == 'select')
            _buildSelectInput(name, placeholder, options, formState, notifier)
          else if (type == 'datetime-local' ||
              type == 'datetime' ||
              type == 'date')
            _buildDateTimeInput(name, placeholder, formState, notifier)
          else if (type == 'file' ||
              type == 'image' ||
              name.toLowerCase().contains('image') ||
              name.toLowerCase().contains('photo'))
            _buildImageInput(name, placeholder, notifier)
          else if (type == 'location' ||
              name.toLowerCase().contains('location'))
            _buildLocationInput(name, placeholder, notifier)
          else
            _buildTextInput(name, placeholder, type, notifier),

          if (isOnlinePaymentType) _buildQrCodeCard(formState, notifier),

          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              error,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQrCodeCard(
    CompleteTaskFormState formState,
    CompleteTaskFormNotifier notifier,
  ) {
    final amountText = notifier.getController('paymentAmount').text.trim();
    final amount = amountText.isNotEmpty ? amountText : '0';
    final upiUrl =
        'upi://pay?pa=satyasolution@upi&pn=SatyaSolution&am=$amount&cu=INR';

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF0066D4).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.qr_code_2, color: Color(0xFF0066D4), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'UPI Payment QR Code',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0066D4),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0066D4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '₹ ${amount == '0' ? '0.00' : amount}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: QrImageView(
              data: upiUrl,
              version: QrVersions.auto,
              size: 180.0,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF222222),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF222222),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Scan to pay using Google Pay, PhonePe, Paytm, or BHIM',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput(
    String name,
    String placeholder,
    String type,
    CompleteTaskFormNotifier notifier,
  ) {
    final controller = notifier.getController(name);
    final isNumber = type == 'number';

    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        fillColor: const Color(0xFFF9FAFB),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0066D4), width: 1.5),
        ),
        prefixIcon: isNumber
            ? Icon(
                name.contains('Phone') ? Icons.phone : Icons.currency_rupee,
                size: 18,
                color: const Color(0xFF0066D4),
              )
            : null,
      ),
    );
  }

  Widget _buildSelectInput(
    String name,
    String placeholder,
    List<CompleteTaskFormFieldOption> options,
    CompleteTaskFormState formState,
    CompleteTaskFormNotifier notifier,
  ) {
    final selectedVal = formState.selectedValues[name];
    String displayLabel = placeholder;

    for (final opt in options) {
      if (opt.value == selectedVal?.toString()) {
        displayLabel = opt.label;
        break;
      }
    }

    return InkWell(
      onTap: () {
        _showSelectOptionsBottomSheet(name, placeholder, options, notifier);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              displayLabel,
              style: TextStyle(
                fontSize: 14,
                color: selectedVal != null
                    ? const Color(0xFF222222)
                    : Colors.grey.shade400,
                fontWeight: selectedVal != null
                    ? FontWeight.w500
                    : FontWeight.normal,
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Color(0xFF0066D4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectOptionsBottomSheet(
    String name,
    String placeholder,
    List<CompleteTaskFormFieldOption> options,
    CompleteTaskFormNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                placeholder,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B2B2B),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final opt = options[index];
                    final isSelected =
                        ref
                            .read(completeTaskFormStateProvider)
                            .selectedValues[name] ==
                        opt.value;

                    return ListTile(
                      title: Text(
                        opt.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFF0066D4)
                              : Colors.black87,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: Color(0xFF0066D4),
                            )
                          : null,
                      onTap: () {
                        notifier.updateSelectedValue(name, opt.value);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateTimeInput(
    String name,
    String placeholder,
    CompleteTaskFormState formState,
    CompleteTaskFormNotifier notifier,
  ) {
    final controller = notifier.getController(name);

    return InkWell(
      onTap: () => CompleteTaskHelper.pickDateTime(context, ref, name),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              controller.text.isNotEmpty ? controller.text : placeholder,
              style: TextStyle(
                fontSize: 14,
                color: controller.text.isNotEmpty
                    ? const Color(0xFF222222)
                    : Colors.grey.shade400,
                fontWeight: controller.text.isNotEmpty
                    ? FontWeight.w500
                    : FontWeight.normal,
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              color: Color(0xFF0066D4),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageInput(
    String name,
    String placeholder,
    CompleteTaskFormNotifier notifier,
  ) {
    final controller = notifier.getController(name);

    return Column(
      children: [
        TextField(
          controller: controller,
          readOnly: true,
          onTap: () => CompleteTaskHelper.pickImage(context, ref, name),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            fillColor: const Color(0xFFF9FAFB),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            suffixIcon: IconButton(
              icon: const Icon(
                Icons.add_a_photo_outlined,
                color: Color(0xFF0066D4),
                size: 20,
              ),
              onPressed: () => CompleteTaskHelper.pickImage(context, ref, name),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInput(
    String name,
    String placeholder,
    CompleteTaskFormNotifier notifier,
  ) {
    final controller = notifier.getController(name);

    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        fillColor: const Color(0xFFF9FAFB),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        suffixIcon: IconButton(
          icon: const Icon(
            Icons.my_location,
            color: Color(0xFF0066D4),
            size: 20,
          ),
          onPressed: () =>
              CompleteTaskHelper.getCurrentLocation(context, ref, name),
        ),
      ),
    );
  }
}
