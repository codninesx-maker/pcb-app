import 'package:audioplayers/audioplayers.dart';

class AudioPop {
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static Future<void> play() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/pop.mp3'));
    } catch (_) {}
  }
}