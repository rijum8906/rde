class LockScreenSettings {
  final bool isEnabled;
  final int delayTimer;
  final String authBackground;
  final String notificationPrivacy;

  const LockScreenSettings({
    required this.isEnabled,
    required this.delayTimer,
    required this.authBackground,
    required this.notificationPrivacy,
  });

  LockScreenSettings copyWith({
    bool? isEnabled,
    int? delayTimer,
    String? authBackground,
    String? notificationPrivacy,
  }) {
    return LockScreenSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      delayTimer: delayTimer ?? this.delayTimer,
      authBackground: authBackground ?? this.authBackground,
      notificationPrivacy: notificationPrivacy ?? this.notificationPrivacy,
    );
  }
}
