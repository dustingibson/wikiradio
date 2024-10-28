import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/widgets.dart';
import 'package:wiki_radio/api.dart';
import 'package:wiki_radio/audio_handler.dart';
import 'package:wiki_radio/login.dart';
import 'package:wiki_radio/tracks.dart';
import 'models.dart';
import 'player.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';

void main() {
  runApp(const MyApp());
}

final RouteObserver<PageRoute> routeObserver = new RouteObserver<PageRoute>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wiki Radio',
      navigatorObservers: <NavigatorObserver>[routeObserver],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Wiki Radio'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with WidgetsBindingObserver, TickerProviderStateMixin, RouteAware {
  final Future<SharedPreferences> localStorage$ =
      SharedPreferences.getInstance();
  final AudioProvider audioProvider = AudioProvider();
  TextEditingController searchController = new TextEditingController();
  TextEditingController usernameController = new TextEditingController();
  StreamController<bool> usernameChangeController = new StreamController();
  StreamController<int> toNextController = new StreamController();
  bool isSearchLoading = false;
  ApiPlaylist api = new ApiPlaylist();
  List<WikiRecent> recent = [];
  late Column column;
  late AnimationController animationController;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      /// [AnimationController]s can be created with `vsync: this` because of
      /// [TickerProviderStateMixin].
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addListener(() {
        setState(() {});
      });
    animationController.repeat();
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    localStorage$
        .then((ls) => {usernameController.text = ls.getString("user") ?? ""});
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      usernameChangeController?.stream.listen((chg) => {
            if (chg)
              {
                localStorage$.then((ls) => {
                      ls.setString("user", usernameController.text ?? ""),
                    }),
                api.getUser(usernameController.text).then((userResults) => {
                      api.getRecent(userResults?.Username ?? "default").then(
                          (recentResults) =>
                              {recent = recentResults, this.setState(() => {})})
                    })
              }
          });
      showModalBottomSheet(
          context: context,
          isDismissible: false,
          enableDrag: false,
          builder: (ctx) => LoginScreen(
              textController: usernameController,
              changeController: usernameChangeController));
    });
  }

  String fromIntToString(int? val) {
    if (val == null) return "NA";
    NumberFormat f = NumberFormat('###,###', 'en_US');
    return f.format(val);
  }

  Table getTables() {
    return Table(
        border: TableBorder.all(),
        columnWidths: {0: FlexColumnWidth()},
        children: recent
                .map((t) => TableRow(children: [
                      TableCell(
                        child: Container(
                            padding: EdgeInsets.only(
                                bottom: 10.0, top: 10.0, left: 4.0, right: 4.0),
                            child: new InkWell(
                                child: new Text("${t.ArticleTitle}",
                                    textScaler: TextScaler.linear(1.35)),
                                onTap: () => navigateToTracks(t.ArticleId ?? "",
                                    t?.ArticleTitle ?? "Tracks")),
                            color: Color.fromARGB(255, 152, 251, 152)),
                      ),
                    ]))
                .toList() ??
            []);
  }

  @override
  void didPopNext() {
    super.didPopNext();
    api.getRecent(usernameController.text).then(
        (recentResults) => {recent = recentResults, this.setState(() => {})});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  void navigateToTracks(String wikiId, String title) {
    Navigator.push(
        context,
        CupertinoPageRoute(
            builder: (context) => TracksPage(
                title: title,
                wikiId: wikiId,
                username: usernameController.text,
                audioProvider: audioProvider)));
  }

  Column buildSearchButton() {
    const cannotFindPage = SnackBar(content: const Text('Cannot find page'));

    const errorPage = SnackBar(content: const Text('Error searching page'));

    const success = SnackBar(content: const Text('Page found'));

    return Column(children: [
      Container(
        child: TextField(
            autofocus: true,
            style: TextStyle(fontSize: 22.0),
            decoration: InputDecoration(
                hintText: 'Wikipedia Article', fillColor: Colors.grey),
            controller: this.searchController),
        padding:
            EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
      ),
      FilledButton(
          child: Container(
            child: Text('Get'),
            padding:
                EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
          ),
          style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll<Color>(Colors.green),
              minimumSize: WidgetStatePropertyAll<Size>(Size(100.0, 50.0))),
          onPressed: () {
            if (searchController.text != "") {
              isSearchLoading = true;
              setState(() => {});
              api
                  .getSearch(usernameController.text, searchController.text)
                  .then((results) => {
                        isSearchLoading = false,
                        if (results?.ArticleId != "")
                          {
                            ScaffoldMessenger.of(context).showSnackBar(success),
                            {
                              navigateToTracks(results?.ArticleId ?? "Default",
                                  results?.ArticleTitle ?? "Tracks")
                            }
                          }
                        else
                          {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(cannotFindPage)
                          }
                      })
                  .catchError((err) => {
                        isSearchLoading = false,
                        ScaffoldMessenger.of(context).showSnackBar(errorPage)
                      });
            }
          })
    ]);
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
    super.dispose();
    routeObserver.unsubscribe(this);
  }

  @override
  Widget build(BuildContext context) {
    column = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[],
    );
    if (this.isSearchLoading) {
      column.children.add(Text(
          "Searching and processing wiki page. May take a few minutes..."));
      column.children.add(LinearProgressIndicator(
        value: animationController.value,
        semanticsLabel: "Progress",
      ));
    }
    column.children.add(buildSearchButton());
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
