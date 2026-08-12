import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/widgets/app_snackbar.dart';
import '../../home/screen/main_screen.dart';
import '../../attendance/provider/punch_in_provider.dart';
import '../../attendance/widget/punch_in_dialog.dart';
import '../provider/complete_task_fields_provider.dart';
import '../provider/complete_task_form_state_provider.dart';
import '../provider/task_provider.dart';
import '../../../core/theme/app_colors.dart';

class CompleteTaskHelper {
  static final ImagePicker _imagePicker = ImagePicker();

  static Future<void> checkLostData(WidgetRef ref) async {
    try {
      final response = await _imagePicker.retrieveLostData();
      final prefs = await SharedPreferences.getInstance();
      if (response.isEmpty || response.file == null) {
        await prefs.remove('last_picked_field');
        return;
      }
      final image = response.file!;
      final fieldName = prefs.getString('last_picked_field');
      if (fieldName != null && fieldName.isNotEmpty) {
        final notifier = ref.read(completeTaskFormStateProvider.notifier);
        notifier.setControllerValue(fieldName, image.path);
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

    if (!context.mounted) return;

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
                    color: AppColors.primary,
                  ),
                  title: const Text('Take Photo (Camera)'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: AppColors.primary,
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
    if (!context.mounted) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );
      if (image != null) {
        final notifier = ref.read(completeTaskFormStateProvider.notifier);
        notifier.setControllerValue(fieldName, image.path);
        if (context.mounted) {
          AppSnackbar.show(context, 'Image captured successfully');
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
    } finally {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_picked_field');
      } catch (_) {}
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
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
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
              colorScheme: const ColorScheme.light(primary: AppColors.primary),
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

      notifier.setControllerValue(fieldName, 'Fetching address...');

      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      String address =
          '${pos.latitude.toStringAsFixed(4)}° N, ${pos.longitude.toStringAsFixed(4)}° E';

      try {
        final dio = Dio();
        final response = await dio.get(
          'https://nominatim.openstreetmap.org/reverse',
          queryParameters: {
            'lat': pos.latitude,
            'lon': pos.longitude,
            'format': 'json',
          },
          options: Options(
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            },
          ),
        );
        if (response.data != null && response.data['display_name'] != null) {
          final String fetchedAddress = response.data['display_name'].toString();
          if (fetchedAddress.trim().isNotEmpty) {
            address = fetchedAddress;
          }
        }
      } catch (e) {
        debugPrint('Reverse geocode error: $e');
      }

      notifier.setControllerValue(fieldName, address);
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
    final punchState = ref.read(punchInProvider);
    if (punchState.isPunchedIn != true) {
      showPunchInRequiredDialog(context, ref);
      return;
    }

    final notifier = ref.read(completeTaskFormStateProvider.notifier);

    final success = await notifier.submitTask(fields: fields, taskId: taskId);

    if (!context.mounted) return;

    if (success) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_picked_field');
      } catch (_) {}
      if (!context.mounted) return;
      AppSnackbar.show(context, 'Task completed successfully!');
      ref.read(taskTitleProvider.notifier).setTitle('All Task');
      ref.read(taskScreenProvider.notifier).fetchTasks(refresh: true);
      ref.read(mainScreenTabProvider.notifier).setTab(1);
      context.go('/home');
    } else {
      final errorMsg =
          ref.read(completeTaskFormStateProvider).submitError ??
          'Please fill in all required fields';
      AppSnackbar.show(context, errorMsg, isError: true);
    }
  }
}
