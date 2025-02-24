import 'dart:io';
import 'package:wiki_radio/api.dart';
import 'models.dart';
import 'package:flutter/material.dart';

class BrowsePlaysetPage extends StatefulWidget {
  const BrowsePlaysetPage({required this.username});
  final String username;

  @override
  State<BrowsePlaysetPage> createState() => _BrowserPlaysetState();
}

class _BrowserPlaysetState extends State<BrowsePlaysetPage>
    with WidgetsBindingObserver, TickerProviderStateMixin, RouteAware {
  TextEditingController searchController = TextEditingController();
  bool isSearchLoading = false;
  ApiPlaylist api = ApiPlaylist();
  List<WikiPlaysetSearch> searchResults = [];
  late AnimationController animationController;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addListener(() {
        setState(() {});
      });
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached) {
      exit(0);
    }
  }

  Table getResultsTables() {
    return Table(
        border: TableBorder.all(),
        columnWidths: {0: FlexColumnWidth()},
        children: searchResults
                .map((t) => TableRow(children: [
                      TableCell(
                        child: Container(
                          child: Row(children: [
                            InkWell(
                                child: Text("${t.Name}",
                                    textScaler: TextScaler.linear(1.35))),
                            buildAddButton(t.Id ?? "")
                          ]),
                          color: Color.fromARGB(255, 152, 251, 152),
                        ),
                      )
                    ]))
                .toList() ??
            []);
  }

  Column buildAddButton(String playsetId) {
    const errorPage = SnackBar(
        content: const Text('Unable to add playset. Possible duplicate.'));
    const successPage =
        SnackBar(content: const Text('Added playset to your list!'));

    return Column(children: [
      Row(children: [
        FilledButton(
            child: Container(
              child: Text('Add'),
              padding: EdgeInsets.only(
                  left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
            ),
            style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll<Color>(Colors.green),
                minimumSize: WidgetStatePropertyAll<Size>(Size(100.0, 50.0))),
            onPressed: () {
              isSearchLoading = true;
              setState(() => {});
              api
                  .setUserPlayset(widget.username, playsetId)
                  .then((results) => {
                        isSearchLoading = false,
                        ScaffoldMessenger.of(context).showSnackBar(successPage)
                      })
                  .catchError((err) => {
                        isSearchLoading = false,
                        ScaffoldMessenger.of(context).showSnackBar(errorPage)
                      });
            })
      ])
    ]);
  }

  Column buildSearchButton() {
    const cannotFindPage = SnackBar(content: const Text('Cannot find page'));
    const errorPage = SnackBar(content: const Text('Error searching page'));
    const success = SnackBar(content: const Text('Page found'));

    return Column(children: [
      //  Row(children: [
      Container(
        child: TextField(
            autofocus: true,
            style: TextStyle(fontSize: 22.0),
            decoration: InputDecoration(
                hintText: 'Playset Name', fillColor: Colors.grey),
            controller: this.searchController),
        padding:
            EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
      ),
      Row(children: [
        FilledButton(
            child: Container(
              child: Text('Get'),
              padding: EdgeInsets.only(
                  left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
            ),
            style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll<Color>(Colors.green),
                minimumSize: WidgetStatePropertyAll<Size>(Size(100.0, 50.0))),
            onPressed: () {
              if (searchController.text != "") {
                isSearchLoading = true;
                setState(() => {});
                api
                    .getPlaysetSearch(searchController.text)
                    .then((results) => {
                          isSearchLoading = false,
                          searchResults = results,
                          setState(() => {})
                        })
                    .catchError((err) => {
                          isSearchLoading = false,
                          ScaffoldMessenger.of(context).showSnackBar(errorPage)
                        });
              }
            })
      ])
    ]);
  }

  @override
  Widget build(BuildContext context) {
    var column = Column(
        mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[]);
    if (this.isSearchLoading) {
      column.children.add(LinearProgressIndicator(
          value: animationController.value, semanticsLabel: "Progress"));
    }
    column.children.add(buildSearchButton());
    column.children.add(getResultsTables());
    return Scaffold(
        appBar: AppBar(
          title: Text("Browse Playsets"),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Container(
          child: SingleChildScrollView(child: column),
        ));
  }
}
