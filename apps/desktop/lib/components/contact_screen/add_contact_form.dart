import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';

class AddContactForm extends StatelessWidget {
  final XFile? pickedFile;
  final TextEditingController nameController;
  final TextEditingController numberController;
  final bool canCreateContact;
  final VoidCallback onPickImage;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onNumberChanged;
  final VoidCallback onCreateContact;

  const AddContactForm({
    required this.pickedFile,
    required this.nameController,
    required this.numberController,
    required this.canCreateContact,
    required this.onPickImage,
    required this.onNameChanged,
    required this.onNumberChanged,
    required this.onCreateContact,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.all(20.sp),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: onPickImage,
              child: CircleAvatar(
                radius: 60.r,
                backgroundColor: const Color(0xFFEFEFEF),
                backgroundImage: pickedFile != null ? FileImage(File(pickedFile!.path)) : null,
                child: pickedFile == null ? Icon(Icons.add_rounded, size: 40.sp, color: Colors.grey) : null,
              ),
            ),
            Gap(30.h),
            InputField(controller: nameController, hint: 'Contact Name', onChanged: onNameChanged),
            Gap(10.h),
            InputField(controller: numberController, hint: 'Contact Number', onChanged: onNumberChanged),
            Gap(20.h),
            ElevatedButton(
              onPressed: canCreateContact ? onCreateContact : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                disabledBackgroundColor: Colors.grey[300],
                minimumSize: Size(200.w, 40.h),
              ),
              child: Text(
                'Create Contact',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: canCreateContact ? Colors.white : Colors.black54,
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
  final ValueChanged<String>? onChanged;

  const InputField({required this.controller, required this.hint, this.onChanged, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300.w,
      height: 40.h,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
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
