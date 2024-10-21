import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:wiki_radio/tracks.dart';

class AudioProvider {
  // Private constructor to prevent external instantiation.
  AudioProvider._();

  // The single instance of the class.
  static final AudioProvider _instance = AudioProvider._();

  // Factory constructor to provide access to the singleton instance.
  factory AudioProvider() {
    return _instance;
  }

  // Add your methods and properties here.
  MyAudioHandler? audioHandler;

  Future<void> init() async {
    if (audioHandler == null) {
      audioHandler = await AudioService.init(
        builder: () => MyAudioHandler(),
        config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.ryanheise.myapp.channel.audio',
            androidNotificationChannelName: 'Audio Playback',
            androidNotificationOngoing: true),
      );
    }
  }
}
