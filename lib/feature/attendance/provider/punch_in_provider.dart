import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_service.dart';
import '../../../core/exception/app_exception.dart';
import '../../../core/network/network_checker.dart';
import '../../../core/storage/local_storage.dart';
import '../model/unsynced_punch_record.dart';
import '../service/background_location_service.dart';
import '../service/offline_sync_service.dart';
import 'sync_provider.dart';

class PunchInState {
  final bool isPunchedIn;
  final DateTime? punchInTime;
  final DateTime? punchOutTime;
  final bool isLoading;
  final String? error;
  final bool isInitialized;

  const PunchInState({
    this.isPunchedIn = false,
    this.punchInTime,
    this.punchOutTime,
    this.isLoading = false,
    this.error,
    this.isInitialized = false,
  });

  PunchInState copyWith({
    bool? isPunchedIn,
    DateTime? punchInTime,
    DateTime? punchOutTime,
    bool? isLoading,
    String? error,
    bool? isInitialized,
  }) {
    return PunchInState(
      isPunchedIn: isPunchedIn ?? this.isPunchedIn,
      punchInTime: punchInTime ?? this.punchInTime,
      punchOutTime: punchOutTime ?? this.punchOutTime,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class PunchInNotifier extends Notifier<PunchInState> {
  Timer? _autoPunchOutTimer;

  @override
  PunchInState build() {
    ref.onDispose(() {
      _autoPunchOutTimer?.cancel();
    });
    _restorePunchState();
    return const PunchInState(isPunchedIn: false, isLoading: false);
  }

  void _restorePunchState() async {
    final isPunchedIn = await LocalStorage.getPunchStatus();
    final timeStr = await LocalStorage.getPunchInTime();
    DateTime? punchInTime;
    if (timeStr != null) {
      punchInTime = DateTime.tryParse(timeStr);
    }
    state = state.copyWith(
      isPunchedIn: isPunchedIn,
      punchInTime: punchInTime,
      isInitialized: true,
    );
    if (isPunchedIn) {
      BackgroundLocationService.startLocationTracking();
      _checkAndScheduleAutoPunchOut();
    }
  }

  void _checkAndScheduleAutoPunchOut() {
    _autoPunchOutTimer?.cancel();
    if (!state.isPunchedIn) return;

    final now = DateTime.now();
    final punchInTime = state.punchInTime ?? now;

    DateTime target7PM;
    if (punchInTime.hour < 19) {
      target7PM = DateTime(
        punchInTime.year,
        punchInTime.month,
        punchInTime.day,
        19,
        0,
        0,
      );
    } else {
      final nextDay = punchInTime.add(const Duration(days: 1));
      target7PM = DateTime(
        nextDay.year,
        nextDay.month,
        nextDay.day,
        19,
        0,
        0,
      );
    }

    if (now.isAfter(target7PM) || now.isAtSameMomentAs(target7PM)) {
      debugPrint('=== AUTO PUNCH OUT TRIGGERED (Past 7:00 PM) ===');
      _triggerAutoPunchOut();
    } else {
      final durationUntil7PM = target7PM.difference(now);
      debugPrint(
        '=== AUTO PUNCH OUT SCHEDULED IN: ${durationUntil7PM.inMinutes} mins (At 7:00 PM) ===',
      );
      _autoPunchOutTimer = Timer(durationUntil7PM, () {
        debugPrint('=== AUTO PUNCH OUT TIMER FIRED AT 7:00 PM ===');
        _triggerAutoPunchOut();
      });
    }
  }

  Future<void> _triggerAutoPunchOut() async {
    if (!state.isPunchedIn) return;
    int empId = 7;
    try {
      final empJson = await LocalStorage.getEmployeeData();
      if (empJson != null && empJson.isNotEmpty) {
        final map = jsonDecode(empJson) as Map<String, dynamic>;
        if (map['id'] != null) {
          empId = (map['id'] is int)
              ? map['id']
              : (int.tryParse(map['id'].toString()) ?? 7);
        }
      }
    } catch (_) {}
    await togglePunchIn(empId: empId);
  }

  Future<Position> _getLocationOrThrow() async {
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    } catch (_) {}

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw AppException(
        'Location service (GPS) is turned off. Please turn on Location services to punch in.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw AppException(
          'Location permission denied. Location access is required to punch in.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw AppException(
        'Location permission permanently denied. Please allow location permission in app settings to punch in.',
      );
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 3),
          ),
        );
        return pos;
      } catch (_) {}

      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          return lastPos;
        }
      } catch (_) {}
    }

    return Position(
      latitude: 26.8467,
      longitude: 80.9462,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  Future<String> _getDeviceInfo() async {
    String devName = Platform.operatingSystem;
    try {
      if (kIsWeb) {
        devName = 'Web Browser';
      } else if (Platform.isAndroid) {
        devName = 'Android (${Platform.operatingSystemVersion})';
      } else if (Platform.isIOS) {
        devName = 'iPhone (${Platform.operatingSystemVersion})';
      } else if (Platform.isWindows) {
        devName = 'Windows Desktop (${Platform.operatingSystemVersion})';
      } else if (Platform.isMacOS) {
        devName = 'Mac (${Platform.operatingSystemVersion})';
      } else if (Platform.isLinux) {
        devName = 'Linux (${Platform.operatingSystemVersion})';
      }
    } catch (_) {}

    int batteryLevel = 100;
    try {
      batteryLevel = await Battery().batteryLevel.timeout(
        const Duration(milliseconds: 300),
        onTimeout: () => 100,
      );
    } catch (_) {}

    return '$devName | Battery: $batteryLevel%';
  }

  Future<String> _getIpAddress() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '192.168.1.10';
  }

  Future<String?> togglePunchIn({required int empId}) async {
    if (state.isLoading == true) return null;

    final currentlyPunchedIn = state.isPunchedIn == true;
    final isNowPunchedIn = !currentlyPunchedIn;
    final now = DateTime.now();

    state = state.copyWith(isLoading: true, error: null);
    final apiService = ref.read(apiServiceProvider);

    Position pos;
    try {
      pos = await _getLocationOrThrow();
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return 'ERROR: ${e.message}';
    } catch (e) {
      final msg =
          'Location error: ${e.toString().replaceAll('Exception:', '').trim()}';
      state = state.copyWith(isLoading: false, error: msg);
      return 'ERROR: $msg';
    }

    final lat = pos.latitude;
    final lng = pos.longitude;

    final ipAddress = await _getIpAddress().timeout(
      const Duration(milliseconds: 500),
      onTimeout: () => '192.168.1.10',
    );
    final deviceInfo = await _getDeviceInfo();

    final body = {
      'location': {'latitude': lat, 'longitude': lng},
      'remarks': 'Visited client office',
      'ip_address': ipAddress,
      'device_info': deviceInfo,
    };

    final hasInternet = await NetworkChecker.hasInternetAccess();

    if (!isNowPunchedIn) {
      // PUNCH OUT:
      _autoPunchOutTimer?.cancel();
      await LocalStorage.savePunchStatus(false);
      await BackgroundLocationService.stopLocationTracking();

      if (!hasInternet) {
        // Calculate stationary duration if available
        int minutes = 0;
        if (state.punchInTime != null) {
          minutes = now.difference(state.punchInTime!).inSeconds ~/ 60;
        }

        // Save offline location update record for WebSocket sync
        final locRecord = UnsyncedPunchRecord(
          id: 'loc_out_${now.millisecondsSinceEpoch}',
          type: 'locationUpdate',
          timestamp: now.toIso8601String(),
          latitude: lat,
          longitude: lng,
          remarks: 'Visited client office',
          ipAddress: ipAddress,
          deviceInfo: deviceInfo,
          empId: empId,
          timeInMinutes: minutes,
        );
        await OfflineSyncService.addPendingRecord(locRecord);

        // Save offline punch out record
        final offlineRecord = UnsyncedPunchRecord(
          id: 'punch_out_${now.millisecondsSinceEpoch}',
          type: 'clockOut',
          timestamp: now.toIso8601String(),
          latitude: lat,
          longitude: lng,
          remarks: 'Visited client office',
          ipAddress: ipAddress,
          deviceInfo: deviceInfo,
          empId: empId,
        );
        await OfflineSyncService.addPendingRecord(offlineRecord);
        ref.read(syncProvider.notifier).loadRecords();

        state = state.copyWith(
          isPunchedIn: false,
          punchOutTime: now,
          isLoading: false,
          error: null,
        );
        return 'Punched Out Offline! Data saved locally & will auto-sync when internet connects.';
      }

      try {
        final response = await apiService
            .post(ApiEndpoints.clockOut, data: body)
            .timeout(const Duration(seconds: 3));

        debugPrint('=== CLOCK OUT API RESPONSE ===');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Response Data: ${response.data}');
      } catch (e) {
        debugPrint(
          '=== CLOCK OUT API TIMEOUT/ERROR HANDLED -> Saved Offline ===: $e',
        );
        final offlineRecord = UnsyncedPunchRecord(
          id: 'punch_out_${now.millisecondsSinceEpoch}',
          type: 'clockOut',
          timestamp: now.toIso8601String(),
          latitude: lat,
          longitude: lng,
          remarks: 'Visited client office',
          ipAddress: ipAddress,
          deviceInfo: deviceInfo,
          empId: empId,
        );
        await OfflineSyncService.addPendingRecord(offlineRecord);
        ref.read(syncProvider.notifier).loadRecords();
      }

      state = state.copyWith(
        isPunchedIn: false,
        punchOutTime: now,
        isLoading: false,
        error: null,
      );

      return 'Successfully Punched Out!';
    } else {
      // PUNCH IN:
      if (!hasInternet) {
        // Save offline punch in record
        await LocalStorage.savePunchStatus(true);
        await LocalStorage.savePunchInTime(now.toIso8601String());
        await BackgroundLocationService.startLocationTracking();

        final offlineRecord = UnsyncedPunchRecord(
          id: 'punch_in_${now.millisecondsSinceEpoch}',
          type: 'clockIn',
          timestamp: now.toIso8601String(),
          latitude: lat,
          longitude: lng,
          remarks: 'Visited client office',
          ipAddress: ipAddress,
          deviceInfo: deviceInfo,
          empId: empId,
        );
        await OfflineSyncService.addPendingRecord(offlineRecord);

        // Save location update record for WebSocket sync
        final locRecord = UnsyncedPunchRecord(
          id: 'loc_in_${now.millisecondsSinceEpoch}',
          type: 'locationUpdate',
          timestamp: now.toIso8601String(),
          latitude: lat,
          longitude: lng,
          remarks: 'Visited client office',
          ipAddress: ipAddress,
          deviceInfo: deviceInfo,
          empId: empId,
          timeInMinutes: 0,
        );
        await OfflineSyncService.addPendingRecord(locRecord);
        ref.read(syncProvider.notifier).loadRecords();

        state = state.copyWith(
          isPunchedIn: true,
          punchInTime: now,
          isLoading: false,
          error: null,
        );

        _checkAndScheduleAutoPunchOut();

        return 'Punched In Offline! Data saved locally & will auto-sync when internet connects.';
      }

      try {
        final response = await apiService
            .post(ApiEndpoints.clockIn, data: body)
            .timeout(const Duration(seconds: 8));

        debugPrint('=== CLOCK IN API RESPONSE ===');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Response Data: ${response.data}');

        if (response.data is Map && response.data['success'] == false) {
          final errMsg =
              response.data['message']?.toString() ?? 'Server rejected request';
          throw AppException(errMsg);
        }

        final serverMsg =
            (response.data is Map && response.data['message'] != null)
            ? response.data['message'].toString()
            : 'Successfully Punched In!';

        await LocalStorage.savePunchStatus(true);
        await LocalStorage.savePunchInTime(now.toIso8601String());
        await BackgroundLocationService.startLocationTracking();

        state = state.copyWith(
          isPunchedIn: true,
          punchInTime: now,
          isLoading: false,
          error: null,
        );

        _checkAndScheduleAutoPunchOut();

        return serverMsg;
      } catch (e) {
        String errorMsg = 'Unable to connect to server';
        if (e is TimeoutException ||
            e.toString().toLowerCase().contains('connection timeout') ||
            e.toString().toLowerCase().contains('socketexception') ||
            e.toString().toLowerCase().contains('connection refused')) {
          // Network connection error -> Fallback to Offline Punch!
          await LocalStorage.savePunchStatus(true);
          await LocalStorage.savePunchInTime(now.toIso8601String());
          await BackgroundLocationService.startLocationTracking();

          final offlineRecord = UnsyncedPunchRecord(
            id: 'punch_in_${now.millisecondsSinceEpoch}',
            type: 'clockIn',
            timestamp: now.toIso8601String(),
            latitude: lat,
            longitude: lng,
            remarks: 'Visited client office',
            ipAddress: ipAddress,
            deviceInfo: deviceInfo,
            empId: empId,
          );
          await OfflineSyncService.addPendingRecord(offlineRecord);
          ref.read(syncProvider.notifier).loadRecords();

          state = state.copyWith(
            isPunchedIn: true,
            punchInTime: now,
            isLoading: false,
            error: null,
          );

          _checkAndScheduleAutoPunchOut();

          return 'Punched In Offline (Network Error)! Data saved locally & will auto-sync when internet connects.';
        } else if (e is AppException) {
          errorMsg = e.message;
        } else {
          errorMsg = e.toString().replaceAll('Exception:', '').trim();
        }

        debugPrint('=== CLOCK IN API ERROR ===: $errorMsg');

        state = state.copyWith(isLoading: false, error: errorMsg);

        return 'ERROR: $errorMsg';
      }
    }
  }
}

final punchInProvider = NotifierProvider<PunchInNotifier, PunchInState>(() {
  return PunchInNotifier();
});

class PunchPromptDismissedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() {
    state = true;
  }

  void reset() {
    state = false;
  }
}

final punchPromptDismissedProvider =
    NotifierProvider<PunchPromptDismissedNotifier, bool>(
  PunchPromptDismissedNotifier.new,
);
