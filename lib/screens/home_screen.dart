import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:geoar/providers/ar_locations_provider.dart';
import 'package:geoar/screens/create_ar_screen.dart';
import 'package:geoar/screens/map_screen.dart';
import 'package:geoar/screens/search_screen.dart';
import 'package:geoar/screens/history_screen.dart';
import 'package:geoar/screens/settings_screen.dart';
import 'package:geoar/widgets/nearby_detector_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late final PageController _pageController;
  late final AnimationController _fabAnimController;

  static const _navItems = [
    _NavItem(icon: Icons.explore_outlined, selectedIcon: Icons.explore, label: 'Explore'),
    _NavItem(icon: Icons.map_outlined, selectedIcon: Icons.map, label: 'Map'),
    _NavItem(icon: Icons.search_outlined, selectedIcon: Icons.search, label: 'Search'),
    _NavItem(icon: Icons.history_outlined, selectedIcon: Icons.history, label: 'History'),
    _NavItem(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ArLocationsProvider>().loadLocations();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fabAnimController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    _pageController.jumpToPage(index);

    final showFab = index == 0 || index == 1;
    if (showFab) {
      _fabAnimController.forward();
    } else {
      _fabAnimController.reverse();
    }
  }

  void _navigateToCreate() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const CreateArScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true,
      appBar: _buildAppBar(colorScheme),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          NearbyDetectorWidget(),
          MapScreen(),
          SearchScreen(),
          HistoryScreen(),
          SettingsScreen(),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(
          parent: _fabAnimController,
          curve: Curves.easeOutBack,
        ),
        child: FloatingActionButton.extended(
          onPressed: _navigateToCreate,
          icon: const Icon(Icons.add_location_alt_rounded),
          label: const Text('New AR Pin'),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 6,
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: 600.ms)
            .slideY(
              begin: 0.3,
              end: 0,
              duration: 400.ms,
              delay: 600.ms,
              curve: Curves.easeOutBack,
            ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildNavBar(colorScheme),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme colorScheme) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.12),
              colorScheme.secondary.withValues(alpha: 0.06),
              Colors.transparent,
            ],
          ),
        ),
      ),
      title: _GeoArTitle(colorScheme: colorScheme)
          .animate()
          .fadeIn(duration: 500.ms)
          .slideX(
            begin: -0.2,
            end: 0,
            duration: 500.ms,
            curve: Curves.easeOutCubic,
          ),
      actions: [
        Consumer<ArLocationsProvider>(
          builder: (context, provider, _) {
            final count = provider.locations.length;
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _LocationCountBadge(count: count, colorScheme: colorScheme),
            ).animate().fadeIn(duration: 500.ms, delay: 200.ms);
          },
        ),
      ],
    );
  }

  Widget _buildNavBar(ColorScheme colorScheme) {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onNavTap,
      backgroundColor: colorScheme.surface.withValues(alpha: 0.95),
      surfaceTintColor: colorScheme.primary,
      elevation: 8,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.2),
      animationDuration: const Duration(milliseconds: 300),
      destinations: _navItems
          .map(
            (item) => NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon, color: colorScheme.primary),
              label: item.label,
              tooltip: item.label,
            ),
          )
          .toList(),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 300.ms)
        .slideY(
          begin: 0.2,
          end: 0,
          duration: 400.ms,
          delay: 300.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ─── Internal data class ──────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

// ─── AppBar title widget ──────────────────────────────────────────────────────

class _GeoArTitle extends StatelessWidget {
  final ColorScheme colorScheme;

  const _GeoArTitle({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colorScheme.primary, colorScheme.secondary],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.location_on_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [colorScheme.primary, colorScheme.secondary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(bounds),
          child: const Text(
            'GeoAR',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Location count chip ──────────────────────────────────────────────────────

class _LocationCountBadge extends StatelessWidget {
  final int count;
  final ColorScheme colorScheme;

  const _LocationCountBadge({required this.count, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.pin_drop_rounded,
            size: 14,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
