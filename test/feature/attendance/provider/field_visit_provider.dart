import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_service.dart';
import 'field_visit_state.dart';

class FieldVisitNotifier extends Notifier<FieldVisitState> {
  @override
  FieldVisitState build() {
    return const FieldVisitState();
  }

  /// Fetch field visits from API for given employee + date
  Future<void> fetchFieldVisits(int empId, String date) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get(
        ApiEndpoints.getFieldVisits,
        queryParameters: {'date': date, 'id': empId},
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final responseData = response.data;
      if (responseData is Map && responseData['success'] == true) {
        final data = responseData['data'] ?? {};
        final attendance = data['attendance'] is Map
            ? Map<String, dynamic>.from(data['attendance'])
            : null;
        final visits = data['visits'] as List<dynamic>? ?? [];

        final List<Map<String, dynamic>> cleanedVisits = [];
        final List<LatLng> fetchedPoints = [];
        final List<LatLng> stoppagePoints = [];
        final List<String> timestamps = [];
        final List<double> speeds = [];

        LatLng? lastSavedPt;

        for (final visit in visits) {
          final visitMap = Map<String, dynamic>.from(visit);
          final rawLocations = visitMap['locations'] as List<dynamic>? ?? [];
          final List<dynamic> filteredLocations = [];

          for (final loc in rawLocations) {
            if (loc['latitude'] != null && loc['longitude'] != null) {
              final lat = double.tryParse(loc['latitude'].toString());
              final lng = double.tryParse(loc['longitude'].toString());
              final timeVal = int.tryParse(loc['time']?.toString() ?? '0') ?? 0;

              if (lat != null && lng != null) {
                final pt = LatLng(lat, lng);

                bool keep = true;
                if (lastSavedPt != null) {
                  final dist = const Distance().as(
                    LengthUnit.Meter,
                    lastSavedPt,
                    pt,
                  );
                  // Ignore points less than 20 meters away unless it's a stoppage
                  if (dist < 20.0 && timeVal == 0) {
                    keep = false;
                  }
                }

                if (keep) {
                  filteredLocations.add(loc);
                  lastSavedPt = pt;

                  fetchedPoints.add(pt);
                  // Capture timestamp from createdAt or timestamp field
                  final ts =
                      loc['createdAt']?.toString() ??
                      loc['created_at']?.toString() ??
                      loc['timestamp']?.toString() ??
                      '';
                  timestamps.add(ts);
                  // Capture speed from API or default to 0
                  final spd =
                      double.tryParse(loc['speed']?.toString() ?? '0') ?? 0.0;
                  speeds.add(spd);
                  if (timeVal > 0) {
                    stoppagePoints.add(pt);
                  }
                }
              }
            }
          }
          visitMap['locations'] = filteredLocations;
          cleanedVisits.add(visitMap);
        }

        if (fetchedPoints.isNotEmpty) {
          // Calculate speeds from consecutive points if API returns 0
          for (int i = 1; i < fetchedPoints.length; i++) {
            if (speeds[i] == 0.0) {
              final dist = const Distance().as(
                LengthUnit.Meter,
                fetchedPoints[i - 1],
                fetchedPoints[i],
              );
              double timeDiffHours = 0.01;
              if (timestamps[i].isNotEmpty && timestamps[i - 1].isNotEmpty) {
                try {
                  final t1 = DateTime.parse(timestamps[i - 1]);
                  final t2 = DateTime.parse(timestamps[i]);
                  final diffSec = t2.difference(t1).inSeconds.abs();
                  if (diffSec > 0) timeDiffHours = diffSec / 3600.0;
                } catch (_) {}
              }
              final speedKmh = (dist / 1000.0) / timeDiffHours;
              speeds[i] = speedKmh.clamp(0.0, 200.0);
            }
          }

          state = state.copyWith(
            isLoading: false,
            attendanceData: attendance,
            visitsData: cleanedVisits,
            rawVisitPoints: fetchedPoints,
            fieldVisitRoutePoints: fetchedPoints,
            stoppageRoutePoints: stoppagePoints,
            locationTimestamps: timestamps,
            locationSpeeds: speeds,
          );

          // Fetch road-snapped route in background
          _fetchRoadRoute(fetchedPoints)
              .then((roadPoints) {
                if (roadPoints.isNotEmpty) {
                  final List<LatLng> fullRoadRoute = [];
                  if (fetchedPoints.first.latitude !=
                          roadPoints.first.latitude ||
                      fetchedPoints.first.longitude !=
                          roadPoints.first.longitude) {
                    fullRoadRoute.add(fetchedPoints.first);
                  }
                  fullRoadRoute.addAll(roadPoints);
                  if (fetchedPoints.last.latitude != roadPoints.last.latitude ||
                      fetchedPoints.last.longitude !=
                          roadPoints.last.longitude) {
                    fullRoadRoute.add(fetchedPoints.last);
                  }
                  state = state.copyWith(fieldVisitRoutePoints: fullRoadRoute);
                }
              })
              .catchError((e) {
                debugPrint("Road route error: $e");
              });
        } else {
          // No location points found for this date
          state = state.copyWith(
            isLoading: false,
            attendanceData: attendance,
            visitsData: cleanedVisits,
            rawVisitPoints: [],
            fieldVisitRoutePoints: [],
            stoppageRoutePoints: [],
            locationTimestamps: [],
            locationSpeeds: [],
          );
        }
        return;
      } else {
        debugPrint(
          "Field visits response error: status code ${responseData?['statusCode']}: ${responseData?['message']}",
        );
      }
    } catch (e) {
      debugPrint("Error fetching field visits: $e");
    }

