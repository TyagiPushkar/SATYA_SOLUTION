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

class AdminPermission {
  final PermissionAction role;
  final PermissionAction leave;
  final PermissionAction state;
  final PermissionAction branch;
  final PermissionAction region;
  final PermissionAction reports;
  final PermissionAction holidays;
  final PermissionAction tasktype;
  final PermissionAction leaveType;
  final PermissionAction department;
  final PermissionAction nonworking;
  final PermissionAction designation;
  final PermissionAction leaveprofile;
  final PermissionAction leavesettingsLeave;
  final PermissionAction leavesettingsHolidays;
  final PermissionAction leavesettingsLeaveType;
  final PermissionAction leavesettingsNonworking;
  final PermissionAction leavesettingsLeaveprofile;

  AdminPermission({
    required this.role,
    required this.leave,
    required this.state,
    required this.branch,
    required this.region,
    required this.reports,
    required this.holidays,
    required this.tasktype,
    required this.leaveType,
    required this.department,
    required this.nonworking,
    required this.designation,
    required this.leaveprofile,
    required this.leavesettingsLeave,
    required this.leavesettingsHolidays,
    required this.leavesettingsLeaveType,
    required this.leavesettingsNonworking,
    required this.leavesettingsLeaveprofile,
  });

  bool get hasAnyAccess =>
      role.hasAnyAccess ||
      leave.hasAnyAccess ||
      state.hasAnyAccess ||
      branch.hasAnyAccess ||
      region.hasAnyAccess ||
      reports.hasAnyAccess ||
      holidays.hasAnyAccess ||
      tasktype.hasAnyAccess ||
      leaveType.hasAnyAccess ||
      department.hasAnyAccess ||
      nonworking.hasAnyAccess ||
      designation.hasAnyAccess ||
      leaveprofile.hasAnyAccess ||
      leavesettingsLeave.hasAnyAccess ||
      leavesettingsHolidays.hasAnyAccess ||
      leavesettingsLeaveType.hasAnyAccess ||
      leavesettingsNonworking.hasAnyAccess ||
      leavesettingsLeaveprofile.hasAnyAccess;

  factory AdminPermission.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return AdminPermission(
        role: PermissionAction(),
        leave: PermissionAction(),
        state: PermissionAction(),
        branch: PermissionAction(),
        region: PermissionAction(),
        reports: PermissionAction(),
        holidays: PermissionAction(),
        tasktype: PermissionAction(),
        leaveType: PermissionAction(),
        department: PermissionAction(),
        nonworking: PermissionAction(),
        designation: PermissionAction(),
        leaveprofile: PermissionAction(),
        leavesettingsLeave: PermissionAction(),
        leavesettingsHolidays: PermissionAction(),
        leavesettingsLeaveType: PermissionAction(),
        leavesettingsNonworking: PermissionAction(),
        leavesettingsLeaveprofile: PermissionAction(),
      );
    }
    
    final ls = json['leavesettings'] as Map<String, dynamic>? ?? {};

    return AdminPermission(
      role: PermissionAction.fromJson(json['role']),
      leave: PermissionAction.fromJson(json['leave']),
      state: PermissionAction.fromJson(json['state']),
      branch: PermissionAction.fromJson(json['branch']),
      region: PermissionAction.fromJson(json['region']),
      reports: PermissionAction.fromJson(json['reports']),
      holidays: PermissionAction.fromJson(json['holidays']),
      tasktype: PermissionAction.fromJson(json['tasktype'] ?? json['taskType']),
      leaveType: PermissionAction.fromJson(json['leaveType'] ?? json['leavetype']),
      department: PermissionAction.fromJson(json['department']),
      nonworking: PermissionAction.fromJson(json['nonworking'] ?? json['nonWorking']),
      designation: PermissionAction.fromJson(json['designation']),
      leaveprofile: PermissionAction.fromJson(json['leaveprofile'] ?? json['leaveProfile']),
      leavesettingsLeave: PermissionAction.fromJson(ls['leave']),
      leavesettingsHolidays: PermissionAction.fromJson(ls['holidays']),
      leavesettingsLeaveType: PermissionAction.fromJson(ls['leaveType'] ?? ls['leavetype']),
      leavesettingsNonworking: PermissionAction.fromJson(ls['nonworking'] ?? ls['nonWorking']),
      leavesettingsLeaveprofile: PermissionAction.fromJson(ls['leaveprofile'] ?? ls['leaveProfile']),
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
  final PermissionAction customer;
  final AdminPermission admin;

  UserPermission({
    required this.task,
    required this.feeds,
    required this.employee,
    required this.settings,
    required this.dashboard,
    required this.attendance,
    required this.customer,
    required this.admin,
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
        customer: PermissionAction(),
        admin: AdminPermission.fromJson(null),
      );
    }
    return UserPermission(
      task: TaskPermission.fromJson(json['task']),
      feeds: PermissionAction.fromJson(json['feeds']),
      employee: EmployeePermission.fromJson(json['employee']),
      settings: PermissionAction.fromJson(json['settings']),
      dashboard: PermissionAction.fromJson(json['dashboard']),
      attendance: AttendancePermission.fromJson(json['attendance']),
      customer: PermissionAction.fromJson(json['customer']),
      admin: AdminPermission.fromJson(json['admin']),
    );
  }
}
