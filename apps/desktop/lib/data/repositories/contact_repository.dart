import 'dart:developer' as dev;

class ContactRepository {
  // Logic for handling raw contact data received via socket
  List<Map<String, dynamic>> parseRawContacts(List<dynamic> content) {
    dev.log('Parsing ${content.length} contact entries', name: 'parseRawContacts');
    return content.map((x) {
      return {
        "name": x["displayName"] ?? "Unknown",
        "id": x["id"] ?? "Unknown",
        "normalizedNumber": x["normalizedNumber"],
      };
    }).toList();
  }
}