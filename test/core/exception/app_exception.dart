class AppException implements Exception {
  final String message;
  final String? prefix;
  AppException([this.message = 'Something went wrong', this.prefix]);
  @override
  String toString() {
    return '${prefix != null ? '$prefix: ' : ''}$message';
  }
}
class ServerException extends AppException {
  ServerException([super.message = 'Internal Server Error', super.prefix = 'Server Error']);
}
class NetworkException extends AppException {
  NetworkException([super.message = 'No Internet Connection', super.prefix = 'Network Error']);
}
class TimeoutException extends AppException {
  TimeoutException([super.message = 'Connection Timed Out', super.prefix = 'Timeout']);
}
class UnauthorizedException extends AppException {
  UnauthorizedException([super.message = 'Unauthorized Access', super.prefix = 'Unauthorized']);
}
class UnknownException extends AppException {
  UnknownException([super.message = 'An unknown error occurred', super.prefix = 'Unknown Error']);
}
