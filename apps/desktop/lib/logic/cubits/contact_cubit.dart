import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer' as dev;

class ContactCubit extends Cubit<List<dynamic>> {
  ContactCubit() : super([]);

  void replaceContacts(List<dynamic> contacts) {
    dev.log('Replacing contacts with ${contacts.length} entries', name: 'replaceContacts');
    emit(contacts);
  }
}