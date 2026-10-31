abstract class BluetoothEvent {
  const BluetoothEvent();
}

/// Reads the adapter and its devices, then starts scanning when the radio is on.
class BluetoothInitEvent extends BluetoothEvent {
  const BluetoothInitEvent();
}

/// Turns the radio on or off.
class ToggleBluetoothPowerEvent extends BluetoothEvent {
  final bool value;

  const ToggleBluetoothPowerEvent(this.value);
}

/// Advertises the controller to other devices, or hides it again.
class ToggleDiscoverableEvent extends BluetoothEvent {
  final bool value;

  const ToggleDiscoverableEvent(this.value);
}

/// Starts scanning for nearby devices.
class StartDiscoveryEvent extends BluetoothEvent {
  const StartDiscoveryEvent();
}

/// Stops the running scan.
class StopDiscoveryEvent extends BluetoothEvent {
  const StopDiscoveryEvent();
}

/// The automatic scan window elapsed.
///
/// Discovery stops without a notice: the user did not ask for this stop, it is
/// simply the end of the window the page started.
class BluetoothScanWindowEndedEvent extends BluetoothEvent {
  const BluetoothScanWindowEndedEvent();
}

/// Connects to the device at [address].
class ConnectDeviceEvent extends BluetoothEvent {
  final String address;

  const ConnectDeviceEvent(this.address);
}

/// Disconnects the device at [address].
class DisconnectDeviceEvent extends BluetoothEvent {
  final String address;

  const DisconnectDeviceEvent(this.address);
}

/// Pairs with the device at [address].
class PairDeviceEvent extends BluetoothEvent {
  final String address;

  const PairDeviceEvent(this.address);
}

/// Forgets the device at [address] and its pairing.
class ForgetDeviceEvent extends BluetoothEvent {
  final String address;

  const ForgetDeviceEvent(this.address);
}

/// Marks the device at [address] as trusted, or removes that trust.
class SetTrustedDeviceEvent extends BluetoothEvent {
  final String address;
  final bool trusted;

  const SetTrustedDeviceEvent(this.address, this.trusted);
}

/// BlueZ reported a change the page has to show.
///
/// The daemon sends no payload of interest: the handler reads the object tree
/// back from it.
class BluetoothServiceChangedEvent extends BluetoothEvent {
  const BluetoothServiceChangedEvent();
}
