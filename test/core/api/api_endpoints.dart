class ApiEndpoints {
  static const String baseUrl =
      'https://namamibackend-1namamibackend.onrender.com/api/v1';
  // static const String baseUrl = 'http://192.168.1.6:5000/api/v1';
  static const String login = '/employees/login';
  static const String logout = '/employees/logout';
  static const String profile = '/profile';
  static const String home = '/home';
  static const String clockIn = '/attendance/clock-in';
  static const String clockOut = '/attendance/clock-out';
  static const String allEmployeeAttendance =
      '/attendance/all-employee-attendance';
  static const String createCustomer = '/customers/create';
  static const String getCustomers = '/customers/get-all';
  static const String getCreateTaskForm = '/tasks/create-form';
  static const String getCustomerForm = '/customers/options';
  static const String createTask = '/tasks/create';
  static const String getTaskTypes = '/task-types/get-all';

  static const String getTasks = '/tasks/get-all';
  static const String getEmployees = '/employees/get-all';
  static const String createEmployee = '/employees/create';
  static const String getCreateEmployeeForm = '/employees/create-form';
  static const String getPermissions = '/employees/get-permission';
  static const String myTeam = '/employees/my-team';
  static const String customerTasks = '/tasks/customer/task';
  static const String teamTasks = '/tasks/team/task';
  static String getTaskDetails(String slug) => '/tasks/get/$slug';
  static const String getFieldVisits = '/field-visits/get-by-date';
  static const String getCompleteBehalfFields = '/complete-behalf/fields';
  static const String completeBehalfTask = '/complete-behalf/complete';

  static String get socketUrl {
    try {
      final uri = Uri.parse(baseUrl);
      return '${uri.scheme}://${uri.host}:${uri.port}'; //abcdefgA1234@
    } catch (_) {
      return 'https://namamibackend-1namamibackend.onrender.com';
    }
  }
}
