class AudioIoSettings {
  final double outputVolume;
  final double inputVolume;
  final bool noiseReduction;
  final bool eqToggle;

  const AudioIoSettings({
    required this.outputVolume,
    required this.inputVolume,
    required this.noiseReduction,
    required this.eqToggle,
  });

  AudioIoSettings copyWith({
    double? outputVolume,
    double? inputVolume,
    bool? noiseReduction,
    bool? eqToggle,
  }) {
    return AudioIoSettings(
      outputVolume: outputVolume ?? this.outputVolume,
      inputVolume: inputVolume ?? this.inputVolume,
      noiseReduction: noiseReduction ?? this.noiseReduction,
      eqToggle: eqToggle ?? this.eqToggle,
    );
  }
}
