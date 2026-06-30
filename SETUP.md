# GeoAR – Setup Guide

## Prerequisites

- Flutter SDK (stable) ≥ 3.0
- Android Studio / Xcode
- A Google Maps API key (Maps SDK for Android + Maps SDK for iOS)
- Physical device recommended (GPS + compass + camera required for full AR)

---

## 1. Install dependencies

```bash
cd geoar
flutter pub get
```

---

## 2. Google Maps API Key

### Android
Open `android/app/src/main/AndroidManifest.xml` and replace:
```xml
<meta-data android:name="com.google.android.geo.API_KEY"
           android:value="YOUR_MAPS_API_KEY"/>
```

### iOS
Open `ios/Runner/Info.plist` and replace:
```xml
<key>GMSApiKey</key>
<string>YOUR_MAPS_API_KEY</string>
```
Also add to `ios/Runner/AppDelegate.swift`:
```swift
import GoogleMaps
// In application(_:didFinishLaunchingWithOptions:):
GMSServices.provideAPIKey("YOUR_MAPS_API_KEY")
```

Get a key at: https://console.cloud.google.com → APIs & Services → Credentials
Enable: **Maps SDK for Android**, **Maps SDK for iOS**

---

## 3. Inter Font (optional but recommended)

Download Inter font from https://fonts.google.com/specimen/Inter and place the `.ttf` files in:
```
assets/fonts/
  Inter-Regular.ttf
  Inter-Medium.ttf
  Inter-SemiBold.ttf
  Inter-Bold.ttf
```

If you skip this, remove the `fonts:` block from `pubspec.yaml` and remove `fontFamily: 'Inter'` from `lib/themes/app_theme.dart`.

---

## 4. Android minimum SDK

In `android/app/build.gradle`, `minSdk` is set to **23** (Android 6.0). This is required by:
- `camera` package
- `geolocator` package
- `sensors_plus` package

---

## 5. iOS permissions

All required permission strings are already in `ios/Runner/Info.plist`:
- Camera
- Location (when in use + always)
- Photo library
- Motion sensors
- Microphone

---

## 6. Run the app

```bash
# Android
flutter run

# iOS (requires macOS + Xcode)
cd ios && pod install && cd ..
flutter run
```

---

## 7. Architecture overview

```
lib/
  main.dart                 # App entry point, MultiProvider setup
  models/
    ar_location.dart        # Hive model for AR locations
    visit_history.dart      # Hive model for visit history
  services/
    database_service.dart   # Hive offline storage singleton
    location_service.dart   # GPS tracking, proximity detection
    media_service.dart      # Image/video pick, compress, store
  providers/
    ar_locations_provider.dart  # ChangeNotifier: CRUD, search, nearby
    settings_provider.dart      # ChangeNotifier: radius, dark mode
  screens/
    home_screen.dart        # Bottom nav + FAB
    create_ar_screen.dart   # Create/edit AR location form
    map_screen.dart         # Google Maps with all markers
    ar_camera_screen.dart   # AR overlay (camera + GPS + compass)
    search_screen.dart      # Search + filter locations
    history_screen.dart     # Visit history log
    settings_screen.dart    # App settings + data export/import
  widgets/
    nearby_detector_widget.dart  # Radar UI + nearby cards (home tab)
    ar_location_card.dart        # Reusable location list card
  themes/
    app_theme.dart          # Material Design 3 themes + GlassContainer
  utils/
    ar_math.dart            # GPS→bearing→screen position math
    constants.dart          # App-wide constants
```

---

## 8. AR Camera – how it works

The AR camera uses a **custom camera + GPS** approach (no ARCore/ARKit required):

1. Camera feed fills the screen via the `camera` package
2. `flutter_compass` gives the device's magnetic heading (0–360°)
3. `sensors_plus` accelerometer gives device tilt (pitch)
4. `geolocator` gives current GPS position
5. For each saved AR location:
   - True **bearing** from user → location is calculated
   - **Angle difference** between compass heading and bearing = horizontal offset
   - Offset mapped to **screen X** via field-of-view math (60° default)
   - Accelerometer **pitch** mapped to **screen Y** (45° vertical FOV)
6. An animated AR marker widget is placed at `(screenX, screenY)` over the camera feed
7. Tapping the marker opens a rich popup with text/image/video content

Works on any device with GPS + compass. No ARCore/ARKit device requirements.

---

## 9. Future enhancements (architecture is ready)

- Firebase Auth + Firestore sync → add to `DatabaseService`
- Cloud Storage for media → extend `MediaService`
- Push notifications → add Firebase Messaging
- AI-generated 3D models → swap `modelType` emoji for real GLB via `model_viewer_plus`
- QR code sharing → add `qr_flutter` + `mobile_scanner`
- Analytics → add Firebase Analytics events in providers

---

## 10. Known limitations

- AR accuracy depends on device compass quality (can drift indoors)
- Video files are stored locally; large videos consume storage
- Google Maps requires internet; offline map tiles not included
- Background location requires explicit user permission on iOS
