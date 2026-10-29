import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_device.dart';
import 'package:rde_settings/features/bluetooth/domain/repositories/bluetooth_repository.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_state.dart';

/// Coordinates the Bluetooth page with the BlueZ-backed repository.
///
/// Every mutation is followed by a fresh read of the object tree, so the page
/// renders what the daemon reports instead of an optimistic guess. A scan runs
/// while the page is open and stops when it goes away, because leaving discovery
/// on keeps the radio busy and slows down Wi-Fi.
class BluetoothBloc extends Bloc<BluetoothEvent, BluetoothState> {
  final BluetoothRepository _bluetoothRepository;

  /// Live updates pushed by BlueZ while the page is open.
  late final StreamSubscription<void> _changes;

  /// Collapses a burst of daemon signals into a single refresh.
  Timer? _changeDebounce;

  BluetoothBloc({required this._bluetoothRepository})
    : super(BluetoothState.initial()) {
    on<BluetoothInitEvent>(_onInit);
    on<ToggleBluetoothPowerEvent>(_onTogglePower);
    on<ToggleDiscoverableEvent>(_onToggleDiscoverable);
    on<StartDiscoveryEvent>(_onStartDiscovery);
    on<StopDiscoveryEvent>(_onStopDiscovery);
    on<ConnectDeviceEvent>(_onConnect);
    on<DisconnectDeviceEvent>(_onDisconnect);
    on<PairDeviceEvent>(_onPair);
    on<ForgetDeviceEvent>(_onForget);
    on<SetTrustedDeviceEvent>(_onSetTrusted);
    on<BluetoothServiceChangedEvent>(_onServiceChanged);

    // BlueZ owns the adapter and every device, and another client such as
    // bluetoothctl can change either while the page is open. Listening to its
    // signals keeps the page showing the daemon's state.
    _changes = _bluetoothRepository.watchChanges().listen(
      (_) => add(const BluetoothServiceChangedEvent()),
      onError: (Object _) {},
    );
  }

  @override
  Future<void> close() async {
    _changeDebounce?.cancel();
    await _changes.cancel();

    // A scan left running would keep the radio and the page's device list alive
    // after the user left, so it is stopped best effort.
    unawaited(_bluetoothRepository.stopDiscovery());

    return super.close();
  }

  Future<void> _onInit(
    BluetoothInitEvent event,
    Emitter<BluetoothState> emit,
  ) async {
    emit(state.copyWith(status: BluetoothStatus.loading, errorMessage: null));

    final result = await _bluetoothRepository.getSnapshot();
    Failure? failure;
    BluetoothSnapshot? snapshot;
    result.fold((value) => failure = value, (value) => snapshot = value);

    if (failure != null) {
      emit(
        state.copyWith(
          status: BluetoothStatus.failure,
          errorMessage: failure!.message,
        ),
      );
      return;
    }

    final loaded = snapshot!;
    final adapter = loaded.adapter;
    emit(
      state.copyWith(
        status: BluetoothStatus.success,
        adapter: adapter,
        devices: loaded.devices,
        errorMessage: null,
      ),
    );

    if (adapter == null) {
      return;
    }

    // A page that claims to list devices without scanning for them looks
    // broken, so an enabled radio starts a scan right away.
    if (adapter.powered && !adapter.discovering) {
      final scan = await _bluetoothRepository.startDiscovery();
      final scanFailure = _failureOf(scan);
      if (scanFailure != null) {
        emit(state.copyWith(errorMessage: scanFailure.message));
        return;
      }
    }

    await _refresh(emit);
  }

  Future<void> _onTogglePower(
    ToggleBluetoothPowerEvent event,
    Emitter<BluetoothState> emit,
  ) async {
    if (!state.isAvailable ||
        event.value == state.isEnabled ||
        state.busyAddress != null) {
      return;
    }

    emit(state.copyWith(errorMessage: null, noticeMessage: null));
    final result = await _bluetoothRepository.setPowered(event.value);
    final failure = _failureOf(result);
    if (failure != null) {
      emit(state.copyWith(errorMessage: failure.message));
      return;
    }

    // Switching the radio on starts a scan: the device objects BlueZ kept are
    // gone while it was off, so the list would otherwise stay empty.
    if (event.value) {
      await _bluetoothRepository.startDiscovery();
    }
    await _refresh(emit);
  }

  Future<void> _onToggleDiscoverable(
    ToggleDiscoverableEvent event,
    Emitter<BluetoothState> emit,
  ) async {
    if (!state.isEnabled || event.value == state.isDiscoverable) {
      return;
    }

    emit(state.copyWith(errorMessage: null, noticeMessage: null));
    final result = await _bluetoothRepository.setDiscoverable(event.value);
    final failure = _failureOf(result);
    if (failure != null) {
      emit(state.copyWith(errorMessage: failure.message));
      return;
    }

    await _refresh(emit);
  }

  Future<void> _onStartDiscovery(
    StartDiscoveryEvent event,
    Emitter<BluetoothState> emit,
  ) async {
    if (!state.isEnabled) {
      return;
    }

    final result = await _bluetoothRepository.startDiscovery();
    final failure = _failureOf(result);
    if (failure != null) {
      emit(state.copyWith(errorMessage: failure.message));
      return;
    }

    emit(
      state.copyWith(
        errorMessage: null,
        noticeMessage: 'Scanning for nearby devices',
      ),
    );
    await _refresh(emit);
  }

  Future<void> _onStopDiscovery(
    StopDiscoveryEvent event,
    Emitter<BluetoothState> emit,
  ) async {
    final result = await _bluetoothRepository.stopDiscovery();
    final failure = _failureOf(result);
    if (failure != null) {
      emit(state.copyWith(errorMessage: failure.message));
      return;
    }

    emit(state.copyWith(errorMessage: null, noticeMessage: 'Scan stopped'));
    await _refresh(emit);
  }

