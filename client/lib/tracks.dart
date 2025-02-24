import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:wiki_radio/api.dart';
import 'package:wiki_radio/audio_handler.dart';
import 'models.dart';
import 'player.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class TracksPage extends StatefulWidget {
  const TracksPage(
      {super.key,
      required this.title,
      required this.wikiId,
      required this.username,
      required this.audioProvider,
      required this.playsetPlaylist});
  final String title;
  final String wikiId;
  final String username;
  final AudioProvider audioProvider;
  final WikiPlaysetPlaylist? playsetPlaylist;

  @override
  State<TracksPage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<TracksPage> with WidgetsBindingObserver {
  final Future<SharedPreferences> localStorage$ =
      SharedPreferences.getInstance();
  StreamController<int> toNextController = new StreamController();
  ApiPlaylist api = new ApiPlaylist();
  late Column column;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      widget.audioProvider?.init().then((t) => {
            widget.audioProvider?.audioHandler?.username = widget.username,
            widget.audioProvider?.audioHandler?.controller.stream
                .listen((onData) => setState(() => {})),
            widget.audioProvider?.audioHandler?.moveOnController
                .addListener(toTheNextArticleListener),
            widget.audioProvider?.audioHandler?.buildPlaylist(widget.wikiId),
            //.then((results) => {this.setState(() => {})});
            toNextController?.stream.listen(
                (chg) => {widget.audioProvider?.audioHandler?.seekToNext()}),
            widget.audioProvider?.audioHandler?.clear()
          });
    });
  }

  toTheNextArticleListener() {
    if (widget.playsetPlaylist != null) toTheNextArticle();
  }

  toTheNextArticle() {
    api
        .getNextInPlaylist(widget.playsetPlaylist?.Id ?? 0, widget.username)
        .then((value) => {
              Navigator.pushReplacement(
                  context,
                  CupertinoPageRoute(
                      builder: (context) => TracksPage(
                            title: value.ArticleTitle ?? "",
                            wikiId: value.ArticleId ?? "",
                            username: widget.username,
                            audioProvider: widget.audioProvider,
                            playsetPlaylist: value,
                          )))
            });
  }

  String fromIntToString(int? val) {
    if (val == null) return "NA";
    NumberFormat f = NumberFormat('###,###', 'en_US');
    return f.format(val);
  }

  Table getTables() {
    int cnt = 0;
    return Table(
        border: TableBorder.all(),
        columnWidths: {0: FlexColumnWidth()},
        children: widget.audioProvider?.audioHandler?.tracks
                .map((t) => TableRow(children: [
                      TableCell(
                        child: Container(
                            padding: EdgeInsets.only(
                                bottom: 10.0, top: 10.0, left: 4.0, right: 4.0),
                            child: new InkWell(
                                child: new Text("${t.SectionTitle}",
                                    textScaler: TextScaler.linear(1.35)),
                                onTap: () => setTrackIndex(t)),
                            color: t.IsPlaying
                                ? Color.fromARGB(255, 152, 251, 152)
                                : Color.fromARGB(255, 200, 200, 200)),
                      ),
                    ]))
                .toList() ??
            []);
  }

  void setTrackIndex(WikiArticle t) {
    widget.audioProvider?.audioHandler?.setTrackIndex(t);
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached) {
      exit(0);
    }
  }

  @override
  void dispose() {
    widget.audioProvider?.audioHandler?.moveOnController
        .removeListener(toTheNextArticleListener);
    //widget.audioProvider?.audioHandler?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    column = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[],
    );
    if (widget.audioProvider?.audioHandler != null) {
      column.children.add(PlayerWidget(
          player:
              widget.audioProvider?.audioHandler?._player ?? new AudioPlayer(),
          api: widget.audioProvider?.audioHandler?.api ?? new ApiPlaylist(),
          toNextController: toNextController));
    }
    column.children.add(getTables());
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Container(child: SingleChildScrollView(child: column)),
    );
  }
}

