/// One output (sink) the audio server reports.
class AudioOutput {
  const AudioOutput({
    required this.name,
    required this.label,
    required this.volume,
    required this.muted,
    required this.isDefault,
  });

  /// PipeWire name of the sink, such as `alsa_output....__sink`.
  final String name;

  /// Human-readable description, such as "HDMI / DisplayPort 3 Output".
  final String label;

  /// Volume percentage of this output.
  final int volume;

  /// Whether this output is muted.
  final bool muted;

  /// Whether this is the sink sound is currently routed to.
  final bool isDefault;
}

/// One input (source) the audio server reports.
class AudioInput {
  const AudioInput({
    required this.name,
    required this.label,
    required this.volume,
    required this.muted,
    required this.isDefault,
  });

  /// PipeWire name of the source, such as `alsa_input....__source`.
  final String name;

  /// Human-readable description, such as "Internal Microphone".
  final String label;

  /// Capture volume percentage of this input.
  final int volume;

  /// Whether this input is muted.
  final bool muted;

  /// Whether this is the source recording is currently taken from.
  final bool isDefault;
}

/// The outputs and inputs the page controls.
///
/// `org.rde.Volume` owns the master output level, but it does not name the
/// device it drives, cannot switch devices and has no capture control, so the
/// device lists and the microphone live here. They are read from
/// PulseAudio-compatible PipeWire.
class AudioDevices {
  const AudioDevices({
    this.outputName,
    this.outputLabel,
    this.outputs = const [],
    this.inputName,
    this.inputLabel,
    this.inputs = const [],
    this.inputVolume = 0,
    this.inputMuted = false,
  });

  /// PipeWire name of the default sink.
  final String? outputName;

  /// Human-readable description of the default sink.
  final String? outputLabel;

  /// Every sink the audio server reports, in its own order.
  final List<AudioOutput> outputs;

  /// PipeWire name of the default source.
  final String? inputName;

  /// Human-readable description of the default source, such as "Microphone".
  final String? inputLabel;

  /// Every capture source the audio server reports, monitors excluded.
  final List<AudioInput> inputs;

  /// Capture volume percentage of the default source.
  final int inputVolume;

  /// Whether the default source is muted.
  final bool inputMuted;

  /// Whether a default output was found.
  bool get hasOutput => outputName != null;

  /// Whether a default input was found.
  bool get hasInput => inputName != null;

  /// Returns a copy with the given capture fields replaced.
  AudioDevices copyWith({int? inputVolume, bool? inputMuted}) {
    return AudioDevices(
      outputName: outputName,
      outputLabel: outputLabel,
      outputs: outputs,
      inputName: inputName,
      inputLabel: inputLabel,
      inputs: inputs,
      inputVolume: inputVolume ?? this.inputVolume,
      inputMuted: inputMuted ?? this.inputMuted,
    );
  }
}
