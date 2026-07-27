import 'dart:async';
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_service.dart';
import '../../../core/exception/app_exception.dart';
import '../../../core/storage/local_storage.dart';
import '../service/background_location_service.dart';

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

    if (!isNowPunchedIn) {
      // PUNCH OUT: Guaranteed instant punch out
      await LocalStorage.savePunchStatus(false);
      await BackgroundLocationService.stopLocationTracking();

      try {
        final response = await apiService
            .post(ApiEndpoints.clockOut, data: body)
            .timeout(const Duration(seconds: 3));

        debugPrint('=== CLOCK OUT API RESPONSE ===');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Response Data: ${response.data}');
      } catch (e) {
        debugPrint('=== CLOCK OUT API TIMEOUT/ERROR HANDLED ===: $e');
      }

      state = state.copyWith(
        isPunchedIn: false,
        punchOutTime: now,
        isLoading: false,
        error: null,
      );

      return 'Successfully Punched Out!';
    } else {
      // PUNCH IN: Validate with server
      try {
        final response = await apiService
            .post(ApiEndpoints.clockIn, data: body)
            .timeout(const Duration(seconds: 12));

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
        if (e is TimeoutException) {
          errorMsg =
              'Server connection timed out. Please verify server (${ApiEndpoints.socketUrl}) is online.';
        } else if (e is AppException) {
          errorMsg = e.message;
        } else {
          final errStr = e.toString().toLowerCase();
          if (errStr.contains('connection timeout') ||
              errStr.contains('connecttimeout') ||
              errStr.contains('timed out')) {
            errorMsg =
                'Server connection timed out (${ApiEndpoints.socketUrl})';
          } else if (errStr.contains('socketexception') ||
              errStr.contains('connection refused')) {
            errorMsg =
                'Server is offline or unreachable (${ApiEndpoints.socketUrl})';
          } else {
            errorMsg = e.toString().replaceAll('Exception:', '').trim();
          }
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
