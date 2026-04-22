import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/contact_cubit.dart';
import '../blocs/contact_ui_cubit.dart';
import '../components/contact_screen/add_contact_form.dart';
import '../components/contact_screen/contact_list.dart';
import '../components/contact_screen/contact_app_bar.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  int _lastClearFormCounter = 0;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController numberController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ContactUiCubit, ContactUiState>(
      listener: (context, uiState) {
        if (uiState.clearFormCounter != _lastClearFormCounter) {
          _lastClearFormCounter = uiState.clearFormCounter;
          nameController.clear();
          numberController.clear();
        }
      },
      child: BlocBuilder<ContactUiCubit, ContactUiState>(
        builder: (context, uiState) {
          return Column(
            children: [
              ContactAppBar(
                addContactOpened: uiState.addContactOpened,
                startedPageNavigation: uiState.startedPageNavigation,
                onBack: () => context.read<ContactUiCubit>().onBackPressed(),
                onForward: () => context.read<ContactUiCubit>().onForwardPressed(),
                onAdd: () => context.read<ContactUiCubit>().onAddPressed(),
                onSearchChanged: (value) => context.read<ContactUiCubit>().updateSearchQuery(value),
              ),
              Expanded(
                child: uiState.addContactOpened
                    ? AddContactForm(
                        pickedFile: uiState.pickedFile,
                        nameController: nameController,
                        numberController: numberController,
                        canCreateContact: uiState.canCreateContact,
                        onPickImage: () => context.read<ContactUiCubit>().pickImage(),
                        onNameChanged: (value) => context.read<ContactUiCubit>().updateName(value),
                        onNumberChanged: (value) => context.read<ContactUiCubit>().updateNumber(value),
                        onCreateContact: () => context.read<ContactUiCubit>().createContact(),
                      )
                    : BlocBuilder<ContactCubit, List<dynamic>>(
                        builder: (context, contacts) {
                          final filteredList = contacts.where((contact) {
                            final name = (contact['name'] ?? '').toLowerCase();
                            final phone = (contact['normalizedNumber'] ?? '').toString();
                            final query = uiState.searchQuery;
                            return name.contains(query.toLowerCase()) || phone.contains(query);
                          }).toList();
                          return ContactList(filteredList: filteredList);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
