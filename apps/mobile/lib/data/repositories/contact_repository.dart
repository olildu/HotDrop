import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:test_mobile/data/services/connection_services.dart';

class ContactRepository {
  Future<List<Contact>> fetchContacts() async {
    dev.log('Requesting contacts permission', name: 'fetchContacts');
    if (await FlutterContacts.requestPermission()) {
      dev.log('Permission granted, fetching contacts', name: 'fetchContacts');
      return await FlutterContacts.getContacts(
        withProperties: true, 
        withThumbnail: true
      );
    }
    dev.log('Permission denied, returning empty list', name: 'fetchContacts');
    return [];
  }

  Future<void> syncContacts(List<Contact> contacts) async {
    dev.log('Syncing ${contacts.length} contacts via socket', name: 'syncContacts');
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