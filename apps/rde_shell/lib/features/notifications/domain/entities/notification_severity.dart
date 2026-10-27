// Notification severity used to pick the icon and tonal accent of a card.

/// The kind of event a notification represents.
///
/// Severity is domain data: it describes what happened. The presentation layer
/// maps it to an icon and colour so the domain stays free of Flutter types.
enum NotificationSeverity {
  /// Neutral information, such as a tip or a completed background task.
  info,

  /// A task finished successfully.
  success,

  /// Something needs attention but is not broken.
  warning,

  /// An operation failed.
  error,

  /// Connectivity changes, such as Wi-Fi or Bluetooth.
  network,
}