  Future<void> _onConnect(
    ConnectDeviceEvent event,
    Emitter<BluetoothState> emit,
  ) async {
    final device = _deviceFor(event.address);
    if (device == null || state.busyAddress != null) {
      return;
    }

    emit(
      state.copyWith(
        busyAddress: event.address,
        errorMessage: null,
        noticeMessage: null,
      ),
    );

    final result = await _bluetoothRepository.connect(device);
    final failure = _failureOf(result);
    if (failure != null) {
      emit(state.copyWith(busyAddress: null, errorMessage: failure.message));
      return;
    }

    emit(
      state.copyWith(
        busyAddress: null,
        noticeMessage: 'Connected to ${device.name}',
      ),
    );
    await _refresh(emit);
  }

  Future<void> _onDisconnect(
    DisconnectDeviceEvent event,
    Emitter<BluetoothState> emit,
  ) async {
    final device = _deviceFor(event.address);
    if (device == null || state.busyAddress != null) {
      return;
    }

    emit(
      state.copyWith(
        busyAddress: event.address,
        errorMessage: null,
        noticeMessage: null,
      ),
    );

    final result = await _bluetoothRepository.disconnect(device);
    final failure = _failureOf(result);
    if (failure != null) {
      emit(state.copyWith(busyAddress: null, errorMessage: failure.message));
      return;
    }

    emit(
      state.copyWith(
        busyAddress: null,
        noticeMessage: 'Disconnected from ${device.name}',
      ),
    );
    await _refresh(emit);
  }

  Future<void> _onPair(
    PairDeviceEvent event,
    Emitter<BluetoothState> emit,
  ) async {
    final device = _deviceFor(event.address);
    if (device == null || state.busyAddress != null) {
      return;
    }

    emit(
      state.copyWith(
        busyAddress: event.address,
        errorMessage: null,
        noticeMessage: null,
      ),
    );

    final result = await _bluetoothRepository.pair(device);
    final failure = _failureOf(result);
    if (failure != null) {
      emit(state.copyWith(busyAddress: null, errorMessage: failure.message));
      return;
    }

    emit(
      state.copyWith(
        busyAddress: null,
        noticeMessage: 'Paired with ${device.name}',
      ),
    );
    await _refresh(emit);
  }

  Future<void> _onForget(
    ForgetDeviceEvent event,
    Emitter<BluetoothState> emit,
  ) async {
    final device = _deviceFor(event.address);
    if (device == null || state.busyAddress != null) {
      return;
    }

    emit(
      state.copyWith(
        busyAddress: event.address,
        errorMessage: null,
        noticeMessage: null,
      ),
    );

    final result = await _bluetoothRepository.forget(device);
    final failure = _failureOf(result);
    if (failure != null) {
      emit(state.copyWith(busyAddress: null, errorMessage: failure.message));
      return;
    }

    emit(
      state.copyWith(busyAddress: null, noticeMessage: 'Forgot ${device.name}'),
    );
    await _refresh(emit);
  }

  Future<void> _onSetTrusted(
    SetTrustedDeviceEvent event,
    Emitter<BluetoothState> emit,
  ) async {
    final device = _deviceFor(event.address);
    if (device == null || state.busyAddress != null) {
      return;
    }

    emit(
      state.copyWith(
        busyAddress: event.address,
        errorMessage: null,
        noticeMessage: null,
      ),
    );

    final result = await _bluetoothRepository.setTrusted(device, event.trusted);
    final failure = _failureOf(result);
    if (failure != null) {
      emit(state.copyWith(busyAddress: null, errorMessage: failure.message));
      return;
    }

    emit(
      state.copyWith(
        busyAddress: null,
        noticeMessage: event.trusted
            ? '${device.name} is now trusted'
            : '${device.name} is no longer trusted',
      ),
    );
    await _refresh(emit);
  }

  /// Refreshes the page after a daemon signal.
  ///
  /// A scan alone produces a signal per device and per property change, so the
  /// refresh waits for the burst to settle. The page keeps showing its current
  /// content until then, and a device operation in flight is left alone because
  /// it refreshes when it finishes.
  void _onServiceChanged(
    BluetoothServiceChangedEvent event,
    Emitter<BluetoothState> emit,
  ) {
    _changeDebounce?.cancel();
    _changeDebounce = Timer(const Duration(milliseconds: 350), () {
      if (state.busyAddress != null) {
        return;
      }
      unawaited(_refresh(emit));
    });
  }

  /// Reads the adapter and its devices back from the daemon.
  ///
  /// A failed read keeps the content the page already shows and only reports
  /// the error, because a transient daemon error should not blank the list.
  Future<void> _refresh(Emitter<BluetoothState> emit) async {
    final result = await _bluetoothRepository.getSnapshot();
    Failure? failure;
    BluetoothSnapshot? snapshot;
    result.fold((value) => failure = value, (value) => snapshot = value);

    if (failure != null) {
      emit(state.copyWith(errorMessage: failure!.message));
      return;
    }

    final loaded = snapshot!;
    emit(
      state.copyWith(
        status: BluetoothStatus.success,
        adapter: loaded.adapter,
        devices: loaded.devices,
        errorMessage: null,
        noticeMessage: null,
      ),
    );
  }

  /// Returns the device at [address], or `null` when it is gone.
  BluetoothDevice? _deviceFor(String address) {
    for (final device in state.devices) {
      if (device.address == address) {
        return device;
      }
    }
    return null;
  }

  /// Extracts the failure of a void result, or `null` on success.
  Failure? _failureOf(Either<Failure, void> result) {
    return result.fold((failure) => failure, (_) => null);
  }
}
