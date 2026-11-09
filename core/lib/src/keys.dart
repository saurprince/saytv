/// Android key codes the TV accepts through the remote protocol (all verified on the tested TV, see NOTES.md).
/// Not available over this protocol on the tested TV: TV_INPUT 178, HDMI 243-246, WAKEUP 224 (Home wakes the screen).
class Keys {
  static const home = 3;
  static const back = 4;
  static const up = 19;
  static const down = 20;
  static const left = 21;
  static const right = 22;
  static const center = 23;
  static const volumeUp = 24;
  static const volumeDown = 25;
  static const power = 26;
  static const menu = 82;
  static const playPause = 85;
  static const stop = 86;
  static const next = 87;
  static const previous = 88;
  static const rewind = 89;
  static const fastForward = 90;
  static const mute = 164; // audio mute. NOT 91, that is the microphone.
  static const channelUp = 166;
  static const channelDown = 167;
  static const play = 126;
  static const pause = 127;

  static const byName = <String, int>{
    'HOME': home,
    'BACK': back,
    'UP': up,
    'DOWN': down,
    'LEFT': left,
    'RIGHT': right,
    'CENTER': center,
    'OK': center,
    'VOLUME_UP': volumeUp,
    'VOLUME_DOWN': volumeDown,
    'POWER': power,
    'MENU': menu,
    'PLAY_PAUSE': playPause,
    'STOP': stop,
    'NEXT': next,
    'PREVIOUS': previous,
    'REWIND': rewind,
    'FAST_FORWARD': fastForward,
    'MUTE': mute,
    'CHANNEL_UP': channelUp,
    'CHANNEL_DOWN': channelDown,
    'PLAY': play,
    'PAUSE': pause,
  };
}
