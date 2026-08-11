import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_service.dart';
import 'complete_task_fields_provider.dart';

class CompleteTaskFormState {
  final Map<String, TextEditingController> controllers;
  final Map<String, dynamic> selectedValues;
  final Map<String, String?> errors;
  final bool isSubmitting;
  final String? submitError;

  CompleteTaskFormState({
    required this.controllers,
    required this.selectedValues,
    required this.errors,
    this.isSubmitting = false,
    this.submitError,
  });

  CompleteTaskFormState copyWith({
    Map<String, TextEditingController>? controllers,
    Map<String, dynamic>? selectedValues,
    Map<String, String?>? errors,
    bool? isSubmitting,
    String? submitError,
  }) {
    return CompleteTaskFormState(
      controllers: controllers ?? this.controllers,
      selectedValues: selectedValues ?? this.selectedValues,
      errors: errors ?? this.errors,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: submitError,
    );
  }
}

class CompleteTaskFormNotifier extends Notifier<CompleteTaskFormState> {
  final Map<String, TextEditingController> _controllersToDispose = {};

  @override
  CompleteTaskFormState build() {
    ref.onDispose(() {
      for (final controller in _controllersToDispose.values) {
        controller.dispose();
      }
      _controllersToDispose.clear();
    });
    return CompleteTaskFormState(
      controllers: {},
      selectedValues: {},
      errors: {},
    );
  }

  TextEditingController getController(String name, {String initialText = ''}) {
    final existing = state.controllers[name];
    if (existing != null) return existing;

    final controller = TextEditingController(text: initialText);
    controller.addListener(() {
      if (state.errors.containsKey(name) && state.errors[name] != null) {
        clearFieldError(name);
      }
    });

    state.controllers[name] = controller;
    _controllersToDispose[name] = controller;
    return controller;
  }

  void updateSelectedValue(String name, dynamic value) {
    final newValues = Map<String, dynamic>.from(state.selectedValues);
    newValues[name] = value;
    final newErrors = Map<String, String?>.from(state.errors);
    newErrors[name] = null;
    state = state.copyWith(selectedValues: newValues, errors: newErrors);
  }

  void setControllerValue(String name, String value) {
    final controller = getController(name);
    controller.text = value;
    clearFieldError(name);
  }

  void clearFieldError(String name) {
    if (state.errors.containsKey(name) && state.errors[name] != null) {
      final newErrors = Map<String, String?>.from(state.errors);
      newErrors[name] = null;
      state = state.copyWith(errors: newErrors);
    }
  }

  bool isFieldVisible(CompleteTaskFormField field) {
    if (field.name.isEmpty) return false;

    String collectPaymentVal = '';
    for (final entry in state.selectedValues.entries) {
      final k = entry.key.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
      if (k == 'collectpayment' || k.contains('collectpayment')) {
        collectPaymentVal = entry.value?.toString().toLowerCase().trim() ?? '';
        break;
      }
    }

    final isYes = collectPaymentVal.contains('yes') ||
        collectPaymentVal == 'yes_collect' ||
        collectPaymentVal == 'yes';
    final isNo = collectPaymentVal.contains('no') ||
        collectPaymentVal == 'no_collect' ||
        collectPaymentVal == 'no';

    String paymentTypeVal = '';
    for (final entry in state.selectedValues.entries) {
      final k = entry.key.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
      if (k == 'paymenttype' ||
          k == 'paymentmode' ||
          k.contains('paymenttype') ||
          k.contains('paymentmode')) {
        paymentTypeVal = entry.value?.toString().toLowerCase().trim() ?? '';
        break;
      }
    }

    final isOnline =
        paymentTypeVal.contains('online') || paymentTypeVal.contains('digital');

    final lowerName = field.name.toLowerCase().replaceAll('_', '');
    final lowerLabel = field.label.toLowerCase();

    // Payment Type, Payment Proof Image, and Remark (open when Yes Collect is selected)
    if (lowerName == 'paymenttype' ||
        lowerName == 'paymentmode' ||
        lowerName == 'paymentprofimage' ||
        lowerName == 'paymentproofimage' ||
        lowerName == 'remark' ||
        lowerLabel.contains('payment type') ||
        lowerLabel.contains('payment mode') ||
        lowerLabel.contains('payment prof') ||
        lowerLabel.contains('payment proof') ||
        lowerLabel == 'remark') {
      return isYes;
    }

    // Payment Amount (open when Yes Collect is selected AND payment type is NOT online)
    if (lowerName == 'paymentamount' || lowerLabel.contains('payment amount')) {
      return isYes && !isOnline;
    }

    // Non-payment fields: Reason, Client Segment, PTP Date (open ONLY when "No" is selected)
    if (lowerName == 'reason' ||
        lowerLabel == 'reason' ||
        lowerName == 'clientsegment' ||
        lowerLabel.contains('client segment') ||
        lowerName == 'ptpdate' ||
        lowerLabel.contains('ptp date')) {
      return isNo;
    }

    return true;
  }

  bool validate(List<CompleteTaskFormField> fields) {
    final Map<String, String?> newErrors = {};
    bool isValid = true;

    for (final field in fields) {
      if (!isFieldVisible(field)) continue;

      if (field.required) {
        if (field.type == 'select') {
          final val = state.selectedValues[field.name]?.toString();
          if (val == null || val.trim().isEmpty) {
            newErrors[field.name] = '${field.label} is required';
            isValid = false;
          }
        } else {
          final controller = state.controllers[field.name];
          final text = controller?.text.trim() ?? '';
          if (text.isEmpty) {
            newErrors[field.name] = '${field.label} is required';
            isValid = false;
          }
        }
      }
    }

    state = state.copyWith(errors: newErrors);
    return isValid;
  }

  Map<String, dynamic> buildSubmissionPayload(
    List<CompleteTaskFormField> fields,
    String taskId,
  ) {
    final Map<String, dynamic> payload = {
      'taskId': taskId,
    };

    for (final field in fields) {
      final name = field.name;
      if (state.selectedValues.containsKey(name)) {
        payload[name] = state.selectedValues[name]?.toString() ?? '';
      } else if (state.controllers.containsKey(name)) {
        payload[name] = state.controllers[name]?.text.trim() ?? '';
      } else {
        payload[name] = '';
      }
    }

    return payload;
  }

  Future<bool> submitTask({
    required List<CompleteTaskFormField> fields,
    required String taskId,
  }) async {
    if (!validate(fields)) {
      state = state.copyWith(submitError: 'Please fill in all required fields');
      return false;
    }

    state = state.copyWith(isSubmitting: true, submitError: null);

    try {
      final apiService = ref.read(apiServiceProvider);
      final payload = buildSubmissionPayload(fields, taskId);

      final response = await apiService.post(
        ApiEndpoints.completeBehalfTask,
        data: payload,
      );

      final responseData = response.data;
      if (responseData != null && responseData['success'] == true) {
        state = state.copyWith(isSubmitting: false, submitError: null);
        return true;
      } else {
        final message =
            responseData?['message']?.toString() ?? 'Failed to submit task';
        state = state.copyWith(isSubmitting: false, submitError: message);
        return false;
      }
    } catch (e) {
      debugPrint('Error submitting complete task: $e');
      state = state.copyWith(
        isSubmitting: false,
        submitError: 'Submission Error: $e',
      );
      return false;
    }
  }
}

final completeTaskFormStateProvider = NotifierProvider.autoDispose<
    CompleteTaskFormNotifier, CompleteTaskFormState>(() {
  return CompleteTaskFormNotifier();
});
