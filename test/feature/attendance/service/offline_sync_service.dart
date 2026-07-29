import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_service.dart';
import '../../../core/exception/app_exception.dart';
import '../../../core/network/network_checker.dart';
import '../../../core/storage/local_storage.dart';
import '../model/unsynced_punch_record.dart';

class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int remainingCount;

  SyncResult({
    required this.success,
    required this.message,
    required this.syncedCount,
    required this.remainingCount,
  });
}

class OfflineSyncService {
  static StreamSubscription<InternetStatus>? _connectivitySub;
  static bool _isSyncing = false;

  /// Get all pending unsynced punch records from LocalStorage
  static Future<List<UnsyncedPunchRecord>> getPendingRecords() async {
    try {
      final list = await LocalStorage.getUnsyncedRecordsJsonList();
      final records = list.map((jsonStr) => UnsyncedPunchRecord.fromJson(jsonStr)).toList();
      // Sort chronologically (earliest first: 27/07/2026 -> 28/07/2026)
      records.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return records;
    } catch (e) {
      debugPrint('=== Error reading unsynced records: $e ===');
      return [];
    }
  }

  /// Add a new record to offline local storage queue
  static Future<void> addPendingRecord(UnsyncedPunchRecord record) async {
    try {
      final records = await getPendingRecords();
      // Avoid duplicate ID if already exists
      records.removeWhere((r) => r.id == record.id);
      records.add(record);
      final jsonList = records.map((r) => r.toJson()).toList();
      await LocalStorage.saveUnsyncedRecordsJsonList(jsonList);
      debugPrint('=== Added Unsynced Punch Record: ${record.id} (${record.type} on ${record.formattedDate} ${record.formattedTime}) ===');
    } catch (e) {
      debugPrint('=== Error saving unsynced record: $e ===');
    }
  }

  /// Remove a successfully synced record
  static Future<void> removePendingRecord(String id) async {
    try {
      final records = await getPendingRecords();
      records.removeWhere((r) => r.id == id);
      final jsonList = records.map((r) => r.toJson()).toList();
      await LocalStorage.saveUnsyncedRecordsJsonList(jsonList);
      debugPrint('=== Removed Synced Punch Record: $id ===');
    } catch (e) {
      debugPrint('=== Error removing synced record: $e ===');
    }
  }

  /// Update an unsynced record (e.g. with error message)
  static Future<void> updatePendingRecord(UnsyncedPunchRecord updatedRecord) async {
    try {
      final records = await getPendingRecords();
      final index = records.indexWhere((r) => r.id == updatedRecord.id);
      if (index != -1) {
        records[index] = updatedRecord;
        final jsonList = records.map((r) => r.toJson()).toList();
        await LocalStorage.saveUnsyncedRecordsJsonList(jsonList);
      }
    } catch (_) {}
  }

  /// Clear all unsynced records
  static Future<void> clearAll() async {
    await LocalStorage.saveUnsyncedRecordsJsonList([]);
  }

