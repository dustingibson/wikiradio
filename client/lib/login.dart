import 'dart:async';
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  StreamController<bool> changeController = StreamController<bool>();
  final TextEditingController textController;
  LoginScreen(
      {super.key,
      required this.textController,
      required this.changeController});

  @override
  Widget build(BuildContext context) {
    changeController.add(false);
    return Column(children: [
      Container(
        child: TextField(
            autofocus: true,
            style: TextStyle(fontSize: 22.0),
            decoration:
                InputDecoration(hintText: 'Username', fillColor: Colors.grey),
            controller: textController),
        padding:
            EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
      ),
      FilledButton(
          child: Container(
            child: Text('Login'),
            padding:
                EdgeInsets.only(left: 10.0, right: 10.0, top: 5.0, bottom: 5.0),
          ),
          style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll<Color>(Colors.green),
              minimumSize: WidgetStatePropertyAll<Size>(Size(100.0, 50.0))),
          onPressed: () {
            if (textController.text != "") {
              this.changeController.add(true);
              Navigator.pop(context);
            }
          })
    ]);
  }
}
