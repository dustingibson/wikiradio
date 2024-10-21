import 'dart:async';
import 'package:audio_service/audio_service.dart';

import 'api.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

// Credit mostly AudioPlayers example package for skeleton. Replaced with just_audio

class PlayerWidget extends StatefulWidget {
  const PlayerWidget(
      {super.key,
      required this.player,
      required this.api,
      required this.toNextController});
  final AudioPlayer player;
  final ApiPlaylist api;
  final StreamController<int> toNextController;

  @override
  State<PlayerWidget> createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends State<PlayerWidget> {
  int seekId = 0;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;

  bool get _isPlaying => player.playing;

  bool get _isPaused => !player.playing;

  String get _durationText =>
      player.duration?.toString().split('.').first ?? '';

  String get _positionText =>
      player.position?.toString().split('.').first ?? '';

  AudioPlayer get player => widget.player;

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const Key('play_button'),
              onPressed: _isPlaying ? null : _play,
              iconSize: 48.0,
              icon: const Icon(Icons.play_arrow),
              color: color,
            ),
            IconButton(
              key: const Key('pause_button'),
              onPressed: _isPlaying ? _pause : null,
              iconSize: 48.0,
              icon: const Icon(Icons.pause),
              color: color,
            ),
            IconButton(
              key: const Key('stop_button'),
              onPressed: _isPlaying || _isPaused ? _stop : null,
              iconSize: 48.0,
              icon: const Icon(Icons.stop),
              color: color,
            ),
            IconButton(
              key: const Key('next_button'),
              onPressed: _next,
              iconSize: 48.0,
              icon: const Icon(Icons.skip_next),
              color: color,
            ),
            IconButton(
              key: const Key('fast_button'),
              onPressed: _speed,
              iconSize: 48.0,
              icon: const Icon(Icons.speed),
              color: color,
            )
          ],
        ),
        Slider(
          onChanged: (value) {
            final duration = player.duration;
            if (duration == null) {
              return;
            }
            final position = value * duration.inMilliseconds;
            player.seek(Duration(milliseconds: position.round()));
          },
          value: (player.position != null &&
                  player.duration != null &&
                  player.position!.inMilliseconds > 0 &&
                  player.position!.inMilliseconds <
                      player.duration!.inMilliseconds)
              ? player.position!.inMilliseconds /
                  player.duration!.inMilliseconds
              : 0.0,
        ),
        Text(
          player.position != null
              ? '$_positionText / $_durationText - x${player.speed.toString()}'
              : player.duration != null
                  ? _durationText
                  : '',
          style: const TextStyle(fontSize: 16.0),
        ),
      ],
    );
  }

  void _initStreams() {
    _playerCompleteSubscription = player.playbackEventStream.listen((event) {
      setState(() => {});
    });
    player.positionStream.listen((pos) => setState(() => {}));
  }

  Future<void> _play() async {
    await player.play();
    setState(() => {});
  }

  Future<void> _pause() async {
    await player.pause();
    setState(() => {});
  }

  Future<void> _stop() async {
    await player.stop();
    setState(() => {});
  }

  Future<void> _next() async {
    widget.toNextController.add(seekId++);
    await player.seekToNext();
    setState(() => {});
  }

  Future<void> _speed() async {
    player.setSpeed(player.speed < 2.0 ? player.speed + 0.25 : 1.0);
    setState(() => {});
  }
}
