class ApiEndpoints {
  static const String baseUrl = 'http://192.168.1.7:5000/api/v1';
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
  static const String customerTasks = '/tasks/customer/task';

  static String get socketUrl {
    try {
      final uri = Uri.parse(baseUrl);
      return '${uri.scheme}://${uri.host}:${uri.port}';
    } catch (_) {
      return 'http://192.168.1.7:5000';
    }
  }
}
