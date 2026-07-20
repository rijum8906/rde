class Failure {
  final String message;

  Failure([this.message = "Unexpected error occured"]);
}

/// Centralize App Error for the whole application
/// Always make the error message self explanatory and don't use words
/// which are already in the enum like "network", "device" etc
/// Ex: type: device, message: "Wifi Adapter not found"
/// So the ui should show like "Device Error: Wifi Adapter not found"
class RdeError {
  final String message;
  final RdeErrorType type;

  const RdeError(this.message, this.type);

  /// Create error from any exception
  factory RdeError.fromException(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    RdeErrorType type;
    String message;

    if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
      type = RdeErrorType.timeout;
      message = 'Operation timed out. Please try again.';
    } else if (errorStr.contains('permission') || errorStr.contains('denied')) {
      type = RdeErrorType.permission;
      message = 'Permission denied. Please grant required permissions.';
    } else if (errorStr.contains('password') || errorStr.contains('auth')) {
      type = RdeErrorType.authentication;
      message = 'Authentication failed. Please check your credentials.';
    } else if (errorStr.contains('device') || errorStr.contains('adapter')) {
      type = RdeErrorType.device;
      message = 'Device not available. Please check your hardware.';
    } else if (errorStr.contains('config') || errorStr.contains('setting')) {
      type = RdeErrorType.configuration;
      message = 'Configuration error. Please check your settings.';
    } else if (errorStr.contains('network') || errorStr.contains('connect')) {
      type = RdeErrorType.network;
      message = 'Network error. Please check your connection.';
    } else if (errorStr.contains('dbus')) {
      type = RdeErrorType.dbus;
      message = 'DBus error. Please try again.';
    } else {
      type = RdeErrorType.unknown;
      message = 'An unexpected error occurred.';
    }

    return RdeError(message, type);
  }

  /// Convert to UI-friendly format
  String toUiMessage() {
    return "${type.genericMessage}: $message";
  }

  @override
  String toString() => toUiMessage();
}

/// Centralize App Error types
enum RdeErrorType {
  network,
  device,
  authentication,
  permission,
  configuration,
  timeout,
  dbus,
  unknown,
}

extension RdeErrorTypeExtension on RdeErrorType {
  String get genericMessage {
    switch (this) {
      case RdeErrorType.network:
        return "Network Error";
      case RdeErrorType.device:
        return "Device Error";
      case RdeErrorType.authentication:
        return "Authentication Error";
      case RdeErrorType.permission:
        return "Permission Error";
      case RdeErrorType.configuration:
        return "Configuration Error";
      case RdeErrorType.timeout:
        return "Timeout Error";
      case RdeErrorType.dbus:
        return "DBus Error";
      case RdeErrorType.unknown:
        return "Error";
    }
  }
}
