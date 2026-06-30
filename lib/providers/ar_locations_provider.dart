import 'package:flutter/foundation.dart';
import '../models/ar_location.dart';
import '../models/visit_history.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import 'package:uuid/uuid.dart';

class ArLocationsProvider extends ChangeNotifier {
  final _db = DatabaseService.instance;
  final _loc = LocationService.instance;
  // FIX: cannot use 'const' as both type annotation and value modifier on a field.
  final _uuid = const Uuid();

  List<ArLocation> _locations = [];
  List<ArLocation> get locations => List.unmodifiable(_locations);

  List<NearbyResult> _nearby = [];
  List<NearbyResult> get nearbyLocations => List.unmodifiable(_nearby);

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  // FIX: filterCategory is a String with 'All' default (was nullable in search_screen but
  // provider.setFilterCategory always receives a String; null guard added to setter).
  String _filterCategory = 'All';
  String get filterCategory => _filterCategory;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ─── Init ────────────────────────────────────────────────────────────────

  Future<void> loadLocations() async {
    _isLoading = true;
    notifyListeners();

    _locations = _db.getAllLocations();
    _isLoading = false;
    notifyListeners();
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> addLocation(ArLocation location) async {
    await _db.saveLocation(location);
    _locations = _db.getAllLocations();
    notifyListeners();
  }

  Future<void> updateLocation(ArLocation location) async {
    await _db.updateLocation(location);
    _locations = _db.getAllLocations();
    notifyListeners();
  }

  Future<void> deleteLocation(String id) async {
    await _db.deleteLocation(id);
    _locations = _db.getAllLocations();
    notifyListeners();
  }

  ArLocation createNew({
    required String title,
    required String subtitle,
    required String description,
    required double latitude,
    required double longitude,
    String? textMessage,
    String? imagePath,
    String? videoPath,
    String? modelPath,
    required String category,
    String modelType = 'default',
  }) {
    final now = DateTime.now();
    return ArLocation(
      id: _uuid.v4(),
      title: title,
      subtitle: subtitle,
      description: description,
      latitude: latitude,
      longitude: longitude,
      textMessage: textMessage,
      imagePath: imagePath,
      videoPath: videoPath,
      modelPath: modelPath,
      category: category,
      modelType: modelType,
      createdDate: now,
      updatedDate: now,
    );
  }

  // ─── Nearby Detection ────────────────────────────────────────────────────

  void updateNearby(double radiusMeters) {
    _nearby = _loc.getNearbyLocations(_locations, radiusMeters);
    notifyListeners();
  }

  // ─── Search & Filter ──────────────────────────────────────────────────────

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // FIX: accepts nullable String so search_screen can pass null for "All"
  void setFilterCategory(String? category) {
    _filterCategory = category ?? 'All';
    notifyListeners();
  }

  List<ArLocation> get filteredLocations {
    var list = _locations;
    if (_filterCategory != 'All') {
      list = list.where((l) => l.category == _filterCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((l) =>
              l.title.toLowerCase().contains(q) ||
              l.category.toLowerCase().contains(q) ||
              l.description.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  // ─── History ──────────────────────────────────────────────────────────────

  Future<void> recordVisit(ArLocation location) async {
    final pos = _loc.currentPosition;
    final history = VisitHistory(
      id: _uuid.v4(),
      locationId: location.id,
      locationTitle: location.title,
      visitTime: DateTime.now(),
      viewCount: 1,
      latitude: pos?.latitude,
      longitude: pos?.longitude,
    );
    await _db.saveHistory(history);
  }

  Future<void> incrementClick(String locationId) async {
    final histories = _db.getHistoryForLocation(locationId);
    if (histories.isEmpty) return;
    final latest = histories.reduce(
        (a, b) => a.visitTime.isAfter(b.visitTime) ? a : b);
    latest.clickCount++;
    await _db.updateHistory(latest);
  }

  List<VisitHistory> get allHistory => _db.getAllHistory();

  Future<void> clearHistory() async {
    await _db.clearAllHistory();
    notifyListeners();
  }

  // ─── Export / Import ─────────────────────────────────────────────────────

  Map<String, dynamic> exportData() => _db.exportData();

  Future<void> importData(Map<String, dynamic> data) async {
    await _db.importData(data);
    _locations = _db.getAllLocations();
    notifyListeners();
  }
}
