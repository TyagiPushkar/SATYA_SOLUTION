import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../model/unsynced_punch_record.dart';
import '../service/offline_sync_service.dart';

class SyncState {
  final List<UnsyncedPunchRecord> records;
  final bool isSyncing;
  final SyncResult? lastResult;

  const SyncState({
    this.records = const [],
    this.isSyncing = false,
    this.lastResult,
  });

  int get pendingCount => records.length;
  bool get hasUnsynced => records.isNotEmpty;

  SyncState copyWith({
    List<UnsyncedPunchRecord>? records,
    bool? isSyncing,
    SyncResult? lastResult,
  }) {
    return SyncState(
      records: records ?? this.records,
      isSyncing: isSyncing ?? this.isSyncing,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() {
    _init();
    return const SyncState();
  }

  void _init() {
    loadRecords();
    OfflineSyncService.listenForReconnection(() {
      forceSync();
    });
  }

  Future<void> loadRecords() async {
    final list = await OfflineSyncService.getPendingRecords();
    state = state.copyWith(records: list);
  }

  Future<SyncResult> forceSync() async {
    state = state.copyWith(isSyncing: true, lastResult: null);
    final apiService = ref.read(apiServiceProvider);
    final result = await OfflineSyncService.syncAllPendingRecords(apiService);
    final updatedList = await OfflineSyncService.getPendingRecords();
    state = state.copyWith(
      isSyncing: false,
      records: updatedList,
      lastResult: result,
    );
    return result;
  }

  Future<void> clearRecord(String id) async {
    await OfflineSyncService.removePendingRecord(id);
    await loadRecords();
  }
}

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(() {
  return SyncNotifier();
});
