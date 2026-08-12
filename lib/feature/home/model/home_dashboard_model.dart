class HomeDashboardModel {
  final String? selectedDashboard;
  final String? selectedMonth;
  final List<String>? dashboards;
  final TaskMetrics? taskMetrics;
  final FieldMetrics? fieldMetrics;
  final AmountMetrics? amountMetrics;

  HomeDashboardModel({
    this.selectedDashboard,
    this.selectedMonth,
    this.dashboards,
    this.taskMetrics,
    this.fieldMetrics,
    this.amountMetrics,
  });

  factory HomeDashboardModel.fromJson(Map<String, dynamic> json) {
    return HomeDashboardModel(
      selectedDashboard: json['selectedDashboard'] as String?,
      selectedMonth: json['selectedMonth'] as String?,
      dashboards: (json['dashboards'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      taskMetrics: json['taskMetrics'] != null
          ? TaskMetrics.fromJson(json['taskMetrics'] as Map<String, dynamic>)
          : null,
      fieldMetrics: json['fieldMetrics'] != null
          ? FieldMetrics.fromJson(json['fieldMetrics'] as Map<String, dynamic>)
          : null,
      amountMetrics: json['amountMetrics'] != null
          ? AmountMetrics.fromJson(json['amountMetrics'] as Map<String, dynamic>)
          : (json['amountCollection'] != null
              ? AmountMetrics.fromJson(
                  json['amountCollection'] as Map<String, dynamic>,
                )
              : null),
    );
  }
}

class TaskMetrics {
  final int? total;
  final int? completed;
  final int? completedPercentage;
  final int? inProgress;
  final int? inProgressPercentage;
  final int? pending;
  final int? pendingPercentage;
  final num? totalAmount;
  final num? completedAmount;
  final num? inProgressAmount;
  final num? pendingAmount;

  TaskMetrics({
    this.total,
    this.completed,
    this.completedPercentage,
    this.inProgress,
    this.inProgressPercentage,
    this.pending,
    this.pendingPercentage,
    this.totalAmount,
    this.completedAmount,
    this.inProgressAmount,
    this.pendingAmount,
  });

  factory TaskMetrics.fromJson(Map<String, dynamic> json) {
    return TaskMetrics(
      total: json['total'] as int?,
      completed: json['completed'] as int?,
      completedPercentage: json['completedPercentage'] as int?,
      inProgress: json['inProgress'] as int?,
      inProgressPercentage: json['inProgressPercentage'] as int?,
      pending: json['pending'] as int?,
      pendingPercentage: json['pendingPercentage'] as int?,
      totalAmount: (json['totalAmount'] ?? json['total_amount']) as num?,
      completedAmount: (json['completedAmount'] ?? json['completed_amount']) as num?,
      inProgressAmount: (json['inProgressAmount'] ?? json['in_progress_amount']) as num?,
      pendingAmount: (json['pendingAmount'] ?? json['pending_amount']) as num?,
    );
  }
}

class AmountMetrics {
  final num? total;
  final num? completed;
  final int? completedPercentage;
  final num? inProgress;
  final int? inProgressPercentage;
  final num? pending;
  final int? pendingPercentage;

  AmountMetrics({
    this.total,
    this.completed,
    this.completedPercentage,
    this.inProgress,
    this.inProgressPercentage,
    this.pending,
    this.pendingPercentage,
  });

  factory AmountMetrics.fromJson(Map<String, dynamic> json) {
    return AmountMetrics(
      total: (json['total'] ?? json['totalAmount'] ?? json['total_amount']) as num?,
      completed: (json['completed'] ?? json['completedAmount'] ?? json['completed_amount']) as num?,
      completedPercentage: json['completedPercentage'] as int?,
      inProgress: (json['inProgress'] ?? json['inProgressAmount'] ?? json['in_progress_amount']) as num?,
      inProgressPercentage: json['inProgressPercentage'] as int?,
      pending: (json['pending'] ?? json['pendingAmount'] ?? json['pending_amount']) as num?,
      pendingPercentage: json['pendingPercentage'] as int?,
    );
  }
}

class FieldMetrics {
  final List<String>? dates;
  final List<num>? values;
  final num? maxYValue;
  final List<String>? yLabels;

  FieldMetrics({this.dates, this.values, this.maxYValue, this.yLabels});

  factory FieldMetrics.fromJson(Map<String, dynamic> json) {
    return FieldMetrics(
      dates: (json['dates'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      values: (json['values'] as List<dynamic>?)?.map((e) => e as num).toList(),
      maxYValue: json['maxYValue'] as num?,
      yLabels: (json['yLabels'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }
}
