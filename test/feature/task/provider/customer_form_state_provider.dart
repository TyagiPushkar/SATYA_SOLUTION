import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'customer_form_fields_provider.dart';

class CustomerFormState {
  final Map<String, TextEditingController> controllers;
  final Map<String, dynamic> formValues;
  final Map<String, String> errors;
  CustomerFormState({
    required this.controllers,
    required this.formValues,
    required this.errors,
  });
  CustomerFormState copyWith({
    Map<String, TextEditingController>? controllers,
    Map<String, dynamic>? formValues,
    Map<String, String>? errors,
  }) {
    return CustomerFormState(
      controllers: controllers ?? this.controllers,
      formValues: formValues ?? this.formValues,
      errors: errors ?? this.errors,
    );
  }
}

class CustomerFormNotifier extends Notifier<CustomerFormState> {
  final Map<String, TextEditingController> _controllersToDispose = {};

  @override
  CustomerFormState build() {
    ref.onDispose(() {
      for (final controller in _controllersToDispose.values) {
        controller.dispose();
      }
      _controllersToDispose.clear();
    });
    return CustomerFormState(controllers: {}, formValues: {}, errors: {});
  }

  TextEditingController getController(String name, {String initialText = ''}) {
    final existing = state.controllers[name];
    if (existing != null) return existing;
    final controller = TextEditingController(text: initialText);
    controller.addListener(() {
      if (state.errors.containsKey(name) && controller.text.trim().isNotEmpty) {
        clearFieldError(name);
      }
    });
    state.controllers[name] = controller;
    _controllersToDispose[name] = controller;
    return controller;
  }

  void updateFormValue(String name, dynamic value) {
    final newValues = Map<String, dynamic>.from(state.formValues);
    newValues[name] = value?.toString() ?? '';
    final newErrors = Map<String, String>.from(state.errors);
    newErrors.remove(name);
    state = state.copyWith(formValues: newValues, errors: newErrors);
  }

  void clearFieldError(String name) {
    if (state.errors.containsKey(name)) {
      final newErrors = Map<String, String>.from(state.errors);
      newErrors.remove(name);
      state = state.copyWith(errors: newErrors);
    }
  }

  bool validate(List<CustomerFormField> fields) {
    final Map<String, String> newErrors = {};
    bool isValid = true;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    for (final field in fields) {
      final val = state.formValues[field.name];
      final controller = state.controllers[field.name];
      final textVal = controller?.text ?? '';
      bool isEmpty = false;
      if (field.type == 'select') {
        isEmpty = (val == null || val.toString().trim().isEmpty);
      } else if (field.name == 'image') {
        isEmpty = (controller == null || textVal == 'No file chosen' || textVal.trim().isEmpty);
      } else {
        isEmpty = (controller == null || textVal.trim().isEmpty);
      }
      if (field.required && isEmpty) {
        newErrors[field.name] = '${field.label} is required';
        isValid = false;
      } else if (!isEmpty && (field.type == 'email' || field.name == 'email')) {
        if (!emailRegex.hasMatch(textVal.trim())) {
          newErrors[field.name] = 'Invalid email address';
          isValid = false;
        }
      }
    }
    state = state.copyWith(errors: newErrors);
    return isValid;
  }

  Map<String, dynamic> getPayload() {
    final Map<String, dynamic> payload = {};
    for (final entry in state.controllers.entries) {
      payload[entry.key] = entry.value.text.toString();
    }
    for (final entry in state.formValues.entries) {
      payload[entry.key] = entry.value?.toString() ?? '';
    }
    payload.putIfAbsent('owner', () => '1');
    payload.putIfAbsent('image', () => 'https://example.com/images/default.jpg');
    payload.putIfAbsent('oldCustomerNo', () => 'CUST20250045');

    if (payload.containsKey('paidInstNo') && payload['paidInstNo'] != null) {
      payload['paidInstNo'] = payload['paidInstNo'].toString();
    }

    if (payload.containsKey('irrRate') && payload['irrRate'] != null) {
      final irrStr = payload['irrRate'].toString().replaceAll(RegExp(r'\D'), '');
      payload['irrRate'] = irrStr.length > 2 ? irrStr.substring(0, 2) : irrStr;
    }
    return payload;
  }
}

final customerFormStateProvider = NotifierProvider.autoDispose<CustomerFormNotifier, CustomerFormState>(() {
  return CustomerFormNotifier();
});
