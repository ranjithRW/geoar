import 'dart:math' as math;

/// Utilities for mapping GPS coordinates to AR screen positions.
class ArMath {
  /// Normalize bearing to 0–360 degrees.
  static double normalizeBearing(double bearing) {
    bearing = bearing % 360;
    if (bearing < 0) bearing += 360;
    return bearing;
  }

  /// Angular difference between two bearings (−180 to +180).
  static double angleDiff(double from, double to) {
    double diff = (to - from + 540) % 360 - 180;
    return diff;
  }

  /// Map an angle offset (degrees) to a normalized screen X (0.0–1.0).
  /// [fovH] is the horizontal field of view in degrees (typically 60–90).
  static double angleToScreenX(double angleDiff, {double fovH = 60.0}) {
    final clamped = angleDiff.clamp(-fovH / 2, fovH / 2);
    return (clamped / fovH) + 0.5;
  }

  /// Map a pitch (tilt) in degrees to a normalized screen Y (0.0–1.0).
  /// Pitch of 0° = horizon (center), positive = up.
  static double pitchToScreenY(double pitch, {double fovV = 45.0}) {
    final clamped = pitch.clamp(-fovV / 2, fovV / 2);
    // Invert: positive pitch should render higher on screen (lower Y)
    return 0.5 - (clamped / fovV);
  }

  /// Calculate pitch from accelerometer values.
  /// [y] and [z] are accelerometer axes (m/s²).
  static double pitchFromAccelerometer(double x, double y, double z) {
    return math.atan2(y, math.sqrt(x * x + z * z)) * (180 / math.pi);
  }

  /// Distance label string.
  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// Convert degrees to radians.
  static double toRad(double deg) => deg * math.pi / 180;

  /// Convert radians to degrees.
  static double toDeg(double rad) => rad * 180 / math.pi;

  /// Haversine distance between two GPS points in meters (backup calculation).
  static double haversineDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = toRad(lat2 - lat1);
    final dLon = toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(lat1)) *
            math.cos(toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  /// True bearing from point 1 to point 2 in degrees (0–360).
  static double bearing(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    final dLon = toRad(lon2 - lon1);
    final y = math.sin(dLon) * math.cos(toRad(lat2));
    final x = math.cos(toRad(lat1)) * math.sin(toRad(lat2)) -
        math.sin(toRad(lat1)) * math.cos(toRad(lat2)) * math.cos(dLon);
    return normalizeBearing(toDeg(math.atan2(y, x)));
  }
}
