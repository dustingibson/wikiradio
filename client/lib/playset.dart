import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:wiki_radio/api.dart';
import 'package:wiki_radio/audio_handler.dart';
import 'package:wiki_radio/main.dart';
import 'package:wiki_radio/tracks.dart';
import 'models.dart';
import 'package:flutter/material.dart';

class PlaysetPage extends StatefulWidget {
  const PlaysetPage(
      {required this.username,
      required this.playsetId,
      required this.playsetName,
      required this.audioProvider,
      required this.playsetPlaylistId});
  final String username;
  final String playsetId;
  final String playsetName;
  final AudioProvider audioProvider;
  final int? playsetPlaylistId;

  @override
  State<PlaysetPage> createState() => _PlaysetState();
}

class _PlaysetState extends State<PlaysetPage>
    with WidgetsBindingObserver, TickerProviderStateMixin, RouteAware {
  ApiPlaylist api = new ApiPlaylist();
  WikiPlaysetDetails? wikiPlaysetDetails = new WikiPlaysetDetails();

  @override
  void initState() {
    super.initState();
    checkPlaysetDetails();
  }

  void checkPlaysetDetails() {
    api.getPlaysetDetails(widget.playsetId, widget.username).then((value) => {
          wikiPlaysetDetails = value,
          setState(
            () {},
          )
        });
  }

  @override
  void didPopNext() {
    super.didPopNext();
    checkPlaysetDetails();
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached) {
      exit(0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute<dynamic>);
  }

  WikiPlaysetPlaylist? getNextPlayset(int index) {
    if (index + 1 >= (wikiPlaysetDetails?.PlaysetPlaylist?.length ?? 0)) {
      return wikiPlaysetDetails?.PlaysetPlaylist?.first;
    }
    return wikiPlaysetDetails?.PlaysetPlaylist?.elementAt(index + 1);
  }

  void navigateToTracks(
      String wikiId, String title, WikiPlaysetPlaylist playsetPlaylist) {
    api
        .setPlaysetProgress(widget.username, playsetPlaylist.Id ?? 0)
        .then((value) => {
              Navigator.push(
                  context,
                  CupertinoPageRoute(
                      builder: (context) => TracksPage(
                            title: title,
                            wikiId: wikiId,
                            username: widget.username,
                            audioProvider: widget.audioProvider,
                            playsetPlaylist: playsetPlaylist,
                          )))
            });
  }

  Table getTables() {
    return Table(
        border: TableBorder.all(),
        columnWidths: {0: FlexColumnWidth()},
        children: wikiPlaysetDetails?.PlaysetPlaylist!
                .map((t) => TableRow(children: [
                      TableCell(
                        child: Container(
                            padding: EdgeInsets.only(
                                bottom: 10.0, top: 10.0, left: 4.0, right: 4.0),
                            child: new InkWell(
                                child: new Text("${t?.ArticleTitle ?? ""}",
                                    textScaler: TextScaler.linear(1.35)),
                                onTap: () => navigateToTracks(
                                    t?.ArticleId ?? "",
                                    t?.ArticleTitle ?? "Tracks",
                                    t)),
                            color: t?.Id ==
                                    wikiPlaysetDetails?.CurrentPlaysetPlaylistId
                                ? Color.fromARGB(255, 138, 147, 215)
                                : Color.fromARGB(255, 152, 251, 152)),
                      ),
                    ]))
                .toList() ??
            []);
  }

  @override
  Widget build(BuildContext context) {
    var column = Column(
        mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[]);
    if (this.wikiPlaysetDetails?.PlaysetPlaylist != null &&
        (this.wikiPlaysetDetails?.PlaysetPlaylist!.length ?? 0) >= 0)
      column.children.add(getTables());
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.playsetName),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Container(
          child: SingleChildScrollView(child: column),
        ));
  }
}
