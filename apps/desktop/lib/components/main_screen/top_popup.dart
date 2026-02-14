import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:test/providers/popup_provider.dart';

class TopPopup extends StatefulWidget {
  const TopPopup({super.key});

  @override
  State<TopPopup> createState() => _TopPopupState();
}

class _TopPopupState extends State<TopPopup> {
  @override
  Widget build(BuildContext context) {
    final popupProvider = context.watch<PopupProvider>();

    return Positioned(
      top: 20.h,
      right: 20.w,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: popupProvider.showPopup ? 1 : 0,
        child: Material(
          elevation: popupProvider.showPopup ? 6 : 0,
          borderRadius: BorderRadius.circular(12.r),
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            constraints: BoxConstraints(
              maxWidth: 300.w,
              minWidth: 200.w,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      popupProvider.icon,
                      color: const Color.fromARGB(255, 99, 99, 99),
                      size: 24.sp,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        popupProvider.message,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                if (popupProvider.progress >= 0)
                  Padding(
                    padding: EdgeInsets.only(top: 8.h),
                    child: SizedBox(
                      width: 200.w,
                      child: LinearProgressIndicator( 
                        value: popupProvider.progress,
                        backgroundColor: Colors.grey[300],
                        color: const Color.fromARGB(255, 73, 69, 79),
                        minHeight: 6.h,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

  }
}
