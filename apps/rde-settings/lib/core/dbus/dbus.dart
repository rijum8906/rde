import 'package:dbus/dbus.dart';

class RdeDbus {
  static final systemClient = DBusClient.system();
  static final sessionClient = DBusClient.session();
}
