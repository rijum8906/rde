import 'package:dbus/dbus.dart';

/// Shared D-Bus connections used by RDE application data sources.
///
/// Keep the system and session bus clients centralized so apps reuse their
/// connections rather than creating a new client for every remote object.
class RdeDbus {
  RdeDbus._();

  /// System bus connection for system services and hardware interfaces.
  static final DBusClient systemClient = DBusClient.system();

  /// Session bus connection for per-user desktop services.
  static final DBusClient sessionClient = DBusClient.session();
}
