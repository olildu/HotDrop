import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../blocs/contact_cubit.dart';
import '../components/contact_screen/add_contact_form.dart';
import '../components/contact_screen/contact_list.dart';
import '../components/contact_screen/contact_app_bar.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  XFile? pickedFile;
  bool addContactOpened = false;
  bool startedPageNavigation = false;
  String searchQuery = "";

  final TextEditingController nameController = TextEditingController();
  final TextEditingController numberController = TextEditingController();
  final TextEditingController searchControllerContacts = TextEditingController();

  void _createContact() {
    // Logic for local contact creation if needed
    nameController.clear();
    numberController.clear();
    setState(() {
      pickedFile = null;
      addContactOpened = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ContactAppBar(
          addContactOpened: addContactOpened,
          startedPageNavigation: startedPageNavigation,
          searchController: searchControllerContacts,
          onBack: () => setState(() => addContactOpened = false),
          onForward: () {
            if (startedPageNavigation) setState(() => addContactOpened = true);
          },
          onAdd: () => setState(() {
            addContactOpened = true;
            startedPageNavigation = true;
          }),
        ),
        Expanded(
          child: addContactOpened
              ? AddContactForm(
                  pickedFile: pickedFile,
                  nameController: nameController,
                  numberController: numberController,
                  onImagePick: (file) => setState(() => pickedFile = file),
                  onCreateContact: _createContact,
                )
              : BlocBuilder<ContactCubit, List<dynamic>>(
                  builder: (context, contacts) {
                    final filteredList = contacts.where((contact) {
                      final name = (contact["name"] ?? "").toLowerCase();
                      final phone = (contact["normalizedNumber"] ?? "").toString();
                      return name.contains(searchQuery.toLowerCase()) || phone.contains(searchQuery);
                    }).toList();
                    return ContactList(filteredList: filteredList);
                  },
                ),
        ),
      ],
    );
  }
}
