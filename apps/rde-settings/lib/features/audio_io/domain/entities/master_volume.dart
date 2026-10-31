/// Master output volume as the `org.rde.Volume` service reports it.
///
/// The service owns the mixer, so this is a snapshot: every field is read back
/// from the daemon after a change instead of being derived here.
class MasterVolume {
  const MasterVolume({
    required this.volume,
    required this.muted,
    required this.step,
    required this.minVolume,
    required this.maxVolume,
  });

  /// Current master volume percentage.
  final int volume;

  /// Whether playback is muted.
  final bool muted;

  /// Percentage the service moves the volume by for its own shortcuts.
  final int step;

  /// Lowest volume the service accepts, normally `0`.
  final int minVolume;

  /// Highest volume the service accepts, normally `100`.
  final int maxVolume;

  /// Whether the slider has a range to move over.
  bool get hasRange => maxVolume > minVolume;

  /// Returns a copy with the given fields replaced.
  MasterVolume copyWith({int? volume, bool? muted, int? step}) {
    return MasterVolume(
      volume: volume ?? this.volume,
      muted: muted ?? this.muted,
      step: step ?? this.step,
      minVolume: minVolume,
      maxVolume: maxVolume,
    );
  }
}
