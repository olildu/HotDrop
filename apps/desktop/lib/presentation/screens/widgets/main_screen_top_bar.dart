import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:test/presentation/screens/main_screen_view_model.dart';
import 'package:test/presentation/screens/messaging_screen.dart';
import 'package:test/presentation/theme/app_colors.dart';

class MainScreenTopBar extends StatelessWidget {
  final MainScreenViewModel viewModel;
  final ValueChanged<String> onSearchChanged;

  const MainScreenTopBar({super.key, required this.viewModel, required this.onSearchChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70.h,
      padding: EdgeInsets.symmetric(horizontal: 40.w),
      child: Row(
        children: [
          Text(
            'KINETIC VOID',
            style: TextStyle(color: Colors.grey, fontSize: 12.sp, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
          Gap(15.w),
          Container(width: 20.w, height: 2.h, color: Colors.grey.shade800),
          Gap(15.w),
          Text(
            viewModel.statusText,
            style: TextStyle(
              color: viewModel.hasConnection ? Colors.white : Colors.grey,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Container(
            width: 250.w,
            height: 40.h,
            padding: EdgeInsets.symmetric(horizontal: 15.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: AppColors.surfaceContainerHigh),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.grey, size: 18.sp),
                Gap(10.w),
                Expanded(
                  child: TextField(
                    onChanged: onSearchChanged,
                    style: TextStyle(color: Colors.white, fontSize: 12.sp),
                    decoration: InputDecoration(
                      hintText: 'Search files...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 12.sp),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      filled: false, // Removes the unwanted grey box
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Gap(20.w),
          IconButton(
            icon: Icon(Icons.chat_bubble_rounded, color: viewModel.hasConnection ? AppColors.primaryContainer : Colors.grey, size: 22.sp),
            onPressed: () {
              viewModel.hasConnection
                  ? Navigator.push(context, MaterialPageRoute(builder: (_) => MessagingScreen()))
                  : ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('No active connection. Please establish a connection to access messaging features.')),
                    );
            },
          ),
        ],
      ),
    );
  }
}
