import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:geoar/utils/constants.dart';
import 'package:geoar/models/ar_location.dart';
import 'package:geoar/providers/ar_locations_provider.dart';
import 'package:geoar/services/location_service.dart';
import 'package:geoar/screens/ar_camera_screen.dart';
import 'package:geoar/screens/create_ar_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    context.read<ArLocationsProvider>().setSearchQuery(_searchController.text);
  }

  void _clearSearch() {
    _searchController.clear();
    // FIX: setFilterCategory now accepts null (provider updated accordingly).
    context.read<ArLocationsProvider>().setSearchQuery('');
    context.read<ArLocationsProvider>().setFilterCategory(null);
    _searchFocus.unfocus();
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

  void _showItemOptions(BuildContext context, ArLocation loc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        content: const Text('What would you like to do?'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CreateArScreen(location: loc)),
              );
            },
          ),
          TextButton.icon(
            icon: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            label: Text('Delete',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDelete(context, loc);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, ArLocation loc) {
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
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            _SearchHeader(
              controller: _searchController,
              focusNode: _searchFocus,
              onClear: _clearSearch,
            ),
            const _CategoryFilterRow(),
            const Divider(height: 1),
            Expanded(
              child: Consumer<ArLocationsProvider>(
                builder: (context, provider, _) {
                  final results = provider.filteredLocations;
                  if (results.isEmpty) {
                    return _EmptySearchState(
                      // FIX: provider.filterCategory is now a non-nullable String
                      // ('All' means no filter).  Check against 'All' instead of null.
                      hasQuery: provider.searchQuery.isNotEmpty ||
                          provider.filterCategory != 'All',
                      onClear: _clearSearch,
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final loc = results[index];
                      final distance = _distanceTo(loc);
                      return _SearchResultItem(
                        key: ValueKey(loc.id),
                        location: loc,
                        index: index,
                        distance: distance,
                        formatDistance: _formatDistance,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ArCameraScreen(location: loc)),
                        ),
                        onLongPress: () => _showItemOptions(context, loc),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Search Header ────────────────────────────────────────────────────────────

class _SearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClear;

  const _SearchHeader({
    required this.controller,
    required this.focusNode,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Discover',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
          ),
          const SizedBox(height: 12),
          SearchBar(
            controller: controller,
            focusNode: focusNode,
            hintText: 'Search AR locations…',
            leading: Icon(Icons.search, color: cs.onSurfaceVariant),
            trailing: [
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, value, __) => value.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: onClear,
                        tooltip: 'Clear search',
                      )
                    : const SizedBox.shrink(),
              ),
            ],
            elevation: const WidgetStatePropertyAll(2),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHigh),
          ),
        ],
      ),
    );
  }
}

// ─── Category Filter Row ──────────────────────────────────────────────────────

class _CategoryFilterRow extends StatelessWidget {
  const _CategoryFilterRow();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final categories = ['All', ...AppConstants.categories];

    return Consumer<ArLocationsProvider>(
      builder: (context, provider, _) {
        // FIX: filterCategory is now always a non-nullable String ('All' == no filter).
        final selected = provider.filterCategory;
        return SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isAll = cat == 'All';
              final isSelected = selected == cat;
              return FilterChip(
                label: Text(cat),
                selected: isSelected,
                onSelected: (_) {
                  // Pass null for 'All' so provider resets to 'All'.
                  provider.setFilterCategory(isAll ? null : cat);
                },
                selectedColor: cs.primaryContainer,
                checkmarkColor: cs.onPrimaryContainer,
                labelStyle: TextStyle(
                  color: isSelected
                      ? cs.onPrimaryContainer
                      : cs.onSurfaceVariant,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide(
                  color: isSelected
                      ? cs.primary.withValues(alpha: 0.4)
                      : cs.outline.withValues(alpha: 0.3),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ─── Search Result Item ───────────────────────────────────────────────────────

class _SearchResultItem extends StatelessWidget {
  final ArLocation location;
  final int index;
  final double? distance;
  final String Function(double) formatDistance;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SearchResultItem({
    super.key,
    required this.location,
    required this.index,
    required this.distance,
    required this.formatDistance,
    required this.onTap,
    required this.onLongPress,
  });

  Color _categoryColor(BuildContext context, String category) {
    final colors = {
      'Nature': const Color(0xFF4CAF50),
      'History': const Color(0xFF795548),
      'Art': const Color(0xFFE91E63),
      'Science': const Color(0xFF2196F3),
      'Food': const Color(0xFFFF9800),
      'Sports': const Color(0xFF9C27B0),
      'Music': const Color(0xFF00BCD4),
      'Architecture': const Color(0xFF607D8B),
    };
    return colors[category] ??
        Theme.of(context).colorScheme.secondary;
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Nature':
        return Icons.park_outlined;
      case 'History':
        return Icons.account_balance_outlined;
      case 'Art':
        return Icons.palette_outlined;
      case 'Science':
        return Icons.science_outlined;
      case 'Food':
        return Icons.restaurant_outlined;
      case 'Sports':
        return Icons.sports_outlined;
      case 'Music':
        return Icons.music_note_outlined;
      case 'Architecture':
        return Icons.architecture_outlined;
      default:
        return Icons.location_on_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // FIX: location.category is non-nullable — no null check needed.
    final accent = _categoryColor(context, location.category);
    final icon = _categoryIcon(location.category);
    final dateStr =
        DateFormat('MMM d, yyyy').format(location.createdDate);

    return Animate(
      effects: [
        FadeEffect(
          delay: Duration(milliseconds: index * 40),
          duration: const Duration(milliseconds: 350),
        ),
        SlideEffect(
          delay: Duration(milliseconds: index * 40),
          duration: const Duration(milliseconds: 350),
          begin: const Offset(0, 0.08),
          end: Offset.zero,
          curve: Curves.easeOut,
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: accent, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // FIX: location.subtitle is non-nullable — guard with isEmpty.
                        if (location.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            location.subtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: [
                            // FIX: location.category is non-nullable — always show it.
                            _MiniChip(
                              label: location.category,
                              color: accent,
                            ),
                            if (distance != null)
                              _MiniChip(
                                label: formatDistance(distance!),
                                color: cs.secondary,
                                icon: Icons.near_me_outlined,
                              ),
                            _MiniChip(
                              label: dateStr,
                              color: cs.onSurfaceVariant,
                              icon: Icons.schedule_outlined,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.view_in_ar_outlined,
                          color: cs.primary, size: 20),
                      const SizedBox(height: 4),
                      Icon(Icons.chevron_right,
                          color: cs.onSurfaceVariant, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Mini Chip ────────────────────────────────────────────────────────────────

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _MiniChip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptySearchState extends StatelessWidget {
  final bool hasQuery;
  final VoidCallback onClear;

  const _EmptySearchState({required this.hasQuery, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasQuery
                    ? Icons.search_off_outlined
                    : Icons.travel_explore_outlined,
                size: 52,
                color: cs.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              hasQuery ? 'No Results Found' : 'Start Exploring',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              hasQuery
                  ? 'Try a different search term or remove filters to see more locations.'
                  : 'Search for AR locations by name or filter by category.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (hasQuery) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_all_outlined),
                label: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: 400.ms,
          curve: Curves.easeOut,
        );
  }
}
