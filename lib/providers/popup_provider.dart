import 'package:flutter/material.dart';

class PopupProvider with ChangeNotifier {
  bool _showPopup = false;
  String _message = "You have a new message";
  IconData _icon = Icons.message_rounded;
  double _progress = -1;

  bool get showPopup => _showPopup;
  String get message => _message;
  IconData get icon => _icon;
  double get progress => _progress;

  void show(String msg, IconData icon, {double progress = -1}) {
    _message = msg;
    _icon = icon;
    _progress = progress;
    _showPopup = true;
    notifyListeners();

    if (progress == -1) {
      Future.delayed(const Duration(seconds: 3), () {
        _showPopup = false;
        notifyListeners();
      });
    }
  }

  void updateProgress(double value) {
    _progress = value;
    notifyListeners();
  }

  void hide() {
    _showPopup = false;
    _progress = -1;
    notifyListeners();
  }

  void showTest() {
    _showPopup = true;
    notifyListeners();

    Future.delayed(const Duration(seconds: 3), () {
      _showPopup = false;
      notifyListeners();
    });
  }
}
