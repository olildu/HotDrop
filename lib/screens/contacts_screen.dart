import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:test/components/contact_screen/add_contact_form.dart';
import 'package:test/components/contact_screen/contact_list.dart';
import 'package:test/constants/globals.dart';
import 'package:test/providers/contact_provider.dart';
import 'package:test/components/contact_screen/contact_app_bar.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  List<dynamic> filteredList = [];
  XFile? pickedFile;
  bool addContactOpened = false;
  bool startedPageNavigation = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController numberController = TextEditingController();
  final TextEditingController searchControllerContacts = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredList = Provider.of<ContactProvider>(navigatorKey.currentContext!, listen: false).contacts;
    searchControllerContacts.addListener(filterContacts);
  }

  void filterContacts() {
    String query = searchControllerContacts.text.toLowerCase();
    final contacts = context.read<ContactProvider>().contacts;

    setState(() {
      filteredList = contacts.where((contact) {
        final name = (contact["name"] ?? "").toLowerCase();
        final phone = contact["normalizedNumber"] ?? "";
        return name.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  void _createContact() {
    final name = nameController.text.trim();
    final number = numberController.text.trim();

    if (name.isEmpty || number.isEmpty) return;

    final newContact = {
      "name": name,
      "normalizedNumber": number,
      "imagePath": pickedFile?.path,
    };

    // context.read<ContactProvider>().addContact(newContact);

    nameController.clear();
    numberController.clear();
    setState(() {
      pickedFile = null;
      addContactOpened = false;
    });
    filterContacts(); 
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
            if (!startedPageNavigation) return;
            setState(() => addContactOpened = true);
          },
          onAdd: () => setState(() {
            addContactOpened = true;
            startedPageNavigation = true;
          }),
        ),
        addContactOpened
          ? AddContactForm(
              pickedFile: pickedFile,
              nameController: nameController,
              numberController: numberController,
              onImagePick: (file) => setState(() => pickedFile = file),
              onCreateContact: _createContact,
            )
          : ContactList(filteredList: filteredList),
      ],
    );
  }
}
