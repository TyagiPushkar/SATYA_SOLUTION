class PermissionAction {
  final bool add;
  final bool edit;
  final bool delete;
  final bool allView;
  final bool ownView;

  bool get hasAnyAccess => add || edit || delete || allView || ownView;

  PermissionAction({
    this.add = false,
    this.edit = false,
    this.delete = false,
    this.allView = false,
    this.ownView = false,
  });

  factory PermissionAction.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PermissionAction();
    return PermissionAction(
      add: json['add'] ?? false,
      edit: json['edit'] ?? false,
      delete: json['delete'] ?? false,
      allView: json['allView'] ?? false,
      ownView: json['ownView'] ?? false,
    );
  }
}

class TaskPermission {
  final PermissionAction taskAll;
  final PermissionAction teamTask;
  final PermissionAction deletedTasks;
  final PermissionAction taskCustomer;
  final PermissionAction onboardingTask;

  TaskPermission({
    required this.taskAll,
    required this.teamTask,
    required this.deletedTasks,
    required this.taskCustomer,
    required this.onboardingTask,
  });

  factory TaskPermission.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return TaskPermission(
        taskAll: PermissionAction(),
        teamTask: PermissionAction(),
        deletedTasks: PermissionAction(),
        taskCustomer: PermissionAction(),
        onboardingTask: PermissionAction(),
      );
    }
    return TaskPermission(
      taskAll: PermissionAction.fromJson(json['taskAll']),
      teamTask: PermissionAction.fromJson(json['teamTask']),
      deletedTasks: PermissionAction.fromJson(json['deletedTasks']),
      taskCustomer: PermissionAction.fromJson(json['taskCustomer']),
      onboardingTask: PermissionAction.fromJson(json['onboardingTask']),
    );
  }
}

class EmployeePermission {
  final PermissionAction myTeam;
  final PermissionAction allEmployee;

  EmployeePermission({required this.myTeam, required this.allEmployee});

  factory EmployeePermission.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return EmployeePermission(
        myTeam: PermissionAction(),
        allEmployee: PermissionAction(),
      );
    }
    return EmployeePermission(
      myTeam: PermissionAction.fromJson(json['myTeam']),
      allEmployee: PermissionAction.fromJson(json['allEmployee']),
    );
  }
}

class AttendancePermission {
  final PermissionAction attendanceDetails;
  final PermissionAction monthlyAttendance;

  AttendancePermission({
    required this.attendanceDetails,
    required this.monthlyAttendance,
  });

  factory AttendancePermission.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return AttendancePermission(
        attendanceDetails: PermissionAction(),
        monthlyAttendance: PermissionAction(),
      );
    }
    return AttendancePermission(
      attendanceDetails: PermissionAction.fromJson(json['attendanceDetails']),
      monthlyAttendance: PermissionAction.fromJson(json['monthlyAttendance']),
    );
  }
}

class UserPermission {
  final TaskPermission task;
  final PermissionAction feeds;
  final EmployeePermission employee;
  final PermissionAction settings;
  final PermissionAction dashboard;
  final AttendancePermission attendance;

  // New API fields
  final PermissionAction role;
  final PermissionAction admin;
  final PermissionAction leave;
  final PermissionAction branch;
  final PermissionAction holiday;
  final PermissionAction reports;
  final PermissionAction department;
  final PermissionAction designation;

  UserPermission({
    required this.task,
    required this.feeds,
    required this.employee,
    required this.settings,
    required this.dashboard,
    required this.attendance,
    required this.role,
    required this.admin,
    required this.leave,
    required this.branch,
    required this.holiday,
    required this.reports,
    required this.department,
    required this.designation,
  });

  factory UserPermission.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return UserPermission(
        task: TaskPermission.fromJson(null),
        feeds: PermissionAction(),
        employee: EmployeePermission.fromJson(null),
        settings: PermissionAction(),
        dashboard: PermissionAction(),
        attendance: AttendancePermission.fromJson(null),
        role: PermissionAction(),
        admin: PermissionAction(),
        leave: PermissionAction(),
        branch: PermissionAction(),
        holiday: PermissionAction(),
        reports: PermissionAction(),
        department: PermissionAction(),
        designation: PermissionAction(),
      );
    }
    return UserPermission(
      task: TaskPermission.fromJson(json['task']),
      feeds: PermissionAction.fromJson(json['feeds']),
      employee: EmployeePermission.fromJson(json['employee']),
      settings: PermissionAction.fromJson(json['settings']),
      dashboard: PermissionAction.fromJson(json['dashboard']),
      attendance: AttendancePermission.fromJson(json['attendance']),
      role: PermissionAction.fromJson(json['role']),
      admin: PermissionAction.fromJson(json['admin']),
      leave: PermissionAction.fromJson(json['leave']),
      branch: PermissionAction.fromJson(json['branch']),
      holiday: PermissionAction.fromJson(json['holiday']),
      reports: PermissionAction.fromJson(json['reports']),
      department: PermissionAction.fromJson(json['department']),
      designation: PermissionAction.fromJson(json['designation']),
    );
  }
}
