abstract class AudioDevicesEvent {
  const AudioDevicesEvent();
}

/// Reads the default output and input devices.
class AudioDevicesInitEvent extends AudioDevicesEvent {
  const AudioDevicesInitEvent();
}

/// Routes sound to the output named [name].
class SelectAudioOutputEvent extends AudioDevicesEvent {
  final String name;

  const SelectAudioOutputEvent(this.name);
}

/// Takes recordings from the input named [name].
class SelectAudioInputEvent extends AudioDevicesEvent {
  final String name;

  const SelectAudioInputEvent(this.name);
}

/// The microphone slider moved to [volume]; the write is committed once the
/// drag settles.
class MicrophoneVolumeChangedEvent extends AudioDevicesEvent {
  final int volume;

  const MicrophoneVolumeChangedEvent(this.volume);
}

/// Writes [volume] to the microphone now.
class MicrophoneVolumeSetEvent extends AudioDevicesEvent {
  final int volume;

  const MicrophoneVolumeSetEvent(this.volume);
}

/// Mutes the microphone, or unmutes it again.
class ToggleMicrophoneMuteEvent extends AudioDevicesEvent {
  const ToggleMicrophoneMuteEvent();
}

/// PipeWire reported a sink or source change.
class AudioDevicesChangedEvent extends AudioDevicesEvent {
  const AudioDevicesChangedEvent();
}
