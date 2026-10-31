import 'package:flutter_test/flutter_test.dart';
import 'package:rde_settings/features/audio_io/data/datasources/pactl_audio_datasource.dart';

/// Sinks the way `pactl --format=json list sinks` reports them.
const _sinks = '''
[
  {
    "index": 47,
    "name": "alsa_output.hdmi3",
    "description": "HDMI / DisplayPort 3 Output",
    "mute": false,
    "volume": {"front-left": {"value_percent": "100%"}}
  },
  {
    "index": 51,
    "name": "alsa_output.speaker",
    "description": "Core Ultra Series Speaker",
    "mute": true,
    "volume": {"front-left": {"value_percent": "40%"}}
  }
]
''';

/// A monitor source and two microphones, in the order pactl lists them.
const _sources = '''
[
  {
    "index": 47,
    "name": "alsa_output.hdmi3.monitor",
    "description": "Monitor of HDMI / DisplayPort 3 Output",
    "mute": false,
    "volume": {"front-left": {"value_percent": "100%"}}
  },
  {
    "index": 52,
    "name": "alsa_input.mic1",
    "description": "Internal Microphone",
    "mute": false,
    "volume": {"front-left": {"value_percent": "65%"}}
  },
  {
    "index": 53,
    "name": "alsa_input.usb",
    "description": "USB Microphone",
    "mute": true,
    "volume": {"front-left": {"value_percent": "80%"}}
  }
]
''';

void main() {
  test('parses the default speaker and microphone', () {
    final devices = PactlAudioDatasource.parseDevices(
      defaultSinkName: 'alsa_output.speaker',
      defaultSourceName: 'alsa_input.mic1',
      sinksJson: _sinks,
      sourcesJson: _sources,
    );

    expect(devices.hasOutput, isTrue);
    expect(devices.outputLabel, 'Core Ultra Series Speaker');
    expect(devices.inputName, 'alsa_input.mic1');
    expect(devices.inputLabel, 'Internal Microphone');
    expect(devices.inputVolume, 65);
    expect(devices.inputMuted, isFalse);
  });

  test('lists every output and marks only the default one', () {
    final devices = PactlAudioDatasource.parseDevices(
      defaultSinkName: 'alsa_output.speaker',
      defaultSourceName: 'alsa_input.mic1',
      sinksJson: _sinks,
      sourcesJson: _sources,
    );

    expect(devices.outputs.length, 2);
    expect(
      devices.outputs.map((output) => output.label),
      containsAll(['HDMI / DisplayPort 3 Output', 'Core Ultra Series Speaker']),
    );

    final marked = devices.outputs.where((output) => output.isDefault).toList();
    expect(marked.single.name, 'alsa_output.speaker');
    expect(marked.single.volume, 40);
    expect(marked.single.muted, isTrue);
  });

  test('lists every microphone and never a monitor', () {
    final devices = PactlAudioDatasource.parseDevices(
      defaultSinkName: 'alsa_output.speaker',
      defaultSourceName: 'alsa_input.mic1',
      sinksJson: _sinks,
      sourcesJson: _sources,
    );

    expect(devices.inputs.length, 2);
    expect(
      devices.inputs.map((input) => input.label),
      containsAll(['Internal Microphone', 'USB Microphone']),
    );
    expect(
      devices.inputs.any((input) => input.name.endsWith('.monitor')),
      isFalse,
    );

    final marked = devices.inputs.where((input) => input.isDefault).toList();
    expect(marked.single.name, 'alsa_input.mic1');
  });

  test('falls back to the first real device, never a monitor', () {
    final devices = PactlAudioDatasource.parseDevices(
      defaultSinkName: 'alsa_output.gone',
      defaultSourceName: 'alsa_input.gone',
      sinksJson: _sinks,
      sourcesJson: _sources,
    );

    expect(devices.outputName, 'alsa_output.hdmi3');
    expect(devices.outputs.first.isDefault, isTrue);
    expect(devices.inputName, 'alsa_input.mic1');
    expect(devices.inputs.first.isDefault, isTrue);
  });

  test('a missing or malformed reply leaves the devices unnamed', () {
    final devices = PactlAudioDatasource.parseDevices(
      defaultSinkName: '',
      defaultSourceName: '',
      sinksJson: 'Connection failure: Connection refused',
      sourcesJson: '',
    );

    expect(devices.hasOutput, isFalse);
    expect(devices.hasInput, isFalse);
    expect(devices.outputs, isEmpty);
    expect(devices.inputs, isEmpty);
    expect(devices.inputVolume, 0);
  });
}
