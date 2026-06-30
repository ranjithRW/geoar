import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';
import 'package:photo_view/photo_view.dart';
import 'package:intl/intl.dart';
import 'package:geoar/models/ar_location.dart';
import 'package:geoar/providers/ar_locations_provider.dart';
import 'package:geoar/services/location_service.dart';
import 'package:geoar/utils/ar_math.dart';
import 'package:geoar/themes/app_theme.dart';
import 'package:geoar/utils/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ArCameraScreen
// ─────────────────────────────────────────────────────────────────────────────

class ArCameraScreen extends StatefulWidget {
  final ArLocation location;
  final List<ArLocation> nearbyLocations;

  const ArCameraScreen({
    super.key,
    required this.location,
    this.nearbyLocations = const [],
  });

  @override
  State<ArCameraScreen> createState() => _ArCameraScreenState();
}

class _ArCameraScreenState extends State<ArCameraScreen>
    with TickerProviderStateMixin {
  // ── Camera ──────────────────────────────────────────────────────────────
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraReady = false;

  // ── Sensors ─────────────────────────────────────────────────────────────
  double _compassHeading = 0;
  double _pitchDegrees = 0;
  double _accX = 0, _accY = 0, _accZ = 9.8;

  StreamSubscription? _compassSub;
  StreamSubscription? _accelerometerSub;
  StreamSubscription<Position>? _locationSub;

  // ── Location ─────────────────────────────────────────────────────────────
  Position? _currentPosition;

  // ── UI State ─────────────────────────────────────────────────────────────
  ArLocation? _selectedLocation;
  bool _showPopup = false;
  Timer? _nearbyTimer;

  // ── Animation ────────────────────────────────────────────────────────────
  late AnimationController _hudFadeController;

  @override
  void initState() {
    super.initState();

    _hudFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _initCamera();
    _initCompass();
    _initAccelerometer();
    _initLocation();

    // Record the visit for the primary location
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ArLocationsProvider>().recordVisit(widget.location);
      }
    });
  }

  // ── Camera Init ──────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      final back = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _isCameraReady = true);
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  // ── Compass ──────────────────────────────────────────────────────────────

  void _initCompass() {
    _compassSub = FlutterCompass.events?.listen((event) {
      if (!mounted) return;
      final heading = event.heading;
      if (heading != null) {
        setState(() => _compassHeading = ArMath.normalizeBearing(heading));
      }
    });
  }

  // ── Accelerometer ────────────────────────────────────────────────────────

  void _initAccelerometer() {
    _accelerometerSub = accelerometerEventStream(samplingPeriod: SensorInterval.normalInterval).listen((event) {
      if (!mounted) return;
      setState(() {
        _accX = event.x;
        _accY = event.y;
        _accZ = event.z;
        _pitchDegrees = ArMath.pitchFromAccelerometer(_accX, _accY, _accZ);
      });
    });
  }

  // ── Location ─────────────────────────────────────────────────────────────

  Future<void> _initLocation() async {
    // Get immediate snapshot
    _currentPosition = LocationService.instance.currentPosition;
    if (_currentPosition == null) {
      _currentPosition = await LocationService.instance.getCurrentPosition();
    }
    if (mounted) setState(() {});

    // Subscribe to live stream
    _locationSub = LocationService.instance.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() => _currentPosition = pos);
    });
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _accelerometerSub?.cancel();
    _locationSub?.cancel();
    _nearbyTimer?.cancel();
    _cameraController?.dispose();
    _hudFadeController.dispose();
    super.dispose();
  }

  // ── AR Computation ───────────────────────────────────────────────────────

  /// Returns the (screenX, screenY) pixel position for an AR location,
  /// or null if the location is outside the visible FOV.
  ({double x, double y})? _computeScreenPosition(
    ArLocation loc,
    double screenWidth,
    double screenHeight,
  ) {
    final pos = _currentPosition;
    if (pos == null) return null;

    final bearing = ArMath.bearing(
      pos.latitude, pos.longitude,
      loc.latitude, loc.longitude,
    );

    final angleDiff = ArMath.angleDiff(_compassHeading, bearing);

    // Cull objects outside ±1.5× FOV (allow slight off-screen to slide in)
    if (angleDiff.abs() > AppConstants.arFovHorizontal * 1.5) return null;

    final normX = ArMath.angleToScreenX(
      angleDiff,
      fovH: AppConstants.arFovHorizontal,
    );
    final normY = ArMath.pitchToScreenY(
      _pitchDegrees,
      fovV: AppConstants.arFovVertical,
    );

    return (x: normX * screenWidth, y: normY * screenHeight);
  }

  double _distanceTo(ArLocation loc) {
    final pos = _currentPosition;
    if (pos == null) return double.infinity;
    return LocationService.instance.distanceBetween(
      pos.latitude, pos.longitude,
      loc.latitude, loc.longitude,
    );
  }

  // ── UI Helpers ────────────────────────────────────────────────────────────

  Color _distanceColor(double meters) {
    if (meters < 15) return Colors.greenAccent;
    if (meters < 50) return Colors.orangeAccent;
    return Colors.white;
  }

  String _emojiForModelType(String modelType) {
    for (final m in AppConstants.modelTypes) {
      if (m['type'] == modelType) return m['emoji'] ?? '📍';
    }
    return '📍';
  }

  void _onMarkerTap(ArLocation loc) {
    context.read<ArLocationsProvider>().incrementClick(loc.id);
    setState(() {
      _selectedLocation = loc;
      _showPopup = true;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 1. Camera preview ───────────────────────────────────────────
          _buildCameraLayer(size),

          // ── 2. AR objects overlay ───────────────────────────────────────
          _buildArOverlay(size),

          // ── 3. HUD – top bar ────────────────────────────────────────────
          _buildHud(size),

          // ── 4. Distance indicator – bottom center ───────────────────────
          _buildDistanceIndicator(size),

          // ── 5. Content popup ────────────────────────────────────────────
          if (_showPopup && _selectedLocation != null)
            ArContentPopup(
              location: _selectedLocation!,
              distanceMeters: _distanceTo(_selectedLocation!),
              onClose: () => setState(() {
                _showPopup = false;
                _selectedLocation = null;
              }),
            ),
        ],
      ),
    );
  }

  // ── Camera Layer ─────────────────────────────────────────────────────────

  Widget _buildCameraLayer(Size size) {
    if (!_isCameraReady || _cameraController == null) {
      return Container(
        width: size.width,
        height: size.height,
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white54),
              SizedBox(height: 16),
              Text(
                'Initializing camera…',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize?.height ?? size.width,
          height: _cameraController!.value.previewSize?.width ?? size.height,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  // ── AR Overlay ───────────────────────────────────────────────────────────

  Widget _buildArOverlay(Size size) {
    final allLocations = [widget.location, ...widget.nearbyLocations];
    final markers = <Widget>[];

    for (final loc in allLocations) {
      final pos = _computeScreenPosition(loc, size.width, size.height);
      if (pos == null) continue;

      // Keep markers on-screen edges when close to boundary
      final markerSize = 80.0;
      final left = pos.x - markerSize / 2;
      final top = pos.y - markerSize / 2;

      // Only render if at least partially visible
      if (left > size.width + markerSize || left < -markerSize * 1.5) continue;

      final isPrimary = loc.id == widget.location.id;
      final distance = _distanceTo(loc);

      markers.add(
        Positioned(
          left: left.clamp(-markerSize / 2, size.width - markerSize / 2),
          top: top.clamp(80.0, size.height - markerSize - 100),
          child: _ArMarker(
            location: loc,
            emoji: _emojiForModelType(loc.modelType),
            isPrimary: isPrimary,
            distanceMeters: distance,
            onTap: () => _onMarkerTap(loc),
          ),
        ),
      );
    }

    return Stack(children: markers);
  }

  // ── HUD Top Bar ──────────────────────────────────────────────────────────

  Widget _buildHud(Size size) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _hudFadeController,
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            bottom: 12,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xCC000000), Colors.transparent],
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),

              // Title + category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.location.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        widget.location.category,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Compass indicator
              _CompassWidget(heading: _compassHeading),
            ],
          ),
        ),
      ),
    );
  }

  // ── Distance Indicator ───────────────────────────────────────────────────

  Widget _buildDistanceIndicator(Size size) {
    final dist = _distanceTo(widget.location);
    final isInfinity = dist == double.infinity;
    final distText = isInfinity
        ? 'Locating…'
        : ArMath.formatDistance(dist);
    final color = isInfinity ? Colors.white54 : _distanceColor(dist);

    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 24,
      left: 0,
      right: 0,
      child: Center(
        child: GlassContainer(
          borderRadius: 30,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          opacity: 0.25,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.near_me_rounded, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                distText,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              if (!isInfinity && dist < 15) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    'IN RANGE',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.3, end: 0),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ArMarker  (private widget)
// ─────────────────────────────────────────────────────────────────────────────

class _ArMarker extends StatefulWidget {
  final ArLocation location;
  final String emoji;
  final bool isPrimary;
  final double distanceMeters;
  final VoidCallback onTap;

  const _ArMarker({
    required this.location,
    required this.emoji,
    required this.isPrimary,
    required this.distanceMeters,
    required this.onTap,
  });

  @override
  State<_ArMarker> createState() => _ArMarkerState();
}

class _ArMarkerState extends State<_ArMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _floatAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // Sine-based vertical float
    _floatAnim = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Scale pulse
    _pulseAnim = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.08)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 50),
      TweenSequenceItem(
          tween: Tween(begin: 1.08, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 50),
    ]).animate(_animController);

    // Slow rotation for non-primary markers
    _rotateAnim = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markerSize = widget.isPrimary ? 80.0 : 64.0;
    final fontSize = widget.isPrimary ? 32.0 : 26.0;
    final ringColor =
        widget.isPrimary ? const Color(0xFF6C63FF) : Colors.white54;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnim.value),
          child: Transform.rotate(
            angle: widget.isPrimary ? 0.0 : _rotateAnim.value,
            child: Transform.scale(
              scale: _pulseAnim.value,
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: markerSize,
          height: markerSize + 32, // extra for label below
          child: Column(
            children: [
              // ── Marker body ─────────────────────────────────────────────
              Container(
                width: markerSize,
                height: markerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.55),
                  border: Border.all(color: ringColor, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: ringColor.withValues(alpha: 0.5),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.emoji,
                    style: TextStyle(fontSize: fontSize),
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // ── Distance label ──────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  widget.distanceMeters == double.infinity
                      ? '…'
                      : ArMath.formatDistance(widget.distanceMeters),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CompassWidget
// ─────────────────────────────────────────────────────────────────────────────

class _CompassWidget extends StatelessWidget {
  final double heading;

  const _CompassWidget({required this.heading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -heading * (math.pi / 180),
            child: const Icon(Icons.navigation,
                color: Colors.redAccent, size: 20),
          ),
          Positioned(
            bottom: 6,
            child: Text(
              '${heading.round()}°',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ArContentPopup
// ─────────────────────────────────────────────────────────────────────────────

class ArContentPopup extends StatefulWidget {
  final ArLocation location;
  final VoidCallback onClose;
  final double distanceMeters;

  const ArContentPopup({
    super.key,
    required this.location,
    required this.onClose,
    required this.distanceMeters,
  });

  @override
  State<ArContentPopup> createState() => _ArContentPopupState();
}

class _ArContentPopupState extends State<ArContentPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(
        parent: _entryController, curve: Curves.easeOut);
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _entryController.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final distText = widget.distanceMeters == double.infinity
        ? 'Unknown distance'
        : ArMath.formatDistance(widget.distanceMeters);

    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            constraints: BoxConstraints(maxHeight: screenHeight * 0.72),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black54, blurRadius: 40, spreadRadius: 2)
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Drag handle ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // ── Header ───────────────────────────────────────────────
                _buildHeader(distText),

                // ── Scrollable body ──────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: _buildBody(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String distText) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6C63FF).withValues(alpha: 0.3),
            const Color(0xFF03DAC6).withValues(alpha: 0.15),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location icon + content badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.location.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (widget.location.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    widget.location.subtitle,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // Distance chip
                    _Chip(
                      icon: Icons.near_me_rounded,
                      label: distText,
                      color: widget.distanceMeters < 15
                          ? Colors.greenAccent
                          : widget.distanceMeters < 50
                              ? Colors.orangeAccent
                              : Colors.white70,
                    ),
                    // Category chip
                    _Chip(
                      icon: Icons.label_outline_rounded,
                      label: widget.location.category,
                      color: const Color(0xFF6C63FF),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Close button
          GestureDetector(
            onTap: _dismiss,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white12,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final loc = widget.location;
    final dateStr = DateFormat('MMM d, yyyy').format(loc.createdDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description
        if (loc.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            loc.description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ],

        // Category + created date row
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                color: Colors.white38, size: 13),
            const SizedBox(width: 5),
            Text(
              'Created $dateStr',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Text content ────────────────────────────────────────────────
        if (loc.hasText) ...[
          GlassContainer(
            borderRadius: 16,
            padding: const EdgeInsets.all(14),
            opacity: 0.12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.message_outlined,
                    color: Color(0xFF6C63FF), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    loc.textMessage!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ── Image content ───────────────────────────────────────────────
        if (loc.hasImage) ...[
          const Text(
            'Photo',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _openImageFullscreen(context, loc.imagePath!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Image.file(
                    File(loc.imagePath!),
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: Colors.white10,
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: Colors.white38, size: 40),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.fullscreen,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ── Video content ───────────────────────────────────────────────
        if (loc.hasVideo) ...[
          const Text(
            'Video',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          VideoPlayerWidget(videoPath: loc.videoPath!),
        ],
      ],
    );
  }

  void _openImageFullscreen(BuildContext context, String imagePath) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              PhotoView(
                imageProvider: FileImage(File(imagePath)),
                backgroundDecoration:
                    const BoxDecoration(color: Colors.transparent),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VideoPlayerWidget
// ─────────────────────────────────────────────────────────────────────────────

class VideoPlayerWidget extends StatefulWidget {
  final String videoPath;

  const VideoPlayerWidget({super.key, required this.videoPath});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _isPlaying = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.file(File(widget.videoPath));
      await _controller.initialize();
      _controller.addListener(_onVideoUpdate);
      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e) {
      debugPrint('Video init error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onVideoUpdate() {
    if (!mounted) return;
    final isPlaying = _controller.value.isPlaying;
    if (isPlaying != _isPlaying) {
      setState(() => _isPlaying = isPlaying);
    }

    // Auto-replay at end
    if (_controller.value.position >= _controller.value.duration &&
        _controller.value.duration > Duration.zero) {
      _controller.seekTo(Duration.zero);
      _controller.pause();
    }
  }

  void _togglePlay() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
      _scheduleHideControls();
    }
    setState(() => _showControls = true);
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onTapVideo() {
    setState(() => _showControls = !_showControls);
    if (_showControls && _controller.value.isPlaying) {
      _scheduleHideControls();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => _FullscreenVideoPage(controller: _controller),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller.removeListener(_onVideoUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_outlined,
                  color: Colors.white38, size: 40),
              SizedBox(height: 8),
              Text('Video unavailable',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: GestureDetector(
            onTap: _onTapVideo,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Video frame
                VideoPlayer(_controller),

                // Controls overlay
                AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Progress bar
                        ValueListenableBuilder(
                          valueListenable: _controller,
                          builder: (_, VideoPlayerValue value, __) {
                            final pos = value.position.inMilliseconds.toDouble();
                            final total = value.duration.inMilliseconds
                                .toDouble()
                                .clamp(1.0, double.infinity);
                            return Column(
                              children: [
                                SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 2,
                                    thumbColor: Colors.white,
                                    activeTrackColor: const Color(0xFF6C63FF),
                                    inactiveTrackColor: Colors.white24,
                                    overlayColor:
                                        const Color(0xFF6C63FF).withValues(alpha: 0.3),
                                  ),
                                  child: Slider(
                                    value: pos.clamp(0.0, total),
                                    min: 0,
                                    max: total,
                                    onChanged: (v) {
                                      _controller.seekTo(
                                          Duration(milliseconds: v.round()));
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
                                  child: Row(
                                    children: [
                                      // Play/Pause
                                      GestureDetector(
                                        onTap: _togglePlay,
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: Colors.white24,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _isPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      // Duration text
                                      Text(
                                        '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),

                                      const Spacer(),

                                      // Fullscreen button
                                      GestureDetector(
                                        onTap: _openFullscreen,
                                        child: const Icon(
                                          Icons.fullscreen_rounded,
                                          color: Colors.white70,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Centre play button (when paused and controls visible)
                if (!_isPlaying && _showControls)
                  GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white54, width: 2),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 36),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FullscreenVideoPage
// ─────────────────────────────────────────────────────────────────────────────

class _FullscreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;

  const _FullscreenVideoPage({required this.controller});

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onTap() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: widget.controller.value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                color: Colors.black26,
                child: SafeArea(
                  child: Column(
                    children: [
                      // Top – close
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: const Icon(Icons.fullscreen_exit_rounded,
                              color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),

                      const Spacer(),

                      // Bottom controls
                      ValueListenableBuilder(
                        valueListenable: widget.controller,
                        builder: (_, VideoPlayerValue value, __) {
                          final pos = value.position.inMilliseconds.toDouble();
                          final total = value.duration.inMilliseconds
                              .toDouble()
                              .clamp(1.0, double.infinity);
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 3,
                                  thumbColor: Colors.white,
                                  activeTrackColor: const Color(0xFF6C63FF),
                                  inactiveTrackColor: Colors.white24,
                                ),
                                child: Slider(
                                  value: pos.clamp(0.0, total),
                                  min: 0,
                                  max: total,
                                  onChanged: (v) => widget.controller.seekTo(
                                      Duration(milliseconds: v.round())),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        value.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                      onPressed: () {
                                        value.isPlaying
                                            ? widget.controller.pause()
                                            : widget.controller.play();
                                        setState(() {});
                                        _scheduleHide();
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_fmt(value.position)} / ${_fmt(value.duration)}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Chip  (small info chip used in popup header)
// ─────────────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
