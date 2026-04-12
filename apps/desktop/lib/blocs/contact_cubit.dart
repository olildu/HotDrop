import 'package:flutter_bloc/flutter_bloc.dart';

class ContactCubit extends Cubit<List<dynamic>> {
  ContactCubit() : super([]);

  void replaceContacts(List<dynamic> contacts) {
    emit(contacts);
  }
}