import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import 'package:geoar/models/ar_location.dart';
import 'package:geoar/utils/ar_math.dart';
import 'package:geoar/utils/constants.dart';

class ArLocationCard extends StatelessWidget {
  final ArLocation location;
  final double? distanceMeters;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ArLocationCard({
    super.key,
    required this.location,
    this.distanceMeters,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _emoji {
    for (final m in AppConstants.modelTypes) {
      if (m['type'] == location.modelType) return m['emoji'] ?? '📍';
    }
    return '📍';
  }

  Color _categoryColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final idx = AppConstants.categories.indexOf(location.category);
    const palette = [
      Color(0xFF6C63FF),
      Color(0xFFFF6584),
      Color(0xFFFFBE0B),
      Color(0xFF4CAF50),
      Color(0xFF2196F3),
      Color(0xFFFF5722),
      Color(0xFF9C27B0),
      Color(0xFF00BCD4),
      Color(0xFFFF9800),
      Color(0xFF795548),
      Color(0xFF607D8B),
      Color(0xFF03DAC6),
    ];
    if (idx >= 0 && idx < palette.length) return palette[idx];
    return colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = _categoryColor(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
                    colorScheme.surfaceContainer.withValues(alpha: 0.7),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.95),
                    colorScheme.surfaceContainerLowest.withValues(alpha: 0.9),
                  ],
          ),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.18),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent bar
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        accentColor,
                        accentColor.withValues(alpha: 0.4),
                      ],
                    ),
                  ),
                ),

                // Main content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 4, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Emoji circle
                        _EmojiCircle(
                            emoji: _emoji, accentColor: accentColor),
                        const SizedBox(width: 12),

                        // Text content
                        Expanded(
                          child: _CardContent(
                            location: location,
                            distanceMeters: distanceMeters,
                            accentColor: accentColor,
                            colorScheme: colorScheme,
                          ),
                        ),

                        // Popup menu
                        if (onEdit != null || onDelete != null)
                          _ActionMenu(
                            onEdit: onEdit,
                            onDelete: onDelete,
                            colorScheme: colorScheme,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
        .slideY(
          begin: 0.12,
          end: 0,
          duration: 380.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ─── Emoji Circle ─────────────────────────────────────────────────────────────

class _EmojiCircle extends StatelessWidget {
  final String emoji;
  final Color accentColor;

  const _EmojiCircle({required this.emoji, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor.withValues(alpha: 0.12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.15),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}

// ─── Card Content ─────────────────────────────────────────────────────────────

class _CardContent extends StatelessWidget {
  final ArLocation location;
  final double? distanceMeters;
  final Color accentColor;
  final ColorScheme colorScheme;

  const _CardContent({
    required this.location,
    required this.distanceMeters,
    required this.accentColor,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('MMM d, yyyy').format(location.createdDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          location.title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        // Subtitle
        if (location.subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            location.subtitle,
            style: TextStyle(
              fontSize: 12.5,
              color: colorScheme.onSurface.withValues(alpha: 0.55),
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],

        const SizedBox(height: 8),

        // Category chip + distance badge
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _CategoryChip(
                category: location.category, accentColor: accentColor),
            if (distanceMeters != null)
              _DistanceBadge(
                  distanceMeters: distanceMeters!,
                  colorScheme: colorScheme),
          ],
        ),

        const SizedBox(height: 8),

        // Content type badges
        if (location.hasText || location.hasImage || location.hasVideo)
          _ContentTypeBadges(
              location: location, colorScheme: colorScheme),

        const SizedBox(height: 6),

        // Created date
        Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 11,
              color: colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(width: 4),
            Text(
              dateStr,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurface.withValues(alpha: 0.35),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Category Chip ────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String category;
  final Color accentColor;

  const _CategoryChip(
      {required this.category, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 11,
          color: accentColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Distance Badge ───────────────────────────────────────────────────────────

class _DistanceBadge extends StatelessWidget {
  final double distanceMeters;
  final ColorScheme colorScheme;

  const _DistanceBadge(
      {required this.distanceMeters, required this.colorScheme});

  Color get _color {
    if (distanceMeters <= 20) return const Color(0xFF4CAF50);
    if (distanceMeters <= 100) return const Color(0xFFFF9800);
    return colorScheme.onSurface.withValues(alpha: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.near_me_rounded, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            ArMath.formatDistance(distanceMeters),
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Content Type Badges ──────────────────────────────────────────────────────

class _ContentTypeBadges extends StatelessWidget {
  final ArLocation location;
  final ColorScheme colorScheme;

  const _ContentTypeBadges(
      {required this.location, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final badges = <_ContentBadgeData>[];
    if (location.hasText) {
      badges.add(const _ContentBadgeData(
          emoji: '📝', label: 'Text', color: Color(0xFF2196F3)));
    }
    if (location.hasImage) {
      badges.add(const _ContentBadgeData(
          emoji: '🖼️', label: 'Image', color: Color(0xFF9C27B0)));
    }
    if (location.hasVideo) {
      badges.add(const _ContentBadgeData(
          emoji: '🎬', label: 'Video', color: Color(0xFFE91E63)));
    }

    return Wrap(
      spacing: 5,
      runSpacing: 4,
      children: badges
          .map((b) => _ContentBadge(data: b, colorScheme: colorScheme))
          .toList(),
    );
  }
}

class _ContentBadgeData {
  final String emoji;
  final String label;
  final Color color;

  const _ContentBadgeData(
      {required this.emoji, required this.label, required this.color});
}

class _ContentBadge extends StatelessWidget {
  final _ContentBadgeData data;
  final ColorScheme colorScheme;

  const _ContentBadge({required this.data, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: data.color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(data.emoji,
              style: const TextStyle(fontSize: 10, height: 1.3)),
          const SizedBox(width: 3),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 10,
              color: data.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action Menu ──────────────────────────────────────────────────────────────

class _ActionMenu extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ColorScheme colorScheme;

  const _ActionMenu({
    required this.onEdit,
    required this.onDelete,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MenuAction>(
      icon: Icon(
        Icons.more_vert_rounded,
        size: 20,
        color: colorScheme.onSurface.withValues(alpha: 0.45),
      ),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      elevation: 8,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.2),
      color: colorScheme.surface,
      onSelected: (action) {
        if (action == _MenuAction.edit) onEdit?.call();
        if (action == _MenuAction.delete) onDelete?.call();
      },
      itemBuilder: (_) => [
        if (onEdit != null)
          PopupMenuItem(
            value: _MenuAction.edit,
            height: 44,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        if (onEdit != null && onDelete != null)
          PopupMenuDivider(height: 1),
        if (onDelete != null)
          PopupMenuItem(
            value: _MenuAction.delete,
            height: 44,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Delete',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

enum _MenuAction { edit, delete }