class MyAudioHandler extends BaseAudioHandler
    with
        QueueHandler, // mix in default queue callback implementations
        SeekHandler {
  // mix in default seek callback implementations

  final AudioPlayer _player = AudioPlayer();
  final ApiPlaylist api = ApiPlaylist();
  late List<WikiArticle> tracks = [];
  int counts = 0;
  String username = '';
  StreamController<List<WikiArticle>> controller =
      StreamController<List<WikiArticle>>.broadcast();
  ValueNotifier<String?> moveOnController = ValueNotifier<String?>(null);

  MyAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  void clear() {
    tracks = [];
  }

  // The most common callbacks:
  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) async {}

  Future<void> seekToNext() => getNext();

  @override
  Future<void> skipToNext() => getNext();

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    switch (button) {
      //case MediaButton.play:
      case 85:
      case 127:
      case 126:
      case 86:
      case MediaButton.media:
        if (_player.playing) {
          _player.pause();
        } else {
          _player.play();
        }
        break;
      case 87:
      case MediaButton.next:
        await getNext();
        break;
      default:
        break;
    }
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    var curTrack = getCurrentTrack();
    if (curTrack != null) {
      mediaItem.add(MediaItem(
          id: curTrack.Url.toString(),
          album: curTrack.ArticleTitle,
          title: curTrack.SectionTitle ?? "",
          artist: curTrack.ArticleTitle,
          duration: _player.duration));
    }
    if (event.processingState == ProcessingState.completed) {
      getNext();
    }
    bool isPlaying = _player.playing;
    return PlaybackState(
        controls: [
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.pause,
          MediaControl.skipToNext
        ],
        systemActions: const {MediaAction.seek},
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: isPlaying,
        androidCompactActionIndices: const [0, 1, 3],
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: 0);
  }

  void playNew() async {
    var curTrack = getCurrentTrack();
    if (curTrack != null) {
      try {
        await api.setAudioProgress(username, curTrack.SectionId ?? "", 0);
        await _player.setAudioSource(api.getAudioUrl(curTrack.SectionId ?? ""));
        await _player.play();
      } catch (_) {
        await Future.delayed(Duration(seconds: 5));
        await getNext();
      }
    }
  }

  Future<void> buildPlaylist(String wikiId) async {
    tracks = (await Future.wait([api.getArticle(username, wikiId)])).first;
    var newTrack = tracks.where((t) => t.Status != "COMPLETED").firstOrNull;
    if (newTrack == null) {
      newTrack = tracks.first;
    }
    newTrack.IsPlaying = true;
    controller.sink.add(tracks);
    playNew();
  }

  WikiArticle? getCurrentTrack() {
    return tracks.where((t) => t.IsPlaying).firstOrNull;
  }

  void setNextTrack() {
    var curTrack = getCurrentTrack();
    if (curTrack != null) {
      var index = tracks.indexOf(curTrack) + 1;
      if (index >= tracks.length) {
        index = 0;
        moveOnController.value =
            "${curTrack.ArticleId} ${curTrack.ArticleTitle}";
      }
      curTrack.IsPlaying = false;
      tracks[index].IsPlaying = true;
    }
  }

  void setTrackIndex(WikiArticle selTrack) {
    var index = tracks.indexOf(selTrack);
    var curTrack = getCurrentTrack();
    if (index >= tracks.length) index = 0;
    if (curTrack != null) {
      curTrack.IsPlaying = false;
      tracks[index].IsPlaying = true;
    }
    controller.sink.add(tracks);
    playNew();
  }

  Future<void> getNext() async {
    var curTrack = getCurrentTrack();
    if (curTrack != null) {
      (await Future.wait([
        api.setOverallProgress(username, curTrack.SectionId ?? "", "COMPLETED")
      ]));
      setNextTrack();
      controller.sink.add(tracks);
      curTrack = getCurrentTrack();
      if (curTrack != null)
        (await Future.wait([
          api.setOverallProgress(
              username, curTrack.SectionId ?? "", "INPROGRESS")
        ]));

      playNew();
    }
  }

  disposePlayer() {
    _player.dispose();
  }

  dispose() {
    var curTrack = getCurrentTrack();
    if (curTrack != null) {
      api
          .setAudioProgress(
              username, curTrack?.SectionId ?? "", _player.position.inSeconds)
          .then((val) => {disposePlayer()});
    } else {
      disposePlayer();
    }
  }
}
