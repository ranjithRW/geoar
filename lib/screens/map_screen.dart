import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:geoar/providers/ar_locations_provider.dart';
import 'package:geoar/models/ar_location.dart';
import 'package:geoar/services/location_service.dart';
import 'package:geoar/themes/app_theme.dart';
import 'package:geoar/screens/ar_camera_screen.dart';
import 'package:geoar/screens/create_ar_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  bool _isLoadingMarkers = false;

  static const CameraPosition _defaultCamera = CameraPosition(
    target: LatLng(20.5937, 78.9629),
    zoom: 5,
  );

  final Map<String, Color> _categoryColors = {
    'Nature': const Color(0xFF4CAF50),
    'History': const Color(0xFF795548),
    'Art': const Color(0xFFE91E63),
    'Science': const Color(0xFF2196F3),
    'Food': const Color(0xFFFF9800),
    'Sports': const Color(0xFF9C27B0),
    'Music': const Color(0xFF00BCD4),
    'Architecture': const Color(0xFF607D8B),
    'Other': const Color(0xFF9E9E9E),
  };

  Color _colorForCategory(String category) {
    return _categoryColors[category] ?? const Color(0xFF9E9E9E);
  }

  // FIX: BitmapDescriptor.defaultMarkerWithHue requires a double hue (0–360).
  // Derive hue from the category colour via HSLColor.
  double _hueForCategory(String category) {
    final color = _colorForCategory(category);
    final hslColor = HSLColor.fromColor(color);
    return hslColor.hue;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildMarkers());
  }

  Future<void> _buildMarkers() async {
    if (!mounted) return;
    setState(() => _isLoadingMarkers = true);

    final provider = context.read<ArLocationsProvider>();
    final locations = provider.locations;
    final Set<Marker> newMarkers = {};

    for (final loc in locations) {
      final hue = _hueForCategory(loc.category);
      final icon = BitmapDescriptor.defaultMarkerWithHue(hue);
      final marker = Marker(
        markerId: MarkerId(loc.id),
        position: LatLng(loc.latitude, loc.longitude),
        icon: icon,
        infoWindow: InfoWindow(
          title: loc.title,
          // FIX: loc.category is non-nullable (late String) — no null check needed.
          snippet: loc.category,
        ),
        onTap: () => _showLocationBottomSheet(loc),
      );
      newMarkers.add(marker);
    }

    if (mounted) {
      setState(() {
        _markers
          ..clear()
          ..addAll(newMarkers);
        _isLoadingMarkers = false;
      });
    }
  }

  double? _distanceTo(ArLocation loc) {
    final pos = LocationService.instance.currentPosition;
    if (pos == null) return null;
    return Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      loc.latitude,
      loc.longitude,
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  void _showLocationBottomSheet(ArLocation loc) {
    final distance = _distanceTo(loc);
    final dateStr = DateFormat('MMM d, yyyy').format(loc.createdDate);
    final colorAccent = _colorForCategory(loc.category);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LocationBottomSheet(
        loc: loc,
        distance: distance,
        dateStr: dateStr,
        colorAccent: colorAccent,
        onNavigate: () {
          Navigator.pop(ctx);
          _openNavigation(loc);
        },
        onOpenAr: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ArCameraScreen(location: loc)),
          );
        },
        onEdit: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CreateArScreen(location: loc)),
          ).then((_) => _buildMarkers());
        },
        onDelete: () {
          Navigator.pop(ctx);
          _confirmDelete(loc);
        },
        formatDistance: _formatDistance,
      ),
    );
  }

  Future<void> _openNavigation(ArLocation loc) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${loc.latitude},${loc.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps application')),
        );
      }
    }
  }

  void _confirmDelete(ArLocation loc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Location'),
        content: Text(
          'Are you sure you want to delete "${loc.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              context.read<ArLocationsProvider>().deleteLocation(loc.id);
              Navigator.pop(ctx);
              _buildMarkers();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _centerOnUser() async {
    final pos = LocationService.instance.currentPosition;
    if (pos == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location not available')),
        );
      }
      return;
    }
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'AR Map',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GlassContainer(
              borderRadius: 24,
              padding: EdgeInsets.zero,
              child: IconButton(
                icon: const Icon(Icons.refresh_outlined),
                onPressed: _buildMarkers,
                tooltip: 'Refresh markers',
              ),
            ),
          ),
        ],
      ),
      body: Consumer<ArLocationsProvider>(
        builder: (context, provider, _) {
          if (provider.locations.isEmpty) {
            return _EmptyMapState(onRefresh: _buildMarkers);
          }
          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: _defaultCamera,
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                onMapCreated: (controller) {
                  _mapController = controller;
                  final pos = LocationService.instance.currentPosition;
                  if (pos != null) {
                    controller.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: LatLng(pos.latitude, pos.longitude),
                          zoom: 13,
                        ),
                      ),
                    );
                  }
                },
              ),
              if (_isLoadingMarkers)
                Positioned(
                  top: kToolbarHeight + MediaQuery.of(context).padding.top + 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GlassContainer(
                      borderRadius: 24,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Loading markers…',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 24,
                right: 16,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'fab_legend',
                      onPressed: () => _showLegend(context),
                      tooltip: 'Category legend',
                      child: const Icon(Icons.layers_outlined),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton(
                      heroTag: 'fab_center',
                      onPressed: _centerOnUser,
                      tooltip: 'My location',
                      child: const Icon(Icons.my_location),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 24,
                left: 16,
                child: GlassContainer(
                  borderRadius: 16,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.place_outlined,
                          size: 16, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${provider.locations.length} location${provider.locations.length == 1 ? '' : 's'}',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLegend(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Category Legend',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: _categoryColors.entries.map((e) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, color: e.value, size: 20),
                    const SizedBox(width: 4),
                    Text(e.key,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom Sheet ────────────────────────────────────────────────────────────

class _LocationBottomSheet extends StatelessWidget {
  final ArLocation loc;
  final double? distance;
  final String dateStr;
  final Color colorAccent;
  final VoidCallback onNavigate;
  final VoidCallback onOpenAr;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(double) formatDistance;

  const _LocationBottomSheet({
    required this.loc,
    required this.distance,
    required this.dateStr,
    required this.colorAccent,
    required this.onNavigate,
    required this.onOpenAr,
    required this.onEdit,
    required this.onDelete,
    required this.formatDistance,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.location_on, color: colorAccent, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.title,
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // FIX: loc.subtitle is non-nullable (late String) — guard with isEmpty.
                    if (loc.subtitle.isNotEmpty)
                      Text(
                        loc.subtitle,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // FIX: loc.category is non-nullable — always show it.
              _InfoChip(
                  icon: Icons.category_outlined,
                  label: loc.category,
                  color: colorAccent),
              if (distance != null)
                _InfoChip(
                    icon: Icons.near_me_outlined,
                    label: formatDistance(distance!),
                    color: cs.secondary),
              _InfoChip(
                  icon: Icons.calendar_today_outlined,
                  label: dateStr,
                  color: cs.tertiary),
            ],
          ),
          // FIX: loc.description is non-nullable — guard with isEmpty.
          if (loc.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              loc.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.navigation_outlined,
                  label: 'Navigate',
                  color: cs.primary,
                  onTap: onNavigate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.view_in_ar_outlined,
                  label: 'Open AR',
                  color: colorAccent,
                  onTap: onOpenAr,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  color: cs.secondary,
                  outlined: true,
                  onTap: onEdit,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  color: cs.error,
                  outlined: true,
                  onTap: onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _EmptyMapState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyMapState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.map_outlined,
                  size: 60, color: cs.onPrimaryContainer),
            ),
            const SizedBox(height: 24),
            Text(
              'No Locations Yet',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first AR location to see it on the map.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 18),
        label: Text(label, style: TextStyle(color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
