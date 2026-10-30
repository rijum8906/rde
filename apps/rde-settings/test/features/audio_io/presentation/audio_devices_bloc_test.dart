import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/audio_io/domain/entities/audio_devices.dart';
import 'package:rde_settings/features/audio_io/domain/repositories/audio_devices_repository.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/audio_devices_bloc.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/audio_devices_event.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/audio_devices_state.dart';

/// In-memory audio server that records the device switches.
class _FakeAudioDevicesRepository implements AudioDevicesRepository {
  String defaultOutput = 'speaker';
  String defaultInput = 'mic';
  final List<String> outputSwitches = [];
  final List<String> inputSwitches = [];

  AudioDevices get _devices => AudioDevices(
    outputName: defaultOutput,
    outputLabel: defaultOutput == 'speaker' ? 'Speaker' : 'HDMI',
    outputs: [
      AudioOutput(
        name: 'speaker',
        label: 'Speaker',
        volume: 55,
        muted: false,
        isDefault: defaultOutput == 'speaker',
      ),
      AudioOutput(
        name: 'hdmi',
        label: 'HDMI',
        volume: 80,
        muted: false,
        isDefault: defaultOutput == 'hdmi',
      ),
    ],
    inputName: defaultInput,
    inputLabel: defaultInput == 'mic' ? 'Microphone' : 'USB Microphone',
    inputs: [
      AudioInput(
        name: 'mic',
        label: 'Microphone',
        volume: 40,
        muted: false,
        isDefault: defaultInput == 'mic',
      ),
      AudioInput(
        name: 'usb',
        label: 'USB Microphone',
        volume: 70,
        muted: false,
        isDefault: defaultInput == 'usb',
      ),
    ],
    inputVolume: 40,
  );

  @override
  Future<Either<Failure, AudioDevices>> read() async => Right(_devices);

  @override
  Future<Either<Failure, void>> setDefaultOutput(String name) async {
    outputSwitches.add(name);
    defaultOutput = name;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> setDefaultInput(String name) async {
    inputSwitches.add(name);
    defaultInput = name;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> setInputVolume(int volume) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> setInputMuted(bool muted) async =>
      const Right(null);

  @override
  Stream<void> watchChanges() => const Stream<void>.empty();
}

void main() {
  test('selecting another output makes it the default', () async {
    final repository = _FakeAudioDevicesRepository();
    final bloc = AudioDevicesBloc(repository: repository);

    bloc.add(const AudioDevicesInitEvent());
    final loaded = await bloc.stream.firstWhere(
      (state) => state.status == AudioDevicesStatus.success,
    );
    expect(loaded.devices!.outputs.length, 2);
    expect(loaded.devices!.outputLabel, 'Speaker');

    final switchedState = bloc.stream.firstWhere(
      (state) => state.devices?.outputName == 'hdmi',
    );
    bloc.add(const SelectAudioOutputEvent('hdmi'));
    final switched = await switchedState;

    expect(repository.outputSwitches, ['hdmi']);
    expect(switched.devices!.outputLabel, 'HDMI');
    expect(
      switched.devices!.outputs.firstWhere((output) => output.isDefault).name,
      'hdmi',
    );
    expect(switched.isBusy, isFalse);

    await bloc.close();
  });

  test('selecting another input makes it the default', () async {
    final repository = _FakeAudioDevicesRepository();
    final bloc = AudioDevicesBloc(repository: repository);

    bloc.add(const AudioDevicesInitEvent());
    final loaded = await bloc.stream.firstWhere(
      (state) => state.status == AudioDevicesStatus.success,
    );
    expect(loaded.devices!.inputs.length, 2);
    expect(loaded.devices!.inputLabel, 'Microphone');

    final switchedState = bloc.stream.firstWhere(
      (state) => state.devices?.inputName == 'usb',
    );
    bloc.add(const SelectAudioInputEvent('usb'));
    final switched = await switchedState;

    expect(repository.inputSwitches, ['usb']);
    expect(switched.devices!.inputLabel, 'USB Microphone');
    expect(
      switched.devices!.inputs.firstWhere((input) => input.isDefault).name,
      'usb',
    );
    expect(switched.isBusy, isFalse);

    await bloc.close();
  });
}
