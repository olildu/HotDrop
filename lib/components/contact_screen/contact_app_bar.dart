import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:test/utils/common/search_bar.dart';

class ContactAppBar extends StatelessWidget {
  final bool addContactOpened;
  final bool startedPageNavigation;
  final TextEditingController searchController;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onAdd;

  const ContactAppBar({
    required this.addContactOpened,
    required this.startedPageNavigation,
    required this.searchController,
    required this.onBack,
    required this.onForward,
    required this.onAdd,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: const Color(0xFFE7E7E7), width: 1.w)),
      ),
      child: AppBar(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, size: 15.sp), onPressed: onBack),
            IconButton(icon: Icon(Icons.arrow_forward_ios_rounded, size: 15.sp), onPressed: onForward),
            Gap(20.w),
            Text("Contacts", style: TextStyle(fontSize: 20.sp)),
            const Spacer(),
            if (!addContactOpened)
              IconButton(
                icon: Container(
                  padding: EdgeInsets.all(5.sp),
                  decoration: const BoxDecoration(color: Color(0xFFEFEFEF), shape: BoxShape.circle),
                  child: const Icon(Icons.add_rounded, color: Color(0xFF959595)),
                ),
                onPressed: onAdd,
              ),
            Gap(10.w),

            // Search Bar
            SearchInput(
              onChanged: (value) {
                searchController.text = value;
              },
            ),
          ],
        ),
      ),
    );
  }
}
