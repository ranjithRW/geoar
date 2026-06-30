import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import 'package:geoar/models/ar_location.dart';
import 'package:geoar/providers/ar_locations_provider.dart';
import 'package:geoar/providers/settings_provider.dart';
import 'package:geoar/screens/ar_camera_screen.dart';
import 'package:geoar/services/location_service.dart';
import 'package:geoar/themes/app_theme.dart';
import 'package:geoar/utils/ar_math.dart';
import 'package:geoar/utils/constants.dart';

class NearbyDetectorWidget extends StatefulWidget {
  const NearbyDetectorWidget({super.key});

  @override
  State<NearbyDetectorWidget> createState() => _NearbyDetectorWidgetState();
}

class _NearbyDetectorWidgetState extends State<NearbyDetectorWidget>
    with TickerProviderStateMixin {
  late final AnimationController _radarController;
  late final AnimationController _pulseController;
  late final AnimationController _textController;

  Timer? _nearbyTimer;

  @override
  void initState() {
    super.initState();

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    LocationService.instance.startTracking();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startNearbyTimer();
    });
  }

  void _startNearbyTimer() {
    _nearbyTimer?.cancel();
    _nearbyTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final radius = context.read<SettingsProvider>().detectionRadius;
      context.read<ArLocationsProvider>().updateNearby(radius);
    });
    final radius = context.read<SettingsProvider>().detectionRadius;
    context.read<ArLocationsProvider>().updateNearby(radius);
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    _textController.dispose();
    _nearbyTimer?.cancel();
    super.dispose();
  }

  String _emojiForModelType(String modelType) {
    for (final m in AppConstants.modelTypes) {
      if (m['type'] == modelType) return m['emoji'] ?? '📍';
    }
    return '📍';
  }

  Color _distanceBadgeColor(double distance, double radius) {
    if (distance <= radius) return const Color(0xFF4CAF50);
    if (distance <= radius * 3) return const Color(0xFFFF9800);
    return Colors.white70;
  }

  void _launchAR(
    BuildContext context,
    ArLocation location,
    List<ArLocation> allNearby,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => ArCameraScreen(
          location: location,
          nearbyLocations: allNearby,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.primary.withValues(alpha: 0.18),
            colorScheme.surface.withValues(alpha: 0.95),
            colorScheme.surface,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: StreamBuilder<Position>(
        stream: LocationService.instance.positionStream,
        builder: (context, snapshot) {
          final position =
              snapshot.data ?? LocationService.instance.currentPosition;

          return Consumer2<ArLocationsProvider, SettingsProvider>(
            builder: (context, locProvider, settingsProvider, _) {
              final nearbyResults = locProvider.nearbyLocations;
              final allLocations = locProvider.locations;
              final radius = settingsProvider.detectionRadius;

              NearbyResult? nearest;
              if (allLocations.isNotEmpty && position != null) {
                double minDist = double.infinity;
                for (final loc in allLocations) {
                  final d = LocationService.instance.distanceBetween(
                    position.latitude,
                    position.longitude,
                    loc.latitude,
                    loc.longitude,
                  );
                  if (d < minDist) {
                    minDist = d;
                    nearest =
                        NearbyResult(location: loc, distanceMeters: d);
                  }
                }
              }

              final allNearbyLocations =
                  nearbyResults.map((r) => r.location).toList();

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: size.height * 0.35,
                      child: _RadarSection(
                        radarController: _radarController,
                        pulseController: _pulseController,
                        position: position,
                        hasNearby: nearbyResults.isNotEmpty,
                        colorScheme: colorScheme,
                        radius: radius,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _StatusSection(
                      textController: _textController,
                      nearbyResults: nearbyResults,
                      nearest: nearest,
                      allLocations: allLocations,
                      colorScheme: colorScheme,
                    ),
                  ),
                  if (nearbyResults.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _NearbyCardsSection(
                        nearbyResults: nearbyResults,
                        allNearbyLocations: allNearbyLocations,
                        radius: radius,
                        colorScheme: colorScheme,
                        emojiForType: _emojiForModelType,
                        badgeColor: _distanceBadgeColor,
                        onLaunchAR: (loc) =>
                            _launchAR(context, loc, allNearbyLocations),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Radar Section ────────────────────────────────────────────────────────────

class _RadarSection extends StatelessWidget {
  final AnimationController radarController;
  final AnimationController pulseController;
  final Position? position;
  final bool hasNearby;
  final ColorScheme colorScheme;
  final double radius;

  const _RadarSection({
    required this.radarController,
    required this.pulseController,
    required this.position,
    required this.hasNearby,
    required this.colorScheme,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: radarController,
          builder: (context, _) {
            return CustomPaint(
              painter: _RadarPainter(
                progress: radarController.value,
                color: hasNearby
                    ? const Color(0xFF4CAF50)
                    : colorScheme.primary,
              ),
              size: const Size(240, 240),
            );
          },
        ),
        AnimatedBuilder(
          animation: pulseController,
          builder: (context, _) {
            final scale = 0.85 + pulseController.value * 0.15;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      hasNearby
                          ? const Color(0xFF4CAF50)
                          : colorScheme.primary,
                      hasNearby
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                          : colorScheme.primary.withValues(alpha: 0.3),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (hasNearby
                              ? const Color(0xFF4CAF50)
                              : colorScheme.primary)
                          .withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  hasNearby
                      ? Icons.location_on_rounded
                      : Icons.radar_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            );
          },
        ),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: _GpsInfoRow(
            position: position,
            colorScheme: colorScheme,
          ),
        ),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = color.withValues(alpha: 0.12);
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxRadius * i / 4, bgPaint);
    }

    final sweepAngle = progress * 2 * math.pi;
    final sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = color.withValues(alpha: 0.6);
    canvas.drawLine(
      center,
      Offset(
        center.dx + maxRadius * math.cos(sweepAngle - math.pi / 2),
        center.dy + maxRadius * math.sin(sweepAngle - math.pi / 2),
      ),
      sweepPaint,
    );

    final sweepGradientPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = SweepGradient(
        startAngle: sweepAngle - math.pi / 2 - 1.2,
        endAngle: sweepAngle - math.pi / 2,
        colors: [
          Colors.transparent,
          color.withValues(alpha: 0.2),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxRadius),
      sweepAngle - math.pi / 2 - 1.2,
      1.2,
      true,
      sweepGradientPaint,
    );

    for (int i = 0; i < 3; i++) {
      final ringProgress = ((progress + i / 3) % 1.0);
      final ringRadius = maxRadius * ringProgress;
      final opacity = (1.0 - ringProgress) * 0.4;
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color.withValues(alpha: opacity);
      canvas.drawCircle(center, ringRadius, ringPaint);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.progress != progress || old.color != color;
}

class _GpsInfoRow extends StatelessWidget {
  final Position? position;
  final ColorScheme colorScheme;

  const _GpsInfoRow({required this.position, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    if (position == null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gps_off_rounded,
                  size: 14, color: colorScheme.onErrorContainer),
              const SizedBox(width: 6),
              Text(
                'Acquiring GPS...',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 400.ms);
    }

    final accuracy = position!.accuracy.round();
    final accuracyColor = accuracy <= 5
        ? const Color(0xFF4CAF50)
        : accuracy <= 15
            ? const Color(0xFFFF9800)
            : const Color(0xFFF44336);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GlassContainer(
          borderRadius: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          opacity: 0.2,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.my_location_rounded,
                  size: 13, color: colorScheme.primary),
              const SizedBox(width: 5),
              Text(
                '${position!.latitude.toStringAsFixed(5)}, '
                '${position!.longitude.toStringAsFixed(5)}',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accuracyColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: accuracyColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.adjust_rounded, size: 12, color: accuracyColor),
              const SizedBox(width: 4),
              Text(
                '±${accuracy}m',
                style: TextStyle(
                  fontSize: 11,
                  color: accuracyColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0);
  }
}

// ─── Status Section ───────────────────────────────────────────────────────────

class _StatusSection extends StatelessWidget {
  final AnimationController textController;
  final List<NearbyResult> nearbyResults;
  final NearbyResult? nearest;
  final List<ArLocation> allLocations;
  final ColorScheme colorScheme;

  const _StatusSection({
    required this.textController,
    required this.nearbyResults,
    required this.nearest,
    required this.allLocations,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    if (nearbyResults.isNotEmpty) {
      return _ArAvailableBanner(
        count: nearbyResults.length,
        colorScheme: colorScheme,
      );
    }
    return _SearchingSection(
      textController: textController,
      nearest: nearest,
      allLocations: allLocations,
      colorScheme: colorScheme,
    );
  }
}

class _ArAvailableBanner extends StatelessWidget {
  final int count;
  final ColorScheme colorScheme;

  const _ArAvailableBanner({required this.count, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF4CAF50).withValues(alpha: 0.2),
              const Color(0xFF81C784).withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.view_in_ar_rounded,
                color: Color(0xFF4CAF50),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AR Available!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                  Text(
                    '$count AR ${count == 1 ? 'object' : 'objects'} nearby',
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 500.ms)
          .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1))
          .shimmer(duration: 1200.ms, delay: 300.ms),
    );
  }
}

class _SearchingSection extends StatelessWidget {
  final AnimationController textController;
  final NearbyResult? nearest;
  final List<ArLocation> allLocations;
  final ColorScheme colorScheme;

  const _SearchingSection({
    required this.textController,
    required this.nearest,
    required this.allLocations,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: textController,
            builder: (context, _) {
              return Opacity(
                opacity: 0.55 + textController.value * 0.45,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Searching nearby AR...',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (nearest != null) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.near_me_rounded,
                    size: 16,
                    color: colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Nearest: ${ArMath.formatDistance(nearest!.distanceMeters)} away',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: textController,
            builder: (context, _) {
              return Transform.translate(
                offset: Offset(
                    0, math.sin(textController.value * math.pi) * 4),
                child: Icon(
                  allLocations.isEmpty
                      ? Icons.add_location_alt_outlined
                      : Icons.directions_walk_rounded,
                  size: 52,
                  color: colorScheme.primary.withValues(alpha: 0.35),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            allLocations.isEmpty
                ? 'Create your first AR pin!'
                : 'Move closer to discover AR',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withValues(alpha: 0.45),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      )
          .animate()
          .fadeIn(duration: 600.ms)
          .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
    );
  }
}

// ─── Nearby Cards Section ─────────────────────────────────────────────────────

class _NearbyCardsSection extends StatelessWidget {
  final List<NearbyResult> nearbyResults;
  final List<ArLocation> allNearbyLocations;
  final double radius;
  final ColorScheme colorScheme;
  final String Function(String) emojiForType;
  final Color Function(double, double) badgeColor;
  final void Function(ArLocation) onLaunchAR;

  const _NearbyCardsSection({
    required this.nearbyResults,
    required this.allNearbyLocations,
    required this.radius,
    required this.colorScheme,
    required this.emojiForType,
    required this.badgeColor,
    required this.onLaunchAR,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Row(
            children: [
              Text(
                'Nearby AR',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${nearbyResults.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0),
        ),
        if (nearbyResults.length == 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _NearbyCard(
              result: nearbyResults.first,
              allNearbyLocations: allNearbyLocations,
              radius: radius,
              colorScheme: colorScheme,
              emojiForType: emojiForType,
              badgeColor: badgeColor,
              onLaunchAR: onLaunchAR,
              index: 0,
            ),
          )
        else
          SizedBox(
            height: 260,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              itemCount: nearbyResults.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 240,
                  child: _NearbyCard(
                    result: nearbyResults[index],
                    allNearbyLocations: allNearbyLocations,
                    radius: radius,
                    colorScheme: colorScheme,
                    emojiForType: emojiForType,
                    badgeColor: badgeColor,
                    onLaunchAR: onLaunchAR,
                    index: index,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _NearbyCard extends StatelessWidget {
  final NearbyResult result;
  final List<ArLocation> allNearbyLocations;
  final double radius;
  final ColorScheme colorScheme;
  final String Function(String) emojiForType;
  final Color Function(double, double) badgeColor;
  final void Function(ArLocation) onLaunchAR;
  final int index;

  const _NearbyCard({
    required this.result,
    required this.allNearbyLocations,
    required this.radius,
    required this.colorScheme,
    required this.emojiForType,
    required this.badgeColor,
    required this.onLaunchAR,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final location = result.location;
    final emoji = emojiForType(location.modelType);
    final distColor = badgeColor(result.distanceMeters, radius);
    final distLabel = ArMath.formatDistance(result.distanceMeters);

    return GlassContainer(
      borderRadius: 22,
      padding: const EdgeInsets.all(16),
      opacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child:
                      Text(emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      location.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: distColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: distColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.place_rounded, size: 12, color: distColor),
                    const SizedBox(width: 4),
                    Text(
                      distLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: distColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        colorScheme.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    location.category,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => onLaunchAR(location),
              icon: const Icon(Icons.view_in_ar_rounded, size: 18),
              label: const Text('Launch AR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: 80 * index))
        .fadeIn(duration: 500.ms)
        .slideX(
          begin: 0.15,
          end: 0,
          duration: 450.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
