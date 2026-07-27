import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/api/api_endpoints.dart';
import '../../../core/storage/local_storage.dart';

class BackgroundLocationService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        initialNotificationTitle: 'Field Visit Tracking Active',
        initialNotificationContent: 'Streaming location updates in background',
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

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  final socketUrl = ApiEndpoints.socketUrl;
  io.Socket? socket;
  Timer? timer;

  double? lastLat;
  double? lastLng;
  DateTime? stationaryStartTime;

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
        try {
          print(
            '=== Background WebSocket Emitting (Stop): empId=$empId, lat=$lastLat, lng=$lastLng, time=$minutes ===',
          );
          socket?.emitWithAck(
            'fieldVisit:addLocation',
            {
              'emp_id': empId,
              'latitude': lastLat,
              'longitude': lastLng,
              'time': minutes,
            },
            ack: (response) {
              print('=== Background WebSocket Ack (Stop): $response ===');
            },
          );
        } catch (e) {
          print('=== Background WebSocket Emit Error (Stop): $e ===');
        }
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
      print(
        '=== Background Location Check: distance=${distance.toStringAsFixed(2)}m, stationary_duration=${durationInSeconds}s ===',
      );

      if (distance < 25.0) {
       
      } else {
       
        int empId = await _getEmpId();
        int minutes = durationInSeconds ~/ 60; 

        try {
          print(
            '=== Location Changed! Emitting Previous Location: empId=$empId, lat=$lastLat, lng=$lastLng, time=$minutes ===',
          );
          socket?.emitWithAck(
            'fieldVisit:addLocation',
            {
              'emp_id': empId,
              'latitude': lastLat,
              'longitude': lastLng,
              'time': minutes,
            },
            ack: (response) {
              print('=== Location Changed WebSocket Ack: $response ===');
            },
          );
        } catch (e) {
          print('=== Location Changed WebSocket Emit Error: $e ===');
        }

        lastLat = lat;
        lastLng = lng;
        stationaryStartTime = now;
      }
    } else {
   
      lastLat = lat;
      lastLng = lng;
      stationaryStartTime = now;

      int empId = await _getEmpId();
      try {
        print(
          '=== Immediate Punch In WebSocket Emitting: empId=$empId, lat=$lastLat, lng=$lastLng, time=0 ===',
        );
        socket?.emitWithAck(
          'fieldVisit:addLocation',
          {
            'emp_id': empId,
            'latitude': lastLat,
            'longitude': lastLng,
            'time': 0,
          },
          ack: (response) {
            print('=== Immediate Punch In WebSocket Ack: $response ===');
          },
        );
      } catch (e) {
        print('=== Immediate Punch In WebSocket Emit Error: $e ===');
      }
    }
  }

  try {
    final token = await LocalStorage.getToken();
    socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .setExtraHeaders(
            token != null ? {'Authorization': 'Bearer $token'} : {},
          )
          .build(),
    );

    socket.onConnect((_) async {
      print(
        '=== Background WebSocket Connected. Waiting 3 seconds before initial payload... ===',
      );
      await Future.delayed(const Duration(seconds: 3));
      await performLocationCheck();
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

