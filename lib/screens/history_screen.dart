import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:geoar/models/visit_history.dart';
import 'package:geoar/providers/ar_locations_provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ArLocationsProvider>(
      builder: (context, provider, _) {
        final history = provider.allHistory;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: const Text('Visit History'),
            centerTitle: true,
            actions: [
              if (history.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: 'Clear All',
                  onPressed: () => _confirmClear(context, provider),
                ),
            ],
          ),
          body: history.isEmpty
              ? const _EmptyHistoryState()
              : _HistoryList(history: history),
        );
      },
    );
  }

  void _confirmClear(
      BuildContext context, ArLocationsProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.delete_sweep_outlined,
          color: Theme.of(context).colorScheme.error,
          size: 32,
        ),
        title: const Text('Clear All History'),
        content: const Text(
          'This will permanently delete all visit history records. This action cannot be undone.',
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
              provider.clearHistory();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('History cleared'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

// ─── History List (grouped by date) ──────────────────────────────────────────

class _HistoryList extends StatelessWidget {
  final List<VisitHistory> history;

  const _HistoryList({required this.history});

  Map<String, List<VisitHistory>> _groupByDate(List<VisitHistory> items) {
    final map = <String, List<VisitHistory>>{};
    for (final item in items) {
      final key = _dateGroupKey(item.visitTime);
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }

  String _dateGroupKey(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(dt);
    }
    return DateFormat('MMMM d, yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDate(history);
    final groups = grouped.entries.toList();

    int globalIndex = 0;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: groups.length,
      itemBuilder: (context, groupIndex) {
        final group = groups[groupIndex];
        final dateLabel = group.key;
        final items = group.value;

        final widgets = <Widget>[
          _DateSectionHeader(label: dateLabel, count: items.length),
        ];

        for (final item in items) {
          final itemIndex = globalIndex++;
          widgets.add(
            _HistoryCard(
              history: item,
              index: itemIndex,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widgets,
        );
      },
    );
  }
}

// ─── Date Section Header ──────────────────────────────────────────────────────

class _DateSectionHeader extends StatelessWidget {
  final String label;
  final int count;

  const _DateSectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: cs.outlineVariant,
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── History Card ─────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final VisitHistory history;
  final int index;

  const _HistoryCard({required this.history, required this.index});

  // Returns gradient colors based on engagement level
  List<Color> _gradientColors(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalEngagement = history.viewCount + history.clickCount;
    if (totalEngagement > 20 || history.durationSeconds > 300) {
      return [
        const Color(0xFFFF6B6B).withValues(alpha: 0.8),
        const Color(0xFFFFE66D).withValues(alpha: 0.6),
      ];
    } else if (totalEngagement > 10 || history.durationSeconds > 120) {
      return [
        const Color(0xFF4ECDC4).withValues(alpha: 0.8),
        const Color(0xFF44A08D).withValues(alpha: 0.6),
      ];
    } else {
      return [
        cs.primaryContainer.withValues(alpha: 0.6),
        cs.secondaryContainer.withValues(alpha: 0.4),
      ];
    }
  }

  String _engagementLabel() {
    final total = history.viewCount + history.clickCount;
    if (total > 20) return 'High Engagement';
    if (total > 10) return 'Medium Engagement';
    return 'Visited';
  }

  Color _engagementColor(BuildContext context) {
    final total = history.viewCount + history.clickCount;
    if (total > 20) return const Color(0xFFFF6B6B);
    if (total > 10) return const Color(0xFF4ECDC4);
    return Theme.of(context).colorScheme.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final timeStr = DateFormat('h:mm a').format(history.visitTime);
    final gradients = _gradientColors(context);
    final engLabel = _engagementLabel();
    final engColor = _engagementColor(context);

    return Animate(
      effects: [
        FadeEffect(
          delay: Duration(milliseconds: index * 50),
          duration: const Duration(milliseconds: 400),
        ),
        SlideEffect(
          delay: Duration(milliseconds: index * 50),
          duration: const Duration(milliseconds: 400),
          begin: const Offset(0, 0.1),
          end: Offset.zero,
          curve: Curves.easeOut,
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: cs.surfaceContainerLow,
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Gradient accent strip
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 6,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: gradients,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            history.locationTitle,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: engColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: engColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            engLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: engColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time_outlined,
                            size: 13, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          timeStr,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.timelapse_outlined,
                            size: 13, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          history.formattedDuration,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _StatBlock(
                            icon: Icons.visibility_outlined,
                            value: history.viewCount.toString(),
                            label: 'Views',
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatBlock(
                            icon: Icons.touch_app_outlined,
                            value: history.clickCount.toString(),
                            label: 'Taps',
                            color: cs.secondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatBlock(
                            icon: Icons.hourglass_bottom_outlined,
                            value: history.formattedDuration,
                            label: 'Duration',
                            color: cs.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stat Block ───────────────────────────────────────────────────────────────

class _StatBlock extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatBlock({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

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
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.tertiaryContainer,
                    cs.secondaryContainer,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_outlined,
                size: 60,
                color: cs.onTertiaryContainer,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No History Yet',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Your AR location visits will appear here. Open a location in AR mode to start tracking.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FeatureHint(
                  icon: Icons.visibility_outlined,
                  label: 'Views tracked',
                  color: cs.primary,
                ),
                const SizedBox(width: 12),
                _FeatureHint(
                  icon: Icons.touch_app_outlined,
                  label: 'Taps logged',
                  color: cs.secondary,
                ),
                const SizedBox(width: 12),
                _FeatureHint(
                  icon: Icons.timelapse_outlined,
                  label: 'Time recorded',
                  color: cs.tertiary,
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .scale(
          begin: const Offset(0.85, 0.85),
          end: const Offset(1, 1),
          duration: 500.ms,
          curve: Curves.easeOutBack,
        );
  }
}

class _FeatureHint extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeatureHint(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
