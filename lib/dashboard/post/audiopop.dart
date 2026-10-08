import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioPop {
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static Future<void> play() async {
    try {
      await _audioPlayer.stop();
      // Try 'pop.mp3' if your assets: declaration is '- assets/sounds/'
      await _audioPlayer.play(AssetSource('sounds/pop.mp3'));
      debugPrint("SUCCESS: Pop sound played!");
    } catch (e) {
      debugPrint("ERROR playing pop sound: $e");
    }
  }
}