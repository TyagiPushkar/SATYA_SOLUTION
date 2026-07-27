import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text.dart';
import '../../../core/widgets/app_sizebox.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../provider/monthly_records_provider.dart';

class MonthlyRecordsScreen extends ConsumerWidget {
  const MonthlyRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(monthlyRecordsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: const CustomAppBar(
        title: 'Monthly Records',
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Actions Row
                    _buildTopActions(context, ref, state),
                    const AppSizeBox.h(16),

                    // Calendar Card
                    _buildCalendarCard(state),
                    const AppSizeBox.h(16),

                    // Daily Records Table / List Header
                    //_buildDailyRecordsSection(state),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTopActions(
    BuildContext context,
    WidgetRef ref,
    MonthlyRecordsState state,
  ) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: AppText(
              'Add Attendance',
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
        const AppSizeBox.w(8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: state.selectedMonth,
              items: state.monthsList.map((m) {
                return DropdownMenuItem(
                  value: m,
                  child: AppText(m, fontSize: 13, fontWeight: FontWeight.bold),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  ref
                      .read(monthlyRecordsProvider.notifier)
                      .setSelectedMonth(val);
                }
              },
            ),
          ),
        ),
        const AppSizeBox.w(8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: () {
              ref.read(monthlyRecordsProvider.notifier).refreshData();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarCard(MonthlyRecordsState state) {
    final daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final calendarDays = state.calendarDays;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month,
                color: AppColors.primary,
                size: 20,
              ),
              const AppSizeBox.w(8),
              AppText(
                'Calendar View - ${state.selectedMonth}',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
          const AppSizeBox.h(16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemBuilder: (context, index) {
              return Center(
                child: AppText(
                  daysOfWeek[index],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              );
            },
          ),
          const Divider(),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: calendarDays.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemBuilder: (context, index) {
              final dayInfo = calendarDays[index];
              final isCurrentMonth = dayInfo['isCurrentMonth'] as bool;
              final status = dayInfo['status'] as String;

              Color? bg;
              Color txtColor = isCurrentMonth
                  ? Colors.black87
                  : Colors.grey.shade400;

              if (status == 'ABSENT') {
                bg = Colors.red;
                txtColor = Colors.white;
              } else if (status == 'PRESENT') {
                bg = Colors.green;
                txtColor = Colors.white;
              } else if (status == 'HALF_DAY') {
                bg = Colors.orange;
                txtColor = Colors.white;
              } else if (status == 'CLOCKED_IN') {
                bg = Colors.blue;
                txtColor = Colors.white;
              }

              return Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(4),
                  border: isCurrentMonth
                      ? Border.all(color: Colors.grey.shade200)
                      : null,
                ),
                child: Center(
                  child: AppText(
                    dayInfo['day'] as String,
                    fontSize: 12,
                    fontWeight: isCurrentMonth
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: txtColor,
                  ),
                ),
              );
            },
          ),
          const AppSizeBox.h(16),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _buildLegendItem('Present', Colors.green),
        _buildLegendItem('Half Day', Colors.orange),
        _buildLegendItem('Absent', Colors.red),
        _buildLegendItem('Non-Working', Colors.blue),
        _buildLegendItem('On Leave', Colors.purple),
        _buildLegendItem('Holiday', Colors.pink),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const AppSizeBox.w(4),
        AppText(label, fontSize: 11, color: Colors.grey.shade700),
      ],
    );
  }

  // Widget _buildDailyRecordsSection(MonthlyRecordsState state) {
  //   final dailyRecords = state.dailyRecords;
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Row(
  //         children: [
  //           const Icon(Icons.list, color: AppColors.primary, size: 20),
  //           const AppSizeBox.w(8),
  //           AppText('Daily Records', fontSize: 16, fontWeight: FontWeight.bold),
  //         ],
  //       ),
  //       const AppSizeBox.h(12),
  //       ListView.builder(
  //         shrinkWrap: true,
  //         physics: const NeverScrollableScrollPhysics(),
  //         itemCount: dailyRecords.length,
  //         itemBuilder: (context, index) {
  //           final record = dailyRecords[index];
  //           final String date = record['date'];
  //           final String firstIn = record['firstIn'];
  //           final String lastOut = record['lastOut'];
  //           final String duration = record['duration'];
  //           final String status = record['status'];
  //           final Color color = record['color'];
  //           return Container(
  //             margin: const EdgeInsets.only(bottom: 12),
  //             padding: const EdgeInsets.all(12),
  //             decoration: BoxDecoration(
  //               color: Colors.white,
  //               borderRadius: BorderRadius.circular(8),
  //               border: Border.all(color: Colors.grey.shade300),
  //             ),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Row(
  //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                   children: [
  //                     AppText(date, fontWeight: FontWeight.bold, fontSize: 14),
  //                     Container(
  //                       padding: const EdgeInsets.symmetric(
  //                         horizontal: 8,
  //                         vertical: 4,
  //                       ),
  //                       decoration: BoxDecoration(
  //                         color: color.withValues(alpha: 0.1),
  //                         borderRadius: BorderRadius.circular(12),
  //                         border: Border.all(
  //                           color: color.withValues(alpha: 0.3),
  //                         ),
  //                       ),
  //                       child: AppText(
  //                         status,
  //                         color: color,
  //                         fontWeight: FontWeight.bold,
  //                         fontSize: 12,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //                 const Divider(height: 16),
  //                 Row(
  //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                   children: [
  //                     _buildDetailItem('First In', firstIn),
  //                     _buildDetailItem('Last Out', lastOut),
  //                     _buildDetailItem('Duration', duration),
  //                   ],
  //                 ),
  //                 if (status == 'AB') ...[
  //                   const Divider(height: 16),
  //                   Align(
  //                     alignment: Alignment.centerRight,
  //                     child: SizedBox(
  //                       height: 28,
  //                       child: ElevatedButton(
  //                         onPressed: () {},
  //                         style: ElevatedButton.styleFrom(
  //                           backgroundColor: Colors.blue.shade700,
  //                           padding: const EdgeInsets.symmetric(horizontal: 12),
  //                           shape: RoundedRectangleBorder(
  //                             borderRadius: BorderRadius.circular(4),
  //                           ),
  //                         ),
  //                         child: const Icon(
  //                           Icons.add,
  //                           color: Colors.white,
  //                           size: 16,
  //                         ),
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ],
  //             ),
  //           );
  //         },
  //       ),
  //     ],
  //   );
  // }

  // Widget _buildDetailItem(String label, String value) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       AppText(label, fontSize: 11, color: Colors.grey.shade600),
  //       const AppSizeBox.h(2),
  //       AppText(value, fontSize: 13, fontWeight: FontWeight.w600),
  //     ],
  //   );
  // }
}
