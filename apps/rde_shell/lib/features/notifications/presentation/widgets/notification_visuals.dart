// Maps notification severity to the icon and accent used by a card.

import 'package:flutter/material.dart';
import 'package:rde_shell/features/notifications/domain/entities/notification_severity.dart';

/// Icon and accent colour for a notification severity.
class NotificationVisuals {
  const NotificationVisuals({required this.icon, required this.accent});

  /// Icon shown in the leading badge.
  final IconData icon;

  /// Accent used by the badge, life bar, and glow.
  final Color accent;

  /// Resolves the visuals for [severity] within [scheme].
  ///
  /// Success, warning, and network tones are fixed so they stay recognisable;
  /// info and error follow the generated expressive palette.
  static NotificationVisuals of(
    NotificationSeverity severity,
    ColorScheme scheme,
  ) {
    return switch (severity) {
      NotificationSeverity.info => NotificationVisuals(
        icon: Icons.auto_awesome_rounded,
        accent: scheme.primary,
      ),
      NotificationSeverity.success => const NotificationVisuals(
        icon: Icons.check_rounded,
        accent: Color(0xFF6EDCA6),
      ),
      NotificationSeverity.warning => const NotificationVisuals(
        icon: Icons.priority_high_rounded,
        accent: Color(0xFFFFC46B),
      ),
      NotificationSeverity.error => NotificationVisuals(
        icon: Icons.error_rounded,
        accent: scheme.error,
      ),
      NotificationSeverity.network => const NotificationVisuals(
        icon: Icons.wifi_rounded,
        accent: Color(0xFF7FD8FF),
      ),
    };
  }
}
