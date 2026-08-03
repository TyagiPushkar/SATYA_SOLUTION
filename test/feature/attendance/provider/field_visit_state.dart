import 'package:latlong2/latlong.dart';

class FieldVisitState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? attendanceData;
  final List<dynamic> visitsData;
  final List<LatLng> rawVisitPoints;
  final List<LatLng> fieldVisitRoutePoints;
  final List<LatLng> stoppageRoutePoints;
  final List<String> locationTimestamps;
  final List<double> locationSpeeds;

  const FieldVisitState({
    this.isLoading = false,
    this.error,
    this.attendanceData,
    this.visitsData = const [],
    this.rawVisitPoints = const [],
    this.fieldVisitRoutePoints = const [],
    this.stoppageRoutePoints = const [],
    this.locationTimestamps = const [],
    this.locationSpeeds = const [],
  });

  FieldVisitState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? attendanceData,
    List<dynamic>? visitsData,
    List<LatLng>? rawVisitPoints,
    List<LatLng>? fieldVisitRoutePoints,
    List<LatLng>? stoppageRoutePoints,
    List<String>? locationTimestamps,
    List<double>? locationSpeeds,
    bool clearError = false,
    bool clearAttendance = false,
  }) {
    return FieldVisitState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      attendanceData:
          clearAttendance ? null : (attendanceData ?? this.attendanceData),
      visitsData: visitsData ?? this.visitsData,
      rawVisitPoints: rawVisitPoints ?? this.rawVisitPoints,
      fieldVisitRoutePoints:
          fieldVisitRoutePoints ?? this.fieldVisitRoutePoints,
      stoppageRoutePoints: stoppageRoutePoints ?? this.stoppageRoutePoints,
      locationTimestamps: locationTimestamps ?? this.locationTimestamps,
      locationSpeeds: locationSpeeds ?? this.locationSpeeds,
    );
  }

  /// Whether we have data to show on map/timeline
  bool get hasData =>
      rawVisitPoints.isNotEmpty || attendanceData != null || visitsData.isNotEmpty;

  /// Initial/first point for map centering
  LatLng? get firstPoint =>
      rawVisitPoints.isNotEmpty ? rawVisitPoints.first : null;
}
