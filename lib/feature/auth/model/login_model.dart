import 'employee_model.dart';

class LoginModel {
  final int statusCode;
  final bool success;
  final String message;
  final LoginData? data;

  LoginModel({
    required this.statusCode,
    required this.success,
    required this.message,
    this.data,
  });

  factory LoginModel.fromJson(Map<String, dynamic> json) {
    return LoginModel(
      statusCode: json['statusCode'] ?? 200,
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? LoginData.fromJson(json['data']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'statusCode': statusCode,
      'success': success,
      'message': message,
      if (data != null) 'data': data!.toJson(),
    };
  }
}

class LoginData {
  final EmployeeModel? employee;
  final String? accessToken;
  final String? refreshToken;

  LoginData({this.employee, this.accessToken, this.refreshToken});

  factory LoginData.fromJson(Map<String, dynamic> json) {
    final rawUser = json['employee'] ?? json['user'];
    return LoginData(
      employee: (rawUser is Map)
          ? EmployeeModel.fromJson(Map<String, dynamic>.from(rawUser))
          : null,
      accessToken: json['accessToken']?.toString(),
      refreshToken: json['refreshToken']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (employee != null) 'employee': employee!.toJson(),
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    };
  }
}
