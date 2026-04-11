import 'dart:convert';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../services/connection_services.dart';

class ContactRepository {
  Future<List<Contact>> fetchContacts() async {
    if (await FlutterContacts.requestPermission()) {
      return await FlutterContacts.getContacts(
        withProperties: true, 
        withThumbnail: true
      );
    }
    return [];
  }

  Future<void> syncContacts(List<Contact> contacts) async {
    final contactData = contacts.map((contact) => {
      "id": contact.id,
      "displayName": contact.displayName,
      "normalizedNumber": contact.phones.isNotEmpty 
          ? contact.phones[0].normalizedNumber 
          : null,
    }).toList();

    await DartFunction().sendDataToSocket(jsonEncode({
      "type": "contacts",
      "format": "list",
      "content": contactData,
    }));
  }
}