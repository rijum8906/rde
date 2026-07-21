import 'package:dbus/dbus.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/dbus/dbus.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';

class RdeWifiProxy {
  static const String serviceName = 'org.rde.wifi';
  static final DBusObjectPath objectPath = DBusObjectPath('/org/rde/wifi');
  static const String interfaceName = 'org.rde.wifi';

  final DBusClient client = RdeDbus.sessionClient;

  RdeWifiProxy();

  /// Call Scan method to trigger background scanning
  Future<Either<RdeError, void>> scan() async {
    try {
      await client.callMethod(
        destination: serviceName,
        path: objectPath,
        interface: interfaceName,
        name: 'Scan',
      );
      return const Right(null);
    } catch (e) {
      return Left(RdeError(e.toString(), RdeErrorType.device));
    }
  }

  /// Get enabled property
  Future<Either<RdeError, bool>> getEnabled() async {
    try {
      final res = await client.callMethod(
        destination: serviceName,
        path: objectPath,
        interface: 'org.freedesktop.DBus.Properties',
        name: 'Get',
        values: [DBusString(interfaceName), DBusString('Enabled')],
      );
      if (res.returnValues.isEmpty) {
        return const Right(true);
      }
      final variant = res.returnValues.first as DBusVariant;
      return Right((variant.value as DBusBoolean).value);
    } catch (e) {
      return Left(RdeError(e.toString(), RdeErrorType.device));
    }
  }

  /// Set enabled property
  Future<Either<RdeError, void>> setEnabled(bool value) async {
    try {
      await client.callMethod(
        destination: serviceName,
        path: objectPath,
        interface: 'org.freedesktop.DBus.Properties',
        name: 'Set',
        values: [
          DBusString(interfaceName),
          DBusString('Enabled'),
          DBusVariant(DBusBoolean(value)),
        ],
      );
      return const Right(null);
    } catch (e) {
      return Left(RdeError(e.toString(), RdeErrorType.device));
    }
  }

  /// Get networks list
  Future<Either<RdeError, List<WifiNetwork>>> getNetworks() async {
    try {
      final res = await client.callMethod(
        destination: serviceName,
        path: objectPath,
        interface: 'org.freedesktop.DBus.Properties',
        name: 'Get',
        values: [DBusString(interfaceName), DBusString('Networks')],
      );
      if (res.returnValues.isEmpty) {
        return const Right([]);
      }
      final variant = res.returnValues.first as DBusVariant;
      final array = variant.value as DBusArray;

      final List<WifiNetwork> list = [];
      for (var child in array.children) {
        if (child is DBusStruct) {
          list.add(_parseAccessPointInfo(child));
        }
      }
      return Right(list);
    } catch (e) {
      return Left(RdeError(e.toString(), RdeErrorType.device));
    }
  }

  /// Get saved networks list
  Future<Either<RdeError, List<String>>> getSavedNetworks() async {
    try {
      final res = await client.callMethod(
        destination: serviceName,
        path: objectPath,
        interface: 'org.freedesktop.DBus.Properties',
        name: 'Get',
        values: [DBusString(interfaceName), DBusString('SavedNetworks')],
      );
      if (res.returnValues.isEmpty) {
        return const Right([]);
      }
      final variant = res.returnValues.first as DBusVariant;
      final array = variant.value as DBusArray;

      final List<String> list = array.children
          .map((v) => (v as DBusString).value)
          .toList();
      return Right(list);
    } catch (e) {
      return Left(RdeError(e.toString(), RdeErrorType.device));
    }
  }

  /// Connect to Wi-Fi
  Future<Either<RdeError, void>> connect(String ssid, String password) async {
    try {
      await client.callMethod(
        destination: serviceName,
        path: objectPath,
        interface: interfaceName,
        name: 'Connect',
        values: [DBusString(ssid), DBusString(password)],
      );
      return const Right(null);
    } catch (e) {
      return Left(RdeError(e.toString(), RdeErrorType.device));
    }
  }

  /// Connect to Saved Network
  Future<Either<RdeError, void>> connectSavedNetwork(String ssid) async {
    try {
      await client.callMethod(
        destination: serviceName,
        path: objectPath,
        interface: interfaceName,
        name: 'ConnectSavedNetwork',
        values: [DBusString(ssid)],
      );
      return const Right(null);
    } catch (e) {
      return Left(RdeError(e.toString(), RdeErrorType.device));
    }
  }

  /// Disconnect
  Future<Either<RdeError, void>> disconnect() async {
    try {
      await client.callMethod(
        destination: serviceName,
        path: objectPath,
        interface: interfaceName,
        name: 'Disconnect',
      );
      return const Right(null);
    } catch (e) {
      return Left(RdeError(e.toString(), RdeErrorType.device));
    }
  }

  /// Forget device
  Future<Either<RdeError, void>> forgotDevice(String ssid) async {
    try {
      await client.callMethod(
        destination: serviceName,
        path: objectPath,
        interface: interfaceName,
        name: 'ForgotDevice',
        values: [DBusString(ssid)],
      );
      return const Right(null);
    } catch (e) {
      return Left(RdeError(e.toString(), RdeErrorType.device));
    }
  }

  WifiNetwork _parseAccessPointInfo(DBusStruct struct) {
    final ssid = (struct.children[1] as DBusString).value;

    // Parse strength
    int strengthVal = 0;
    final strengthChild = struct.children[2];
    if (strengthChild is DBusByte) {
      strengthVal = strengthChild.value;
    } else if (strengthChild is DBusUint32) {
      strengthVal = strengthChild.value;
    } else if (strengthChild is DBusInt32) {
      strengthVal = strengthChild.value;
    } else if (strengthChild is DBusInt64) {
      strengthVal = strengthChild.value.toInt();
    }

    // Parse security
    String securityStr = 'Unknown';
    final securityChild = struct.children[3];
    if (securityChild is DBusString) {
      securityStr = securityChild.value;
    } else {
      int secIdx = 6; // default Unknown
      if (securityChild is DBusByte) {
        secIdx = securityChild.value;
      } else if (securityChild is DBusUint32) {
        secIdx = securityChild.value;
      } else if (securityChild is DBusInt32) {
        secIdx = securityChild.value;
      } else if (securityChild is DBusInt64) {
        secIdx = securityChild.value.toInt();
      }

      switch (secIdx) {
        case 0:
          securityStr = 'Open';
          break;
        case 1:
          securityStr = 'WEP';
          break;
        case 2:
          securityStr = 'WPA';
          break;
        case 3:
          securityStr = 'WPA2';
          break;
        case 4:
          securityStr = 'WPA3';
          break;
        case 5:
          securityStr = 'Enterprise';
          break;
        default:
          securityStr = 'Unknown';
          break;
      }
    }

    return WifiNetwork(
      ssid: ssid.isNotEmpty ? ssid : 'Unknown Network',
      security: securityStr,
      strength: '$strengthVal%',
    );
  }
}
