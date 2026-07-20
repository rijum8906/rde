import 'package:flutter_test/flutter_test.dart';
import 'package:rde_settings/features/wifi/data/datasources/dbus/network_manager_proxy.dart';

void main() {
  test('network manager proxy devices', () async {
    final networkManagerProxy = NetworkManagerProxy();
    final res = await networkManagerProxy.devices();

    expect(res.isLeft(), false);
  });
}