    // Clear all data on error / 404 / failure response
    state = FieldVisitState(
      isLoading: false,
      error: 'Failed to fetch field visits',
    );
  }

  /// Fetch road-snapped route using OSRM
  Future<List<LatLng>> _fetchRoadRoute(List<LatLng> points) async {
    if (points.length < 2) return points;

    // Filter points to be at least 100 meters apart to prevent OSRM from creating micro-loops (square artifacts) due to GPS drift around buildings
    final List<LatLng> simplifiedPoints = [points.first];
    for (int i = 1; i < points.length; i++) {
      final dist = const Distance().as(
        LengthUnit.Meter,
        simplifiedPoints.last,
        points[i],
      );
      if (dist >= 100.0) {
        simplifiedPoints.add(points[i]);
      }
    }
    if (simplifiedPoints.last != points.last) {
      final dist = const Distance().as(
        LengthUnit.Meter,
        simplifiedPoints.last,
        points.last,
      );
      if (dist > 20.0) {
        simplifiedPoints.add(points.last);
      }
    }

    if (simplifiedPoints.length < 2) return points;

    final List<LatLng> roadRoute = [];
    final dio = Dio();

    // Process in chunks of max 20 points for fast & reliable OSRM road routing
    const chunkSize = 20;
    for (int i = 0; i < simplifiedPoints.length - 1; i += (chunkSize - 1)) {
      final end = (i + chunkSize < simplifiedPoints.length)
          ? i + chunkSize
          : simplifiedPoints.length;
      final chunk = simplifiedPoints.sublist(i, end);
      if (chunk.length < 2) continue;

      final coords = chunk.map((p) => '${p.longitude},${p.latitude}').join(';');
      final url =
          'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson';

      try {
        final response = await dio.get(
          url,
          options: Options(
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );

        if (response.statusCode == 200 &&
            response.data is Map &&
            response.data['code'] == 'Ok') {
          final routes = response.data['routes'] as List<dynamic>?;
          if (routes != null && routes.isNotEmpty) {
            final geometry = routes[0]['geometry'] as Map<dynamic, dynamic>?;
            final coordinates = geometry?['coordinates'] as List<dynamic>?;
            if (coordinates != null) {
              for (final coord in coordinates) {
                if (coord is List && coord.length >= 2) {
                  final lng = (coord[0] as num).toDouble();
                  final lat = (coord[1] as num).toDouble();
                  final newPt = LatLng(lat, lng);
                  if (roadRoute.isEmpty || roadRoute.last != newPt) {
                    roadRoute.add(newPt);
                  }
                }
              }
            }
          } else {
            roadRoute.addAll(chunk);
          }
        } else {
          roadRoute.addAll(chunk);
        }
      } catch (e) {
        debugPrint('OSRM routing error: $e');
        roadRoute.addAll(chunk);
      }
    }

    return roadRoute.isNotEmpty ? roadRoute : simplifiedPoints;
  }
}
final fieldVisitProvider =
    NotifierProvider<FieldVisitNotifier, FieldVisitState>(
      () => FieldVisitNotifier(),
    );
