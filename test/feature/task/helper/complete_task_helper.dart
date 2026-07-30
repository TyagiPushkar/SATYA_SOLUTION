import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/widgets/app_snackbar.dart';
import '../../home/screen/main_screen.dart';
import '../provider/complete_task_fields_provider.dart';
import '../provider/complete_task_form_state_provider.dart';
import '../provider/task_provider.dart';

class CompleteTaskHelper {
  static final ImagePicker _imagePicker = ImagePicker();

  static Future<void> checkLostData(WidgetRef ref) async {
    try {
      final response = await _imagePicker.retrieveLostData();
      if (response.isEmpty || response.file == null) return;
      final image = response.file!;
      final prefs = await SharedPreferences.getInstance();
      final fieldName = prefs.getString('last_picked_field');
      if (fieldName != null && fieldName.isNotEmpty) {
        final notifier = ref.read(completeTaskFormStateProvider.notifier);
        notifier.setControllerValue(fieldName, image.name);
        await prefs.remove('last_picked_field');
      }
    } catch (e) {
      debugPrint('Error retrieving lost image data: $e');
    }
  }

  static Future<void> pickImage(
    BuildContext context,
    WidgetRef ref,
    String fieldName, {
    ImageSource? preferredSource,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_picked_field', fieldName);
    } catch (_) {}

    ImageSource? source = preferredSource;

    source ??= await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Image Source',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B2B2B),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt,
                    color: Color(0xFF0066D4),
                  ),
                  title: const Text('Take Photo (Camera)'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: Color(0xFF0066D4),
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );
      if (image != null) {
        final notifier = ref.read(completeTaskFormStateProvider.notifier);
        notifier.setControllerValue(fieldName, image.name);
        if (context.mounted) {
          AppSnackbar.show(context, 'Image captured: ${image.name}');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          'Error accessing camera/gallery: $e',
          isError: true,
        );
      }
    }
  }

  static String formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$s';
  }

  static Future<void> pickDateTime(
    BuildContext context,
    WidgetRef ref,
    String fieldName,
  ) async {
    final notifier = ref.read(completeTaskFormStateProvider.notifier);
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF0066D4)),
          ),
          child: child!,
        );
      },
    );

    if (date != null && context.mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: Color(0xFF0066D4)),
            ),
            child: child!,
          );
        },
      );

      if (time != null && context.mounted) {
        final selectedDt = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        notifier.setControllerValue(fieldName, formatDateTime(selectedDt));
      }
    }
  }

  static Future<void> getCurrentLocation(
    BuildContext context,
    WidgetRef ref,
    String fieldName,
  ) async {
    final notifier = ref.read(completeTaskFormStateProvider.notifier);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          AppSnackbar.show(
            context,
            'Please enable GPS Location services',
            isError: true,
          );
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      notifier.setControllerValue(
        fieldName,
        '${pos.latitude.toStringAsFixed(4)}° N, ${pos.longitude.toStringAsFixed(4)}° E',
      );
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  static Future<void> submitForm(
    BuildContext context,
    WidgetRef ref,
    List<CompleteTaskFormField> fields,
    String taskId,
  ) async {
    final notifier = ref.read(completeTaskFormStateProvider.notifier);

    final success = await notifier.submitTask(fields: fields, taskId: taskId);

    if (!context.mounted) return;

    if (success) {
      AppSnackbar.show(context, 'Task completed successfully!');
      ref.invalidate(taskScreenProvider);
      ref.read(mainScreenTabProvider.notifier).setTab(1);
      ref.read(taskTitleProvider.notifier).setTitle('All Task');
      context.go('/home');
    } else {
      final errorMsg =
          ref.read(completeTaskFormStateProvider).submitError ??
          'Please fill in all required fields';
      AppSnackbar.show(context, errorMsg, isError: true);
    }
  }
}
