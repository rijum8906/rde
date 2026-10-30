import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/audio_io/domain/entities/audio_devices.dart';

/// Reads the default PipeWire devices and controls the microphone.
///
/// The RDE volume service owns the master output level but exposes neither a
/// device name nor a capture control, so the speaker name and the microphone
/// are read from PipeWire through `pactl`, which speaks the same protocol on
/// PulseAudio and PipeWire systems. The JSON form is used because the text form
/// is meant for humans and changes with the tool's version.
class PactlAudioDatasource {
  const PactlAudioDatasource();

  /// The tool every desktop distribution ships alongside PipeWire/PulseAudio.
  static const String _executable = 'pactl';

  /// Reads the default sink and source, plus the microphone capture level.
  ///
  /// # Errors
  /// Returns an [RdeError] when `pactl` is missing or the audio server refuses
  /// to answer.
  Future<Either<RdeError, AudioDevices>> read() {
    return _read('read the audio devices', () async {
      final info = await _run(const ['info']);
      final sinks = await _run(const ['--format=json', 'list', 'sinks']);
      final sources = await _run(const ['--format=json', 'list', 'sources']);

      return parseDevices(
        defaultSinkName: _infoValue('${info.stdout}', 'Default Sink'),
        defaultSourceName: _infoValue('${info.stdout}', 'Default Source'),
        sinksJson: '${sinks.stdout}',
        sourcesJson: '${sources.stdout}',
      );
    });
  }

  /// Sets the microphone capture volume to [volume] percent.
  ///
  /// # Errors
  /// Returns an [RdeError] when the audio server rejects the change.
  Future<Either<RdeError, void>> setInputVolume(int volume) {
    return _write('change the microphone volume', () async {
      await _run(['set-source-volume', '@DEFAULT_SOURCE@', '$volume%']);
    });
  }

  /// Mutes or unmutes the microphone.
  ///
  /// # Errors
  /// Returns an [RdeError] when the audio server rejects the change.
  Future<Either<RdeError, void>> setInputMuted(bool muted) {
    return _write('change the microphone mute state', () async {
      await _run(['set-source-mute', '@DEFAULT_SOURCE@', muted ? '1' : '0']);
    });
  }

  /// Makes [name] the output sound is routed to.
  ///
  /// # Errors
  /// Returns an [RdeError] when the audio server rejects the switch.
  Future<Either<RdeError, void>> setDefaultOutput(String name) {
    return _write('switch the output device', () async {
      await _run(['set-default-sink', name]);
    });
  }

  /// Makes [name] the source recordings are taken from.
  ///
  /// # Errors
  /// Returns an [RdeError] when the audio server rejects the switch.
  Future<Either<RdeError, void>> setDefaultInput(String name) {
    return _write('switch the input device', () async {
      await _run(['set-default-source', name]);
    });
  }

  /// Watches PipeWire for sink and source changes.
  ///
  /// # Returns
  /// A broadcast stream that emits once per reported event, with no payload:
  /// the card reads the authoritative devices back.
  ///
  /// # Errors
  /// The stream never reports errors; a missing `pactl` simply means no live
  /// updates, and the explicit reads still work.
  Stream<void> watchChanges() {
    late final StreamController<void> controller;
    Process? process;
    var cancelled = false;

    controller = StreamController<void>.broadcast(
      onListen: () async {
        cancelled = false;
        try {
          process = await Process.start(_executable, const ['subscribe']);
          process!.stderr.listen((_) {});
          process!.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .listen((line) {
                if (!cancelled && line.contains("Event 'change'")) {
                  controller.add(null);
                }
              }, onError: (Object _) {});
        } catch (_) {
          // No audio server to subscribe to: the card still reads on demand.
        }
      },
      onCancel: () async {
        cancelled = true;
        process?.kill();
        process = null;
      },
    );
    return controller.stream;
  }

  /// Parses the default sink and source out of the `pactl` JSON replies.
  ///
  /// Kept pure so a test can drive it with a recorded reply.
  static AudioDevices parseDevices({
    required String defaultSinkName,
    required String defaultSourceName,
    required String sinksJson,
    required String sourcesJson,
  }) {
    final decodedSinks = _decode(sinksJson);
    final decodedSources = _decode(sourcesJson);
    final sink = _entry(decodedSinks, defaultSinkName);
    final source = _entry(decodedSources, defaultSourceName);

    return AudioDevices(
      outputName: _string(sink, 'name'),
      outputLabel: _string(sink, 'description'),
      outputs: _outputs(decodedSinks, defaultSinkName),
      inputName: _string(source, 'name'),
      inputLabel: _string(source, 'description'),
      inputs: _inputs(decodedSources, defaultSourceName),
      inputVolume: _volumeOf(source),
      inputMuted: source?['mute'] == true,
    );
  }

