import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SearchInput extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const SearchInput({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        width: 200.w,
        height: 40.h,
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        child: TextField(
          onChanged: onChanged,
          cursorColor: Colors.grey,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.black,
            fontWeight: FontWeight.w300,
          ),
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFFA1A1A1),
            ),
            hintText: "Search",
            hintStyle: TextStyle(
              fontSize: 12.sp,
              color: const Color(0xFFA1A1A1),
              fontWeight: FontWeight.w300,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5.r),
              borderSide: const BorderSide(color: Color(0xFFECECEC)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5.r),
              borderSide: const BorderSide(color: Color(0xFFECECEC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5.r),
              borderSide: const BorderSide(color: Color(0xFFECECEC)),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 10.h),
          ),
        ),
      ),
    );
  }
}
