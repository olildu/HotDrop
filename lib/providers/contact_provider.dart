import 'package:flutter/material.dart';

class ContactProvider with ChangeNotifier {
  List<dynamic> _contacts = [];

  List<dynamic> get contacts => _contacts;

  void replaceContacts(List contacts) {
    _contacts = contacts;
  }
}
