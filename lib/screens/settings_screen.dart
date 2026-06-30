import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:geoar/providers/ar_locations_provider.dart';
import 'package:geoar/providers/settings_provider.dart';
import 'package:geoar/services/media_service.dart';
import 'package:geoar/themes/app_theme.dart';
import 'package:geoar/utils/constants.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                theme.colorScheme.surface.withValues(alpha: 0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _DetectionRadiusSection()
              .animate()
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.12, end: 0),
          const SizedBox(height: 16),
          _AppearanceSection()
              .animate()
              .fadeIn(duration: 350.ms, delay: 80.ms)
              .slideY(begin: 0.12, end: 0),
          const SizedBox(height: 16),
          _DataManagementSection()
              .animate()
              .fadeIn(duration: 350.ms, delay: 160.ms)
              .slideY(begin: 0.12, end: 0),
          const SizedBox(height: 16),
          const _AboutSection()
              .animate()
              .fadeIn(duration: 350.ms, delay: 240.ms)
              .slideY(begin: 0.12, end: 0),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Detection Radius Section ─────────────────────────────────────────────────

class _DetectionRadiusSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final options = AppConstants.detectionRadiusOptions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Detection Radius',
          icon: Icons.radar_rounded,
        ),
        GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_searching_rounded,
                      size: 20, color: theme.colorScheme.secondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Nearby AR trigger distance',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${settings.detectionRadius.toStringAsFixed(0)} m',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _RadiusSegmentedButton(
                options: options,
                selected: settings.detectionRadius,
                onChanged: (value) => settings.setDetectionRadius(value),
              ),
              const SizedBox(height: 12),
              _RadiusVisualizer(
                radius: settings.detectionRadius,
                maxRadius: options.last,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RadiusSegmentedButton extends StatelessWidget {
  final List<double> options;
  final double selected;
  final ValueChanged<double> onChanged;

  const _RadiusSegmentedButton({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SegmentedButton<double>(
      style: SegmentedButton.styleFrom(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selectedBackgroundColor: theme.colorScheme.primary,
        selectedForegroundColor: theme.colorScheme.onPrimary,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      segments: options
          .map((v) => ButtonSegment<double>(
                value: v,
                label: Text('${v.toStringAsFixed(0)}m'),
              ))
          .toList(),
      selected: {selected},
      onSelectionChanged: (set) {
        if (set.isNotEmpty) onChanged(set.first);
      },
    );
  }
}

class _RadiusVisualizer extends StatelessWidget {
  final double radius;
  final double maxRadius;

  const _RadiusVisualizer({required this.radius, required this.maxRadius});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = (radius / maxRadius).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor:
                AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('5 m',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            Text('50 m',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}

// ─── Appearance Section ───────────────────────────────────────────────────────

class _AppearanceSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Appearance',
          icon: Icons.palette_rounded,
        ),
        GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              _SettingsTile(
                icon: settings.darkMode
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                iconColor: settings.darkMode
                    ? const Color(0xFF9C8AFF)
                    : const Color(0xFFFFB74D),
                title: 'Dark Mode',
                subtitle: settings.darkMode
                    ? 'Dark theme active'
                    : 'Light theme active',
                trailing: Switch(
                  value: settings.darkMode,
                  onChanged: (v) => settings.setDarkMode(v),
                  activeThumbColor: theme.colorScheme.primary,
                ),
              ),
              Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
              _SettingsTile(
                icon: Icons.format_paint_rounded,
                iconColor: theme.colorScheme.tertiary,
                title: 'Theme Color',
                subtitle: 'Cosmic Purple (default)',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: theme.colorScheme.outlineVariant, width: 2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded,
                        color: theme.colorScheme.onSurfaceVariant, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Data Management Section ──────────────────────────────────────────────────

class _DataManagementSection extends StatefulWidget {
  @override
  State<_DataManagementSection> createState() =>
      _DataManagementSectionState();
}

class _DataManagementSectionState extends State<_DataManagementSection> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isClearing = false;

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    try {
      final locationsProvider = context.read<ArLocationsProvider>();
      final data = locationsProvider.exportData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final file = File('${dir.path}/geoar_export_$timestamp.json');
      await file.writeAsString(jsonString);

      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'GeoAR Data Export',
        text: 'GeoAR location data exported on $timestamp',
      );

      if (mounted) {
        _showSnack(
            'Data exported successfully', Icons.check_circle_rounded, Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Export failed: $e', Icons.error_rounded, Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importData() async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select GeoAR export file',
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isImporting = false);
        return;
      }

      final path = result.files.single.path;
      if (path == null) {
        if (mounted) setState(() => _isImporting = false);
        return;
      }

      final content = await File(path).readAsString();
      final Map<String, dynamic> data =
          jsonDecode(content) as Map<String, dynamic>;

      if (!mounted) return;
      final confirmed = await _showImportConfirmDialog();
      if (!confirmed) {
        if (mounted) setState(() => _isImporting = false);
        return;
      }

      if (!mounted) return;
      await context.read<ArLocationsProvider>().importData(data);

      if (mounted) {
        _showSnack('Data imported successfully',
            Icons.check_circle_rounded, Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Import failed: $e', Icons.error_rounded, Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<bool> _showImportConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.upload_file_rounded,
                    color: Theme.of(ctx).colorScheme.primary),
                const SizedBox(width: 10),
                const Text('Import Data'),
              ],
            ),
            content: const Text(
              'This will merge imported locations with your existing data. '
              'Duplicate IDs may be overwritten. Continue?',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Import')),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_sweep_rounded,
                color: Theme.of(ctx).colorScheme.error),
            const SizedBox(width: 10),
            const Text('Clear Cache'),
          ],
        ),
        content: const Text(
          'This will delete all cached media files and visit history. '
          'Your AR locations will not be affected. This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isClearing = true);
    try {
      await MediaService.instance.clearCache();
      if (!mounted) return;
      await context.read<ArLocationsProvider>().clearHistory();
      if (mounted) {
        _showSnack('Cache cleared successfully',
            Icons.check_circle_rounded, Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Clear failed: $e', Icons.error_rounded, Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  Future<void> _resetAllSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.settings_backup_restore_rounded,
                color: Theme.of(ctx).colorScheme.error),
            const SizedBox(width: 10),
            const Text('Reset Settings'),
          ],
        ),
        content: const Text(
          'All preferences will be reset to defaults. '
          'This does not affect your saved locations.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<SettingsProvider>().clearPreferences();
      if (mounted) {
        _showSnack('Settings reset to defaults',
            Icons.check_circle_rounded, Colors.green);
      }
    }
  }

  void _showSnack(String msg, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Data Management',
          icon: Icons.storage_rounded,
        ),
        GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              _SettingsTile(
                icon: Icons.upload_rounded,
                iconColor: const Color(0xFF26C6DA),
                title: 'Export Data',
                subtitle: 'Save locations as JSON file',
                trailing: _isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.chevron_right_rounded,
                        color: theme.colorScheme.onSurfaceVariant),
                onTap: _isExporting ? null : _exportData,
              ),
              Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
              _SettingsTile(
                icon: Icons.download_rounded,
                iconColor: const Color(0xFF66BB6A),
                title: 'Import Data',
                subtitle: 'Load locations from JSON file',
                trailing: _isImporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.chevron_right_rounded,
                        color: theme.colorScheme.onSurfaceVariant),
                onTap: _isImporting ? null : _importData,
              ),
              Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
              _SettingsTile(
                icon: Icons.delete_sweep_rounded,
                iconColor: const Color(0xFFEF5350),
                title: 'Clear Cache',
                subtitle: 'Remove media cache & visit history',
                trailing: _isClearing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.chevron_right_rounded,
                        color: theme.colorScheme.onSurfaceVariant),
                onTap: _isClearing ? null : _clearCache,
              ),
              Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
              _SettingsTile(
                icon: Icons.settings_backup_restore_rounded,
                iconColor: const Color(0xFFFF7043),
                title: 'Reset Settings',
                subtitle: 'Restore all defaults',
                trailing: Icon(Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant),
                onTap: _resetAllSettings,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── About Section ────────────────────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'About',
          icon: Icons.info_rounded,
        ),
        GlassContainer(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.view_in_ar_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GeoAR',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Version 1.0.0',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'GPS-Based Augmented Reality Platform with Interactive Multimedia Content',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Divider(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
              const SizedBox(height: 8),
              const _AboutRow(label: 'Framework', value: 'Flutter 3'),
              const SizedBox(height: 6),
              const _AboutRow(label: 'Build', value: 'Production'),
              const SizedBox(height: 6),
              const _AboutRow(label: 'License', value: 'Proprietary'),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;

  const _AboutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Shared Settings Tile ─────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
