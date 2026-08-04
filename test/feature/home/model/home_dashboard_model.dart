class HomeDashboardModel {
  final String? selectedDashboard;
  final String? selectedMonth;
  final List<String>? dashboards;
  final TaskMetrics? taskMetrics;
  final FieldMetrics? fieldMetrics;

  HomeDashboardModel({
    this.selectedDashboard,
    this.selectedMonth,
    this.dashboards,
    this.taskMetrics,
    this.fieldMetrics,
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

  TaskMetrics({
    this.total,
    this.completed,
    this.completedPercentage,
    this.inProgress,
    this.inProgressPercentage,
    this.pending,
    this.pendingPercentage,
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
