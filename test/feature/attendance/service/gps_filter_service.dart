import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class GpsFilterService {
  static const double maxAccuracyMeters = 20.0;
  static const double minAccuracyStrictMeters = 15.0;
  static const double minDistanceFilterMeters = 5.0;
  static const double maxSpeedKmh = 120.0; // 120 km/h ~ 33.33 m/s
  static const double maxSpeedMs = maxSpeedKmh / 3.6;

  /// Check if a single position update passes base accuracy checks
  static bool isAccuracyValid(Position position, {double maxAccuracy = maxAccuracyMeters}) {
    if (position.accuracy <= 0) return true; // Accuracy not reported by device
    return position.accuracy <= maxAccuracy;
  }

  /// Comprehensive check to decide if [newPos] is a valid movement from [lastPos]
  static bool isValidMovement({
    required Position newPos,
    Position? lastPos,
  }) {
    // 1. Accuracy Check (Sabse Important)
    if (!isAccuracyValid(newPos, maxAccuracy: maxAccuracyMeters)) {
      return false;
    }

    if (lastPos == null) {
      // First point accepted if accuracy is valid
      return true;
    }

    // 2. Minimum Movement Threshold (5-10m noise filter)
    final distance = Geolocator.distanceBetween(
      lastPos.latitude,
      lastPos.longitude,
      newPos.latitude,
      newPos.longitude,
    );

    if (distance < minDistanceFilterMeters) {
      return false; // Ignored as micro GPS noise/jitter
    }

    // Calculate time difference in seconds
    final timeDiffSec = newPos.timestamp.difference(lastPos.timestamp).inSeconds.abs();

    // Prevent divide-by-zero if two positions have identical timestamp
    final effectiveTimeDiff = timeDiffSec == 0 ? 1 : timeDiffSec;

    // Calculated speed in m/s and km/h
    final calculatedSpeedMs = distance / effectiveTimeDiff;
    final calculatedSpeedKmh = calculatedSpeedMs * 3.6;

    // 3. Har location ko save mat karo (Speed / Teleportation Jump Check)
    if (calculatedSpeedKmh > maxSpeedKmh) {
      // Example: 35 meters in 1 second = 126 km/h (Impossible jump)
      return false;
    }

    // 4. Native Speed Check
    if (newPos.speed > 0) {
      final nativeSpeedKmh = newPos.speed * 3.6;
      // If native GPS hardware speed says user is moving slow (e.g. 15 km/h)
      // but point jump calculates > 70 km/h, ignore.
      if (nativeSpeedKmh < 30.0 && calculatedSpeedKmh > 70.0) {
        return false;
      }
    }

    // 5. Bearing / Direction Change Check
    if (lastPos.heading > 0 && newPos.heading > 0 && distance > 15.0) {
      double headingDiff = (newPos.heading - lastPos.heading).abs();
      if (headingDiff > 180.0) {
        headingDiff = 360.0 - headingDiff;
      }
      // Sudden 180° direction flip over short time (< 5 sec) and high speed -> ignore jump
      if (headingDiff > 135.0 && timeDiffSec <= 5) {
        return false;
      }
    }

    // 6. Strict Validation if Distance > 20 meters
    if (distance > 20.0) {
      // Must pass stricter accuracy check (<= 15m)
      if (!isAccuracyValid(newPos, maxAccuracy: minAccuracyStrictMeters)) {
        return false;
      }
      // Speed must be reasonable for urban movement
      if (calculatedSpeedKmh > 90.0) {
        return false;
      }
    }

    return true;
  }

  /// Clean an array of raw LatLng route points (used for playback/visualization)
  /// Applies moving window outlier rejection (e.g., Left -> Left -> Right -> Left -> Left)
  static List<LatLng> cleanRoutePoints(List<LatLng> points) {
    if (points.length <= 2) return points;

    final List<LatLng> cleaned = [points.first];

    for (int i = 1; i < points.length - 1; i++) {
      final prev = cleaned.last;
      final curr = points[i];
      final next = points[i + 1];

      final distPrevCurr = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude,
      );
      final distCurrNext = Geolocator.distanceBetween(
        curr.latitude,
        curr.longitude,
        next.latitude,
        next.longitude,
      );
      final distPrevNext = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        next.latitude,
        next.longitude,
      );

      // If curr is an isolated spike jump (prev->curr is large, curr->next is large, but prev->next is small)
      if (distPrevCurr > 25.0 && distCurrNext > 25.0 && distPrevNext < 20.0) {
        // Skip curr (outlier spike point)
        continue;
      }

      // Minimum movement check
      if (distPrevCurr >= minDistanceFilterMeters) {
        cleaned.add(curr);
      }
    }

    // Always add the last point if it moves beyond the last accepted point
    final lastAccepted = cleaned.last;
    final finalPt = points.last;
    final dist = Geolocator.distanceBetween(
      lastAccepted.latitude,
      lastAccepted.longitude,
      finalPt.latitude,
      finalPt.longitude,
    );
    if (dist >= minDistanceFilterMeters || cleaned.length == 1) {
      cleaned.add(finalPt);
    }

    return cleaned;
  }

  /// Calculate bearing/heading angle between two LatLng points in degrees
  static double calculateBearing(LatLng start, LatLng end) {
    final startLat = start.latitude * (math.pi / 180.0);
    final startLng = start.longitude * (math.pi / 180.0);
    final endLat = end.latitude * (math.pi / 180.0);
    final endLng = end.longitude * (math.pi / 180.0);

    final dLng = endLng - startLng;

    final y = math.sin(dLng) * math.cos(endLat);
    final x = math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(dLng);

    final brng = math.atan2(y, x);
    final brngDegrees = (brng * (180.0 / math.pi) + 360.0) % 360.0;
    return brngDegrees;
  }
}
