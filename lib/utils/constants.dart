class AppConstants {
  // Detection
  static const double defaultDetectionRadius = 15.0; // meters
  static const List<double> detectionRadiusOptions = [5, 10, 15, 20, 50];

  // AR Camera
  static const double arFovHorizontal = 60.0; // degrees
  static const double arFovVertical = 45.0;   // degrees

  // Categories
  static const List<String> categories = [
    'General',
    'Art',
    'History',
    'Nature',
    'Business',
    'Tourism',
    'Education',
    'Entertainment',
    'Sports',
    'Food & Drink',
    'Technology',
    'Other',
  ];

  // 3D Model types
  static const List<Map<String, String>> modelTypes = [
    {'type': 'default',     'label': 'Default Marker',   'emoji': '📍'},
    {'type': 'gift',        'label': 'Gift Box',          'emoji': '🎁'},
    {'type': 'treasure',    'label': 'Treasure Chest',    'emoji': '🏆'},
    {'type': 'cube',        'label': 'Cube',              'emoji': '📦'},
    {'type': 'sphere',      'label': 'Sphere',            'emoji': '🔮'},
    {'type': 'logo',        'label': 'Company Logo',      'emoji': '🏢'},
    {'type': 'building',    'label': 'Building',          'emoji': '🏛️'},
    {'type': 'arrow',       'label': 'Arrow',             'emoji': '⬆️'},
    {'type': 'robot',       'label': 'Animated Robot',   'emoji': '🤖'},
  ];

  // Hive box names
  static const String locationsBox = 'ar_locations';
  static const String historyBox = 'visit_history';
  static const String settingsBox = 'settings';

  // Settings keys
  static const String keyDetectionRadius = 'detection_radius';
  static const String keyDarkMode = 'dark_mode';
  static const String keyMapsApiKey = 'maps_api_key';
}