  /// Every capture source in the reply, with the default one marked.
  ///
  /// Monitor sources are the loopback of an output, not a microphone, so they
  /// are left out of the picker. When the server names a default that is not in
  /// the list, the first real source is marked instead.
  static List<AudioInput> _inputs(Object? decoded, String defaultName) {
    if (decoded is! List) {
      return const [];
    }

    final inputs = <AudioInput>[];
    for (final entry in decoded.whereType<Map<String, dynamic>>()) {
      final name = _string(entry, 'name');
      if (name == null || name.endsWith('.monitor')) {
        continue;
      }
      inputs.add(
        AudioInput(
          name: name,
          label: _string(entry, 'description') ?? name,
          volume: _volumeOf(entry),
          muted: entry['mute'] == true,
          isDefault: name == defaultName,
        ),
      );
    }

    if (inputs.isNotEmpty && !inputs.any((input) => input.isDefault)) {
      final first = inputs.first;
      inputs[0] = AudioInput(
        name: first.name,
        label: first.label,
        volume: first.volume,
        muted: first.muted,
        isDefault: true,
      );
    }

    return inputs;
  }

  /// Every sink in the reply, with the default one marked.
  ///
  /// When the server names a default that is not in the list, the first sink is
  /// marked instead, so the card always shows which device sound uses.
  static List<AudioOutput> _outputs(Object? decoded, String defaultName) {
    if (decoded is! List) {
      return const [];
    }

    final outputs = <AudioOutput>[];
    for (final entry in decoded.whereType<Map<String, dynamic>>()) {
      final name = _string(entry, 'name');
      if (name == null) {
        continue;
      }
      outputs.add(
        AudioOutput(
          name: name,
          label: _string(entry, 'description') ?? name,
          volume: _volumeOf(entry),
          muted: entry['mute'] == true,
          isDefault: name == defaultName,
        ),
      );
    }

    if (outputs.isNotEmpty && !outputs.any((output) => output.isDefault)) {
      final first = outputs.first;
      outputs[0] = AudioOutput(
        name: first.name,
        label: first.label,
        volume: first.volume,
        muted: first.muted,
        isDefault: true,
      );
    }

    return outputs;
  }

  /// Runs one `pactl` call.
  Future<ProcessResult> _run(List<String> arguments) {
    return Process.run(_executable, arguments);
  }

  /// Reads one `Name: value` line out of the `pactl info` text.
  static String _infoValue(String info, String key) {
    for (final line in info.split('\n')) {
      if (line.startsWith('$key:')) {
        return line.substring(key.length + 1).trim();
      }
    }
    return '';
  }

  /// Decodes a JSON reply, or returns `null` when it is not JSON.
  static Object? _decode(String json) {
    try {
      return jsonDecode(json);
    } on FormatException {
      return null;
    }
  }

  /// The entry named [name], or the first real device when it is missing.
  ///
  /// Monitor sources are skipped in the fallback: they mirror an output and are
  /// not a microphone.
  static Map<String, dynamic>? _entry(Object? decoded, String name) {
    if (decoded is! List) {
      return null;
    }
    final entries = decoded.whereType<Map<String, dynamic>>().toList();
    for (final entry in entries) {
      if (entry['name'] == name) {
        return entry;
      }
    }
    for (final entry in entries) {
      final entryName = _string(entry, 'name');
      if (entryName == null || !entryName.endsWith('.monitor')) {
        return entry;
      }
    }
    return null;
  }

  /// The capture level of a source entry, as a percentage.
  static int _volumeOf(Map<String, dynamic>? entry) {
    final volume = entry?['volume'];
    if (volume is! Map || volume.isEmpty) {
      return 0;
    }
    final channel = volume.values.first;
    if (channel is! Map) {
      return 0;
    }
    final percent = channel['value_percent'];
    if (percent is! String) {
      return 0;
    }
    return int.tryParse(percent.replaceAll('%', '')) ?? 0;
  }

  /// Reads a string field, or `null` when it is absent.
  static String? _string(Map<String, dynamic>? entry, String key) {
    final value = entry?[key];
    return value is String ? value : null;
  }

  /// Runs a read-only operation and maps failures onto [RdeError].
  Future<Either<RdeError, T>> _read<T>(
    String action,
    Future<T> Function() body,
  ) async {
    try {
      return Right(await body());
    } catch (error) {
      return Left(RdeError('Could not $action: $error', RdeErrorType.dbus));
    }
  }

  /// Runs a mutating operation and maps failures onto [RdeError].
  Future<Either<RdeError, void>> _write(
    String action,
    Future<void> Function() body,
  ) async {
    try {
      await body();
      return const Right(null);
    } catch (error) {
      return Left(RdeError('Could not $action: $error', RdeErrorType.dbus));
    }
  }
}
