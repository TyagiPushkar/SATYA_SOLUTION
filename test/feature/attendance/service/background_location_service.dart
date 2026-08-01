import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/api/api_endpoints.dart';
import '../../../core/storage/local_storage.dart';
import '../model/unsynced_punch_record.dart';
import 'offline_sync_service.dart';

class BackgroundLocationService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        autoStartOnBoot: true,
        isForegroundMode: true,
        initialNotificationTitle: 'Field Visit Tracking Active',
        initialNotificationContent:
            'Streaming location updates in background until Punch Out',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  static Future<void> startLocationTracking() async {
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final service = FlutterBackgroundService();
        final isRunning = await service.isRunning();
        if (!isRunning) {
          await service.startService();
        }
      }
    } catch (_) {}
  }

  static Future<void> stopLocationTracking() async {
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      if (isRunning) {
        service.invoke('stopService');
      }
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  DartPluginRegistrant.ensureInitialized();

  final socketUrl = ApiEndpoints.socketUrl;
  io.Socket? socket;
  Timer? timer;

  double? lastLat;
  double? lastLng;
  DateTime? stationaryStartTime;

  DateTime? lastOfflineSavedTime;

  Future<void> sendOrSaveLocationUpdate({
    required int empId,
    required double latitude,
    required double longitude,
    required int timeInMinutes,
    bool isStationaryTick = false,
  }) async {
    bool isConnected = socket != null && socket.connected == true;
    if (isConnected) {
      try {
        print(
          '=== Background WebSocket Emitting: empId=$empId, lat=$latitude, lng=$longitude, time=$timeInMinutes ===',
        );
        socket.emitWithAck(
          'fieldVisit:addLocation',
          {
            'emp_id': empId,
            'latitude': latitude,
            'longitude': longitude,
            'time': timeInMinutes,
          },
          ack: (response) {
            print('=== Background Location WebSocket Ack: $response ===');
          },
        );
        return;
      } catch (e) {
        print(
          '=== Background Location WebSocket Emit Error: $e -> Fallback Offline Save ===',
        );
      }
    }

    // Socket offline/disconnected -> Save offline location record
    final now = DateTime.now();
    if (isStationaryTick && lastOfflineSavedTime != null) {
      if (now.difference(lastOfflineSavedTime!).inSeconds < 30) {
        return;
      }
    }
    lastOfflineSavedTime = now;

    try {
      final record = UnsyncedPunchRecord(
        id: 'loc_${now.millisecondsSinceEpoch}',
        type: 'locationUpdate',
        timestamp: now.toIso8601String(),
        latitude: latitude,
        longitude: longitude,
        empId: empId,
        timeInMinutes: timeInMinutes,
        remarks: 'Background Location Update',
      );
      await OfflineSyncService.addPendingRecord(record);
      print(
        '=== Saved Offline Location Update: lat=$latitude, lng=$longitude, time=$timeInMinutes ===',
      );
    } catch (e) {
      print('=== Error saving offline location update: $e ===');
    }
  }

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) async {
    try {
      double? finalLat = lastLat;
      double? finalLng = lastLng;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 2),
          ),
        );
        finalLat = pos.latitude;
        finalLng = pos.longitude;
      } catch (_) {}

      if (finalLat != null &&
          finalLng != null &&
          socket != null &&
          socket.connected) {
        final durationInSeconds = stationaryStartTime != null
            ? DateTime.now().difference(stationaryStartTime!).inSeconds
            : 0;
        int minutes = durationInSeconds ~/ 60;
        int empId = await _getEmpId();

        try {
          print(
            '=== Final Location Emit on Stop (Punch Out): empId=$empId, lat=$finalLat, lng=$finalLng, time=$minutes ===',
          );
          socket.emitWithAck(
            'fieldVisit:addLocation',
            {
              'emp_id': empId,
              'latitude': finalLat,
              'longitude': finalLng,
              'time': minutes,
            },
            ack: (response) {
              print('=== Final Location Ack on Stop: $response ===');
            },
          );
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      print('=== Final Location Emit Error on Stop: $e ===');
    }

    timer?.cancel();
    socket?.disconnect();
    socket?.dispose();
    service.stopSelf();
  });

  Future<void> performLocationCheck() async {
    final isPunchedIn = await LocalStorage.getPunchStatus();
    if (!isPunchedIn) {
      // Check if we need to emit before stopping
      if (lastLat != null && lastLng != null && stationaryStartTime != null) {
        final durationInSeconds = DateTime.now()
            .difference(stationaryStartTime!)
            .inSeconds;
        int empId = await _getEmpId();
        int minutes = durationInSeconds ~/ 60;
        await sendOrSaveLocationUpdate(
          empId: empId,
          latitude: lastLat!,
          longitude: lastLng!,
          timeInMinutes: minutes,
        );
      }

      timer?.cancel();
      socket?.disconnect();
      socket?.dispose();
      service.stopSelf();
      return;
    }

    double? lat;
    double? lng;

    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {}

    if (lat == null || lng == null) {
      try {
        final currentPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 3),
          ),
        );
        lat = currentPos.latitude;
        lng = currentPos.longitude;
      } catch (_) {}
    }

    // If location fetch failed, fallback to last known lat/lng so we don't jump coordinates!
    if (lat == null || lng == null) {
      if (lastLat != null && lastLng != null) {
        lat = lastLat;
        lng = lastLng;
      } else {
        print(
          '=== Background Location Check: Unable to fetch GPS location, skipping tick ===',
        );
        return;
      }
    }

    final now = DateTime.now();

    if (lastLat != null && lastLng != null && stationaryStartTime != null) {
      double distance = Geolocator.distanceBetween(
        lastLat!,
        lastLng!,
        lat!,
        lng!,
      );

      final durationInSeconds = now.difference(stationaryStartTime!).inSeconds;
      int empId = await _getEmpId();
      int minutes = durationInSeconds ~/ 60;

      if (distance < 25.0) {
        // Location unchanged (within 25m threshold)
        // Keep counting time, do NOT send socket data while stationary!
        print(
          '=== Background Location Check: Location unchanged (distance=${distance.toStringAsFixed(2)}m < 25m). Stationary duration counting: ${durationInSeconds}s (${minutes}m). Skipping socket emit. ===',
        );
      } else {
        // Location changed (distance >= 25m)
        // Emit previous location with the accumulated stationary duration spent there
        print(
          '=== Background Location Changed (distance=${distance.toStringAsFixed(2)}m >= 25m)! Emitting previous location (lat=$lastLat, lng=$lastLng) with time=$minutes min ===',
        );
        await sendOrSaveLocationUpdate(
          empId: empId,
          latitude: lastLat!,
          longitude: lastLng!,
          timeInMinutes: minutes,
          isStationaryTick: false,
        );

        lastLat = lat;
        lastLng = lng;
        stationaryStartTime = now;
      }
    } else {
      // First punch in: emit initial location with time = 0
      lastLat = lat;
      lastLng = lng;
      stationaryStartTime = now;

      int empId = await _getEmpId();
      print(
        '=== Initial Location Emit on Punch In: lat=$lastLat, lng=$lastLng, time=0 ===',
      );
      await sendOrSaveLocationUpdate(
        empId: empId,
        latitude: lastLat!,
        longitude: lastLng!,
        timeInMinutes: 0,
      );
    }
  }

  try {
    final token = await LocalStorage.getToken();
    socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(99999)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(3000)
          .setTimeout(10000)
          .setExtraHeaders(
            token != null ? {'Authorization': 'Bearer $token'} : {},
          )
          .setAuth(token != null ? {'token': token} : {})
          .build(),
    );

    socket.onConnect((_) async {
      print(
        '=== Background WebSocket Connected Successfully! Waiting 3s before location check... ===',
      );
      await Future.delayed(const Duration(seconds: 3));
      await performLocationCheck();
    });
    socket.onReconnect((_) async {
      print('=== Background WebSocket Reconnected! ===');
      await performLocationCheck();
    });
    socket.onDisconnect((reason) {
      print('=== Background WebSocket Disconnected: $reason ===');
    });
    socket.onConnectError((err) {
      print('=== Background WebSocket Connect Error: $err ===');
    });
    socket.onError((err) {
      print('=== Background WebSocket Error: $err ===');
    });

    socket.connect();
  } catch (_) {}

  timer = Timer.periodic(const Duration(seconds: 3), (t) async {
    if (socket != null && !socket.connected) {
      try {
        socket.connect();
      } catch (_) {}
    }
    await performLocationCheck();
  });
}

Future<int> _getEmpId() async {
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
  return empId;
}
