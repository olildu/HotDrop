import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

class ContactUiState {
  final XFile? pickedFile;
  final bool addContactOpened;
  final bool startedPageNavigation;
  final String searchQuery;
  final bool isNameValid;
  final bool isNumberValid;
  final int clearFormCounter;

  const ContactUiState({
    this.pickedFile,
    this.addContactOpened = false,
    this.startedPageNavigation = false,
    this.searchQuery = '',
    this.isNameValid = false,
    this.isNumberValid = false,
    this.clearFormCounter = 0,
  });

  bool get canCreateContact => isNameValid && isNumberValid;

  ContactUiState copyWith({
    XFile? pickedFile,
    bool clearPickedFile = false,
    bool? addContactOpened,
    bool? startedPageNavigation,
    String? searchQuery,
    bool? isNameValid,
    bool? isNumberValid,
    int? clearFormCounter,
  }) {
    return ContactUiState(
      pickedFile: clearPickedFile ? null : pickedFile ?? this.pickedFile,
      addContactOpened: addContactOpened ?? this.addContactOpened,
      startedPageNavigation: startedPageNavigation ?? this.startedPageNavigation,
      searchQuery: searchQuery ?? this.searchQuery,
      isNameValid: isNameValid ?? this.isNameValid,
      isNumberValid: isNumberValid ?? this.isNumberValid,
      clearFormCounter: clearFormCounter ?? this.clearFormCounter,
    );
  }
}

class ContactUiCubit extends Cubit<ContactUiState> {
  ContactUiCubit() : super(const ContactUiState());

  void onBackPressed() {
    emit(state.copyWith(addContactOpened: false));
  }

  void onForwardPressed() {
    if (state.startedPageNavigation) {
      emit(state.copyWith(addContactOpened: true));
    }
  }

  void onAddPressed() {
    emit(
      state.copyWith(
        addContactOpened: true,
        startedPageNavigation: true,
      ),
    );
  }

  void updateSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  void updateName(String name) {
    emit(state.copyWith(isNameValid: name.trim().isNotEmpty));
  }

  void updateNumber(String number) {
    final isValid = RegExp(r'^\+?\d{7,15}$').hasMatch(number.trim());
    emit(state.copyWith(isNumberValid: isValid));
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      emit(state.copyWith(pickedFile: file));
    }
  }

  void createContact() {
    emit(
      state.copyWith(
        clearPickedFile: true,
        addContactOpened: false,
        isNameValid: false,
        isNumberValid: false,
        clearFormCounter: state.clearFormCounter + 1,
      ),
    );
  }
}