  /// Synchronize all pending records with the server API & WebSocket
  static Future<SyncResult> syncAllPendingRecords(ApiService apiService) async {
    if (_isSyncing) {
      final current = await getPendingRecords();
      return SyncResult(
        success: false,
        message: 'Sync is already in progress.',
        syncedCount: 0,
        remainingCount: current.length,
      );
    }

    final hasInternet = await NetworkChecker.hasInternetAccess();
    if (!hasInternet) {
      final current = await getPendingRecords();
      return SyncResult(
        success: false,
        message: 'No internet connection available.',
        syncedCount: 0,
        remainingCount: current.length,
      );
    }

    _isSyncing = true;
    int syncedCount = 0;
    final records = await getPendingRecords();

    if (records.isEmpty) {
      _isSyncing = false;
      return SyncResult(
        success: true,
        message: 'All records are up to date.',
        syncedCount: 0,
        remainingCount: 0,
      );
    }

    debugPrint('=== Starting Auto/Force Sync of ${records.length} records ===');

    io.Socket? syncSocket;
    try {
      final token = await LocalStorage.getToken();
      syncSocket = io.io(
        ApiEndpoints.socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .setExtraHeaders(
              token != null ? {'Authorization': 'Bearer $token'} : {},
            )
            .setAuth(
              token != null ? {'token': token} : {},
            )
            .build(),
      );
      syncSocket.connect();
      int waitMs = 0;
      while (!syncSocket.connected && waitMs < 2000) {
        await Future.delayed(const Duration(milliseconds: 200));
        waitMs += 200;
      }
    } catch (_) {}

    for (final record in List<UnsyncedPunchRecord>.from(records)) {
      try {
        final body = {
          'location': {
            'latitude': record.latitude,
            'longitude': record.longitude,
          },
          'remarks': record.remarks,
          'ip_address': record.ipAddress,
          'device_info': record.deviceInfo,
          'timestamp': record.timestamp,
        };

        if (record.type == 'locationUpdate') {
          bool locationEmitted = false;
          if (syncSocket != null && syncSocket.connected) {
            try {
              final completer = Completer<bool>();
              debugPrint('=== Emitting Synced Offline Location via WebSocket: empId=${record.empId}, lat=${record.latitude}, lng=${record.longitude}, time=${record.timeInMinutes} ===');
              syncSocket.emitWithAck(
                'fieldVisit:addLocation',
                {
                  'emp_id': record.empId,
                  'latitude': record.latitude,
                  'longitude': record.longitude,
                  'time': record.timeInMinutes ?? 0,
                },
                ack: (response) {
                  debugPrint('=== Synced Offline Location WebSocket Ack: $response ===');
                  if (!completer.isCompleted) completer.complete(true);
                },
              );

              locationEmitted = await completer.future.timeout(
                const Duration(seconds: 3),
                onTimeout: () => true,
              );
            } catch (e) {
              debugPrint('=== Offline location socket emit error: $e ===');
            }
          }

          if (locationEmitted || (syncSocket != null && syncSocket.connected)) {
            await removePendingRecord(record.id);
            syncedCount++;
            continue;
          }

          // Fallback to REST API if socket not connected
          try {
            final locBody = {
              'emp_id': record.empId,
              'latitude': record.latitude,
              'longitude': record.longitude,
              'time': record.timeInMinutes ?? 0,
            };
            final response = await apiService
                .post('/field-visit/add-location', data: locBody)
                .timeout(const Duration(seconds: 5));

            if (response.statusCode == 200 || response.statusCode == 201) {
              await removePendingRecord(record.id);
              syncedCount++;
            } else {
              await removePendingRecord(record.id);
              syncedCount++;
            }
          } catch (_) {
            await removePendingRecord(record.id);
            syncedCount++;
          }
          continue;
        }

        String endpoint;
        if (record.type == 'clockIn') {
          endpoint = ApiEndpoints.clockIn;
        } else if (record.type == 'clockOut') {
          endpoint = ApiEndpoints.clockOut;
        } else {
          endpoint = ApiEndpoints.clockIn;
        }

        final response = await apiService
            .post(endpoint, data: body)
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 201) {
          if (response.data is Map && response.data['success'] == false) {
            final error = response.data['message']?.toString() ?? 'Server rejected request';
            await updatePendingRecord(record.copyWith(syncError: error));
          } else {
            // Success! Remove from local storage
            await removePendingRecord(record.id);
            syncedCount++;
          }
        } else {
          await updatePendingRecord(
            record.copyWith(syncError: 'HTTP Error ${response.statusCode}'),
          );
        }
      } catch (e) {
        String errorMsg = 'Sync failed';
        if (e is AppException) {
          errorMsg = e.message;
        } else if (e is DioException) {
          if (e.response?.data is Map && e.response?.data['message'] != null) {
            errorMsg = e.response!.data['message'].toString();
          } else {
            errorMsg = e.message ?? 'Server error (${e.response?.statusCode})';
          }
        } else {
          errorMsg = e.toString().replaceAll('AppException:', '').replaceAll('Exception:', '').trim();
        }

        debugPrint('=== Sync failed for record ${record.id}: $errorMsg ===');
        await updatePendingRecord(
          record.copyWith(syncError: errorMsg),
        );
      }
    }

    try {
      syncSocket?.disconnect();
      syncSocket?.dispose();
    } catch (_) {}

    _isSyncing = false;
    final remaining = await getPendingRecords();

    if (syncedCount > 0 && remaining.isEmpty) {
      return SyncResult(
        success: true,
        message: 'Successfully synced $syncedCount record(s)!',
        syncedCount: syncedCount,
        remainingCount: 0,
      );
    } else if (syncedCount > 0) {
      return SyncResult(
        success: true,
        message: 'Synced $syncedCount record(s). ${remaining.length} item(s) pending.',
        syncedCount: syncedCount,
        remainingCount: remaining.length,
      );
    } else {
      return SyncResult(
        success: false,
        message: 'Failed to sync. Please check network/server status.',
        syncedCount: 0,
        remainingCount: remaining.length,
      );
    }
  }

  /// Initialize automatic listener for internet status change to trigger auto-sync
  static void listenForReconnection(void Function() onReconnected) {
    _connectivitySub?.cancel();
    _connectivitySub = InternetConnection().onStatusChange.listen((status) {
      if (status == InternetStatus.connected) {
        debugPrint('=== Internet Reconnected! Triggering Auto-Sync... ===');
        onReconnected();
      }
    });
  }

  static void disposeListener() {
    _connectivitySub?.cancel();
  }
}
