import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../../../core/api/api_endpoints.dart';

class MonthlyRecordsState {
  final String selectedMonth;
  final bool isLoading;
  final List<String> monthsList;
  final List<dynamic> fetchedAttendances;

  MonthlyRecordsState({
    required this.selectedMonth,
    this.isLoading = false,
    required this.monthsList,
    this.fetchedAttendances = const [],
  });

  MonthlyRecordsState copyWith({
    String? selectedMonth,
    bool? isLoading,
    List<String>? monthsList,
    List<dynamic>? fetchedAttendances,
  }) {
    return MonthlyRecordsState(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      isLoading: isLoading ?? this.isLoading,
      monthsList: monthsList ?? this.monthsList,
      fetchedAttendances: fetchedAttendances ?? this.fetchedAttendances,
    );
  }

  bool get isCurrentActiveMonth {
    final now = DateTime.now();
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final currentMonthStr = '${monthNames[now.month - 1]} ${now.year}';
    return selectedMonth == currentMonthStr || selectedMonth == 'Jul 2026';
  }

  double get absentDays => isCurrentActiveMonth ? 2.0 : 0.0;
  double get presentDays => 0.0;
  double get deductionsDays => 0.0;
  double get onLeaveDays => 0.0;
  double get nonWorkingDays => 0.0;
  double get holidayDays => 0.0;

  List<Map<String, dynamic>> get calendarDays {
    final parts = selectedMonth.split(' ');
    if (parts.length != 2) return [];

    final monthStr = parts[0];
    final year = int.tryParse(parts[1]) ?? DateTime.now().year;

    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = monthNames.indexOf(monthStr) + 1;
    if (month == 0) return [];

    final firstDay = DateTime(year, month, 1);
    final weekdayOffset = firstDay.weekday % 7;

    final prevMonthLastDay = DateTime(year, month, 0).day;
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final List<Map<String, dynamic>> days = [];

    // Previous month days
    for (int i = weekdayOffset - 1; i >= 0; i--) {
      days.add({
        'day': (prevMonthLastDay - i).toString(),
        'isCurrentMonth': false,
        'status': 'NJ',
      });
    }

    // Current month days
    for (int i = 1; i <= daysInMonth; i++) {
      String status = 'NJ'; // Not Joined / No record

      String dayStr = i.toString().padLeft(2, '0');
      String monthStrNum = month.toString().padLeft(2, '0');
      String dateStr = '$year-$monthStrNum-$dayStr';

      var found = fetchedAttendances.where((item) {
        if (item is! Map) return false;
        final rawDate = item['date']?.toString() ?? '';
        final rawClockIn = item['clock_in']?.toString() ?? '';

        bool matches(String str) {
          if (str.isEmpty) return false;
          if (str.startsWith(dateStr)) return true;
          final dt = DateTime.tryParse(str);
          if (dt != null) {
            final formatted =
                "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
            return formatted == dateStr;
          }
          return false;
        }

        return matches(rawDate) || matches(rawClockIn);
      }).toList();

      if (found.isNotEmpty) {
        status = (found.first['status'] ?? 'NJ').toString();
      }

      days.add({'day': i.toString(), 'isCurrentMonth': true, 'status': status});
    }

    // Next month days
    final remaining = 42 - days.length;
    for (int i = 1; i <= remaining; i++) {
      days.add({'day': i.toString(), 'isCurrentMonth': false, 'status': 'NJ'});
    }

    return days;
  }

  List<Map<String, dynamic>> get dailyRecords {
    final parts = selectedMonth.split(' ');
    if (parts.length != 2) return [];
    final monthStr = parts[0];
    final year = int.tryParse(parts[1]) ?? DateTime.now().year;

    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = monthNames.indexOf(monthStr) + 1;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final isActiveMonth = isCurrentActiveMonth;

    final List<Map<String, dynamic>> records = [];
    for (int i = daysInMonth; i >= 1; i--) {
      String status = 'NJ';
      String firstIn = 'Not Joined';
      Color color = Colors.grey;

      if (isActiveMonth && (i == 20 || i == 21)) {
        status = 'AB';
        firstIn = 'Absent';
        color = Colors.red;
      }

      final fullMonthName = _getFullMonthName(monthStr);
      final dateStr = '${i.toString().padLeft(2, '0')} $fullMonthName $year';

      records.add({
        'date': dateStr,
        'firstIn': firstIn,
        'lastOut': '-',
        'duration': '-',
        'status': status,
        'color': color,
      });
    }
    return records;
  }

  static String _getFullMonthName(String shortName) {
    switch (shortName) {
      case 'Jan':
        return 'January';
      case 'Feb':
        return 'February';
      case 'Mar':
        return 'March';
      case 'Apr':
        return 'April';
      case 'May':
        return 'May';
      case 'Jun':
        return 'June';
      case 'Jul':
        return 'July';
      case 'Aug':
        return 'August';
      case 'Sep':
        return 'September';
      case 'Oct':
        return 'October';
      case 'Nov':
        return 'November';
      case 'Dec':
        return 'December';
      default:
        return shortName;
    }
  }
}

class MonthlyRecordsNotifier extends Notifier<MonthlyRecordsState> {
  @override
  MonthlyRecordsState build() {
    final months = _generateMonths();
    final now = DateTime.now();
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final currentMonthStr = '${monthNames[now.month - 1]} ${now.year}';
    String initialMonth;
    if (months.contains(currentMonthStr)) {
      initialMonth = currentMonthStr;
    } else if (months.isNotEmpty) {
      initialMonth = months.first;
    } else {
      initialMonth = 'Jul 2026';
    }

    Future.microtask(() => _fetchAttendance());

    return MonthlyRecordsState(selectedMonth: initialMonth, monthsList: months);
  }

  static List<String> _generateMonths() {
    final List<String> months = [];
    final List<String> monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final currentYear = DateTime.now().year;
    final previousYear = currentYear - 1;

    for (int year = currentYear; year >= previousYear; year--) {
      for (int m = 11; m >= 0; m--) {
        months.add('${monthNames[m]} $year');
      }
    }
    return months;
  }

  void setSelectedMonth(String month) {
    state = state.copyWith(selectedMonth: month);
    _fetchAttendance();
  }

  Future<void> refreshData() async {
    await _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    state = state.copyWith(isLoading: true);
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get(ApiEndpoints.allEmployeeAttendance);
      if (response.statusCode == 200) {
        final resData = response.data;
        List<dynamic> attendancesList = [];
        if (resData is Map) {
          if (resData['data'] != null &&
              resData['data'] is Map &&
              resData['data']['attendances'] is List) {
            attendancesList = resData['data']['attendances'] as List<dynamic>;
          } else if (resData['attendances'] is List) {
            attendancesList = resData['attendances'] as List<dynamic>;
          } else if (resData['data'] is List) {
            attendancesList = resData['data'] as List<dynamic>;
          }
        }
        state = state.copyWith(
          fetchedAttendances: attendancesList,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      debugPrint('Error fetching attendance API: $e');
      state = state.copyWith(isLoading: false);
    }
  }
}

final monthlyRecordsProvider =
    NotifierProvider<MonthlyRecordsNotifier, MonthlyRecordsState>(() {
      return MonthlyRecordsNotifier();
    });
