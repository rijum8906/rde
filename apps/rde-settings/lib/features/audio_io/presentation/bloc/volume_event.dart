abstract class VolumeEvent {
  const VolumeEvent();
}

/// Reads the volume the service reports.
class VolumeInitEvent extends VolumeEvent {
  const VolumeInitEvent();
}

/// The slider moved to [volume]; the write is committed once the drag settles.
class VolumeSliderChangedEvent extends VolumeEvent {
  final int volume;

  const VolumeSliderChangedEvent(this.volume);
}

/// Writes [volume] to the service now, without waiting for a drag to settle.
class VolumeSetEvent extends VolumeEvent {
  final int volume;

  const VolumeSetEvent(this.volume);
}

/// Mutes playback, or unmutes it again.
class ToggleVolumeMuteEvent extends VolumeEvent {
  const ToggleVolumeMuteEvent();
}

/// The service reported a volume or mute change another client made.
class VolumeServiceChangedEvent extends VolumeEvent {
  const VolumeServiceChangedEvent();
}
