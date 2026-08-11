import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text.dart';
import '../model/unsynced_punch_record.dart';
import '../provider/sync_provider.dart';

class UnsyncedRecordsScreen extends ConsumerWidget {
  const UnsyncedRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    final records = syncState.records;
    final isSyncing = syncState.isSyncing;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Unsynced Records',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh List',
            onPressed: () {
              ref.read(syncProvider.notifier).loadRecords();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: records.isEmpty
                    ? Colors.green.shade50
                    : Colors.amber.shade50,
                border: Border(
                  bottom: BorderSide(
                    color: records.isEmpty
                        ? Colors.green.shade200
                        : Colors.amber.shade300,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    records.isEmpty
                        ? Icons.check_circle_rounded
                        : Icons.cloud_off_rounded,
                    color: records.isEmpty
                        ? Colors.green.shade700
                        : Colors.amber.shade900,
                    size: 32,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          records.isEmpty
                              ? 'Sub Data Synced!'
                              : '${records.length} Record(s) Unsynced',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: records.isEmpty
                              ? Colors.green.shade900
                              : Colors.amber.shade900,
                        ),
                        const SizedBox(height: 4),
                        AppText(
                          records.isEmpty
                              ? 'Aapka sara attendance data server par sync ho chuka h.'
                              : 'Ye data aapka sync nahi hua h. Internet milte hi auto-sync ho jayega ya Force Sync karein.',
                          fontSize: 13,
                          color: records.isEmpty
                              ? Colors.green.shade800
                              : Colors.amber.shade900,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Records List
            Expanded(
              child: records.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_done_outlined,
                            size: 72,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          AppText(
                            'Koi Unsynced Data Nahi Hai',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(height: 6),
                          AppText(
                            'Offline save hua koi punch record pending nahi hai.',
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
                        return _buildRecordCard(context, ref, record, index);
                      },
                    ),
            ),

            if (records.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: isSyncing
                        ? null
                        : () async {
                            final result = await ref
                                .read(syncProvider.notifier)
                                .forceSync();

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(
                                        result.success
                                            ? Icons.check_circle
                                            : Icons.error_outline,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          result.message,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: result.success
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    icon: isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.sync_rounded, size: 24),
                    label: Text(
                      isSyncing ? 'SYNCING DATA...' : 'FORCE SYNC NOW',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(
    BuildContext context,
    WidgetRef ref,
    UnsyncedPunchRecord record,
    int index,
  ) {
    final bool isPunchIn = record.type == 'clockIn';
    final Color badgeColor = isPunchIn
        ? Colors.green.shade700
        : (record.type == 'clockOut'
              ? Colors.orange.shade800
              : Colors.blue.shade700);

    final IconData iconData = isPunchIn
        ? Icons.login_rounded
        : (record.type == 'clockOut'
              ? Icons.logout_rounded
              : Icons.my_location_rounded);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: record.syncError != null
              ? Colors.red.shade200
              : Colors.grey.shade200,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(13),
                topRight: Radius.circular(13),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(iconData, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    AppText(
                      record.displayType,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: badgeColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month,
                        size: 14,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 4),
                      AppText(
                        record.formattedDate,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Card Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_filled,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        AppText(
                          'Time: ${record.formattedTime}',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Discard Record',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Record?'),
                            content: const Text(
                              'Kya aap is offline punch record ko delete karna chahte hain?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          ref
                              .read(syncProvider.notifier)
                              .clearRecord(record.id);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: AppText(
                        'Lat: ${record.latitude.toStringAsFixed(4)}, Lng: ${record.longitude.toStringAsFixed(4)}',
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                if (record.syncError != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AppText(
                                record.syncError!,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ],
                        ),
                        if (record.syncError!.toLowerCase().contains(
                          'no clock in record found',
                        )) ...[
                          const SizedBox(height: 8),
                          AppText(
                            'Server par aaj koi Clock In data nahi mila, isliye ye Punch Out sync nahi ho sakta.',
                            fontSize: 12,
                            color: Colors.red.shade800,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade800,
                                side: BorderSide(color: Colors.red.shade400),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                ref
                                    .read(syncProvider.notifier)
                                    .clearRecord(record.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Invalid Punch Out record removed.',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: const Text(
                                'Delete Invalid Punch Out',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
