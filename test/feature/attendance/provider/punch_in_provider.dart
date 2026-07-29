import 'dart:async';
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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

  const PunchInState({
    this.isPunchedIn = false,
    this.punchInTime,
    this.punchOutTime,
    this.isLoading = false,
    this.error,
  });

  PunchInState copyWith({
    bool? isPunchedIn,
    DateTime? punchInTime,
    DateTime? punchOutTime,
    bool? isLoading,
    String? error,
  }) {
    return PunchInState(
      isPunchedIn: isPunchedIn ?? this.isPunchedIn,
      punchInTime: punchInTime ?? this.punchInTime,
      punchOutTime: punchOutTime ?? this.punchOutTime,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PunchInNotifier extends Notifier<PunchInState> {
  @override
  PunchInState build() {
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
    state = state.copyWith(isPunchedIn: isPunchedIn, punchInTime: punchInTime);
    if (isPunchedIn) {
      BackgroundLocationService.startLocationTracking();
    }
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        return lastPos;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(milliseconds: 1000),
          ),
        );
      }
    } catch (_) {}
    return null;
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

    final pos = await _getCurrentPosition().timeout(
      const Duration(milliseconds: 1000),
      onTimeout: () => null,
    );
    final lat = pos?.latitude ?? 26.8467;
    final lng = pos?.longitude ?? 80.9462;

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
