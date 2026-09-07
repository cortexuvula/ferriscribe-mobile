import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Semantic status: icon + words + optional color — never color alone.
///
/// Maps to the design's status pill/row vocabulary: available (success),
/// degraded/offline (warning), error (error), neutral (onSurfaceVariant).
enum AppStatusTone { neutral, success, warning, error }

/// A compact status line: semantic icon, text, and tone color.
///
/// Used on consultation rows (`SOAP available`), banners, and document rows.
class StatusLine extends StatelessWidget {
  const StatusLine({
    super.key,
    required this.tone,
    required this.text,
    this.icon,
    this.dense = false,
  });

  final AppStatusTone tone;
  final String text;

  /// Optional explicit icon; defaults to a tone glyph.
  final IconData? icon;

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Tolerate a theme without the extension (bare MaterialApp in tests):
    // fall back to scheme-adjacent colors.
    final status = Theme.of(context).extension<AppStatusColors>();
    final (color, defaultIcon) = switch (tone) {
      AppStatusTone.neutral => (scheme.onSurfaceVariant, Icons.info_outline),
      AppStatusTone.success => (
        status?.success ?? scheme.primary,
        Icons.check_circle_outline,
      ),
      AppStatusTone.warning => (
        status?.warning ?? scheme.onSurfaceVariant,
        Icons.cloud_off_outlined,
      ),
      AppStatusTone.error => (scheme.error, Icons.error_outline),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon ?? defaultIcon, size: dense ? 14 : 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: dense ? 13 : 14,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// A notice banner with a semantic container fill (error / offline / info).
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.tone,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final AppStatusTone tone;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = Theme.of(context).extension<AppStatusColors>();
    final (bg, fg) = switch (tone) {
      AppStatusTone.neutral => (scheme.surfaceContainer, scheme.onSurface),
      AppStatusTone.success => (
        status?.successContainer ?? scheme.primaryContainer,
        status?.onSuccessContainer ?? scheme.onPrimaryContainer,
      ),
      AppStatusTone.warning => (
        status?.warningContainer ?? scheme.surfaceContainerHighest,
        status?.onWarningContainer ?? scheme.onSurface,
      ),
      AppStatusTone.error => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: fg, fontSize: 14, height: 1.4),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: fg,
                minimumSize: const Size(0, 36),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Empty state: icon, short message, and optional supporting line.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.supporting,
  });

  final IconData icon;
  final String message;
  final String? supporting;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            if (supporting != null) ...[
              const SizedBox(height: 8),
              Text(
                supporting!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Labelled loading state for lists — skeleton rows, not a full-screen wipe.
class ListLoadingState extends StatelessWidget {
  const ListLoadingState({super.key, this.label = 'Loading…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: i.isEven ? 160 : 110,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 11,
                        width: 90,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
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
