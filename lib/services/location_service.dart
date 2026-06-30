import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/ar_location.dart';

class NearbyResult {
  final ArLocation location;
  final double distanceMeters;

  NearbyResult({required this.location, required this.distanceMeters});
}

class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();
  LocationService._();

  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();

  Stream<Position> get positionStream => _positionController.stream;
  Position? get currentPosition => _currentPosition;

  Future<bool> requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<void> startTracking() async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) return;

    // FIX: geolocator ^11 uses LocationSettings directly (no platform-specific subclass needed).
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2, // update every 2 metres
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      _currentPosition = position;
      _positionController.add(position);
    });
  }

  Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) return null;

    try {
      // FIX: geolocator ^11 getCurrentPosition uses desiredAccuracy param,
      // NOT a LocationSettings object.  Use the named param form.
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentPosition = position;
      return position;
    } catch (_) {
      return null;
    }
  }

  /// Distance in metres between two GPS points.
  double distanceBetween(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Bearing in degrees from (lat1,lon1) to (lat2,lon2).
  double bearingBetween(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    return Geolocator.bearingBetween(lat1, lon1, lat2, lon2);
  }

  /// Returns locations within [radiusMeters] of current position.
  List<NearbyResult> getNearbyLocations(
    List<ArLocation> locations,
    double radiusMeters,
  ) {
    if (_currentPosition == null) return [];
    final results = <NearbyResult>[];
    for (final loc in locations) {
      final dist = distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        loc.latitude,
        loc.longitude,
      );
      if (dist <= radiusMeters) {
        results.add(NearbyResult(location: loc, distanceMeters: dist));
      }
    }
    results.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return results;
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  void dispose() {
    stopTracking();
    _positionController.close();
  }
}
