import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/ar_location.dart';
import '../models/visit_history.dart';

class DatabaseService {
  static const String _locationsBox = 'ar_locations';
  static const String _historyBox = 'visit_history';

  static DatabaseService? _instance;
  static DatabaseService get instance => _instance ??= DatabaseService._();
  DatabaseService._();

  late Box<ArLocation> _locations;
  late Box<VisitHistory> _history;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(dir.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ArLocationAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(VisitHistoryAdapter());
    }

    _locations = await Hive.openBox<ArLocation>(_locationsBox);
    _history = await Hive.openBox<VisitHistory>(_historyBox);
  }

  // ─── Locations ───────────────────────────────────────────────────────────

  List<ArLocation> getAllLocations() => _locations.values.toList();

  ArLocation? getLocation(String id) {
    try {
      return _locations.values.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLocation(ArLocation location) async {
    await _locations.put(location.id, location);
  }

  Future<void> deleteLocation(String id) async {
    // FIX: orElse: () => null is invalid when the key type is non-nullable dynamic.
    // Use try/catch to safely find the key, then delete if found.
    dynamic foundKey;
    try {
      foundKey = _locations.keys.firstWhere(
        (k) => _locations.get(k)?.id == id,
      );
    } catch (_) {
      foundKey = null;
    }
    if (foundKey != null) await _locations.delete(foundKey);
  }

  Future<void> updateLocation(ArLocation location) async {
    location.updatedDate = DateTime.now();
    await _locations.put(location.id, location);
  }

  ValueListenable<Box<ArLocation>> get locationsListenable =>
      _locations.listenable();

  // ─── History ─────────────────────────────────────────────────────────────

  List<VisitHistory> getAllHistory() =>
      _history.values.toList()..sort((a, b) => b.visitTime.compareTo(a.visitTime));

  List<VisitHistory> getHistoryForLocation(String locationId) =>
      _history.values.where((h) => h.locationId == locationId).toList();

  Future<void> saveHistory(VisitHistory history) async {
    await _history.put(history.id, history);
  }

  Future<void> updateHistory(VisitHistory history) async {
    await _history.put(history.id, history);
  }

  Future<void> clearAllHistory() async {
    await _history.clear();
  }

  // ─── Export / Import ─────────────────────────────────────────────────────

  Map<String, dynamic> exportData() {
    return {
      'locations': getAllLocations()
          .map((l) => {
                'id': l.id,
                'title': l.title,
                'subtitle': l.subtitle,
                'description': l.description,
                'latitude': l.latitude,
                'longitude': l.longitude,
                'textMessage': l.textMessage,
                'category': l.category,
                'modelType': l.modelType,
                'createdDate': l.createdDate.toIso8601String(),
                'updatedDate': l.updatedDate.toIso8601String(),
              })
          .toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> importData(Map<String, dynamic> data) async {
    final locations = data['locations'] as List? ?? [];
    for (final item in locations) {
      final location = ArLocation(
        id: item['id'],
        title: item['title'],
        subtitle: item['subtitle'] ?? '',
        description: item['description'] ?? '',
        latitude: (item['latitude'] as num).toDouble(),
        longitude: (item['longitude'] as num).toDouble(),
        textMessage: item['textMessage'],
        category: item['category'] ?? 'General',
        modelType: item['modelType'] ?? 'default',
        createdDate: DateTime.parse(item['createdDate']),
        updatedDate: DateTime.parse(item['updatedDate']),
      );
      await saveLocation(location);
    }
  }

  Future<void> clearCache() async {
    await _history.clear();
  }

  Future<void> dispose() async {
    await _locations.close();
    await _history.close();
  }
}
