import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_windows/image_picker_windows.dart';

class AddContactForm extends StatefulWidget {
  final XFile? pickedFile;
  final TextEditingController nameController;
  final TextEditingController numberController;
  final Function(XFile?) onImagePick;
  final VoidCallback onCreateContact;

  const AddContactForm({
    required this.pickedFile,
    required this.nameController,
    required this.numberController,
    required this.onImagePick,
    required this.onCreateContact,
    super.key,
  });

  @override
  State<AddContactForm> createState() => _AddContactFormState();
}

class _AddContactFormState extends State<AddContactForm> {
  bool isNameValid = false;
  bool isNumberValid = false;

  @override
  void initState() {
    super.initState();
    widget.nameController.addListener(_validateInputs);
    widget.numberController.addListener(_validateInputs);
  }

  void _validateInputs() {
    final numberValid = RegExp(r'^\+?\d{7,15}$').hasMatch(widget.numberController.text.trim());
    setState(() {
      isNumberValid = numberValid;
    });
  }


  @override
  void dispose() {
    widget.nameController.removeListener(_validateInputs);
    widget.numberController.removeListener(_validateInputs);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.all(20.sp),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () async {
                final picker = ImagePickerWindows();
                final file = await picker.getImage(source: ImageSource.gallery);
                widget.onImagePick(file);
              },
              child: CircleAvatar(
                radius: 60.r,
                backgroundColor: const Color(0xFFEFEFEF),
                backgroundImage: widget.pickedFile != null ? FileImage(File(widget.pickedFile!.path)) : null,
                child: widget.pickedFile == null
                    ? Icon(Icons.add_rounded, size: 40.sp, color: Colors.grey)
                    : null,
              ),
            ),
            Gap(30.h),
            InputField(controller: widget.nameController, hint: "Contact Name"),
            Gap(10.h),
            InputField(controller: widget.numberController, hint: "Contact Number"),
            Gap(20.h),
            ElevatedButton(
              onPressed: isNameValid && isNumberValid ? widget.onCreateContact : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                disabledBackgroundColor: Colors.grey[300],
                minimumSize: Size(200.w, 40.h),
              ),
              child: Text(
                "Create Contact",
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: isNameValid && isNumberValid ? Colors.white : Colors.black54,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const InputField({required this.controller, required this.hint, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300.w,
      height: 40.h,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12.sp, color: const Color(0xFFA1A1A1), fontWeight: FontWeight.w300),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.r),
            borderSide: const BorderSide(color: Color(0xFFECECEC)),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 10.w),
        ),
      ),
    );
  }
}
