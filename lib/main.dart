import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:geoar/providers/ar_locations_provider.dart';
import 'package:geoar/providers/settings_provider.dart';
import 'package:geoar/screens/home_screen.dart';
import 'package:geoar/services/database_service.dart';
import 'package:geoar/services/location_service.dart';
import 'package:geoar/themes/app_theme.dart';

// ─── Entry Point ──────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent system overlays
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Global Flutter error handler — log & prevent red-screen crashes in release
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
    debugPrint(details.stack.toString());
  };

  // Initialise database first — providers depend on it
  await DatabaseService.instance.init();

  // Start GPS tracking early so first fix arrives sooner
  await LocationService.instance.startTracking();

  runApp(const GeoArApp());
}

// ─── Root App ─────────────────────────────────────────────────────────────────

class GeoArApp extends StatelessWidget {
  const GeoArApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(),
        ),
        ChangeNotifierProvider<ArLocationsProvider>(
          create: (_) => ArLocationsProvider(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'GeoAR',
            debugShowCheckedModeBanner: false,
            themeMode:
                settings.darkMode ? ThemeMode.dark : ThemeMode.light,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: const _AppBootstrap(),
          );
        },
      ),
    );
  }
}

// ─── Bootstrap Widget ─────────────────────────────────────────────────────────
// Initialises providers that need async setup, then shows HomeScreen.
// A beautiful animated splash is displayed while loading.

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap>
    with SingleTickerProviderStateMixin {
  late final Future<void> _initFuture;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _initFuture = _initialise();
  }

  Future<void> _initialise() async {
    // Run provider init in parallel for speed
    final settings = context.read<SettingsProvider>();
    final locations = context.read<ArLocationsProvider>();

    await Future.wait([
      settings.init(),
      locations.loadLocations(),
    ]);

    // Minimum splash duration so it doesn't flash by too fast
    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasError) {
          return _ErrorScreen(error: snapshot.error.toString());
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return _SplashScreen(pulseController: _pulseController);
        }

        // Slide the HomeScreen in once ready
        return const HomeScreen();
      },
    );
  }
}

// ─── Splash Screen ────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  final AnimationController pulseController;

  const _SplashScreen({required this.pulseController});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              theme.colorScheme.primaryContainer.withValues(alpha: isDark ? 0.5 : 0.4),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Animated logo
                AnimatedBuilder(
                  animation: pulseController,
                  builder: (context, child) {
                    final scale = 1.0 +
                        pulseController.value * 0.06;
                    final glowRadius = 20.0 +
                        pulseController.value * 20.0;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.secondary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.45),
                              blurRadius: glowRadius,
                              spreadRadius: 2,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.view_in_ar_rounded,
                          color: Colors.white,
                          size: 54,
                        ),
                      ),
                    );
                  },
                )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scale(
                      begin: const Offset(0.7, 0.7),
                      end: const Offset(1.0, 1.0),
                      duration: 700.ms,
                      curve: Curves.elasticOut,
                    ),

                const SizedBox(height: 32),

                // App name
                Text(
                  'GeoAR',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    color: theme.colorScheme.onSurface,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 250.ms)
                    .slideY(begin: 0.2, end: 0),

                const SizedBox(height: 8),

                // Tagline
                Text(
                  'Augmented Reality, Rooted in Place',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 380.ms)
                    .slideY(begin: 0.2, end: 0),

                const Spacer(flex: 2),

                // Loading indicator
                Column(
                  children: [
                    SizedBox(
                      width: 140,
                      child: LinearProgressIndicator(
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary),
                        borderRadius: BorderRadius.circular(8),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Loading your world…',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 500.ms),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Error Screen ─────────────────────────────────────────────────────────────

class _ErrorScreen extends StatelessWidget {
  final String error;

  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 72,
                color: theme.colorScheme.error,
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(begin: const Offset(0.6, 0.6)),
              const SizedBox(height: 24),
              Text(
                'Failed to Start',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 12),
              Text(
                'Something went wrong while initialising GeoAR. '
                'Please restart the app.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 16),
              // Debug detail (only visible in debug builds)
              if (kDebugMode)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    error,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontFamily: 'monospace',
                    ),
                  ),
                ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  // Attempt a hot-restart path by popping to the bootstrap
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                        builder: (_) => const _AppBootstrap()),
                  );
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  minimumSize: const Size(200, 52),
                ),
              ).animate().fadeIn(delay: 500.ms),
            ],
          ),
        ),
      ),
    );
  }
}

