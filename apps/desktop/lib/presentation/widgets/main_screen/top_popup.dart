import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test/logic/cubits/popup_cubit.dart';
import 'package:test/presentation/theme/app_colors.dart';

class TopPopup extends StatefulWidget {
  const TopPopup({super.key});

  @override
  State<TopPopup> createState() => _TopPopupState();
}

class _TopPopupState extends State<TopPopup> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PopupCubit, PopupState>(
      builder: (context, state) {
        final hasProgress = state.progress >= 0;
        final progressValue = hasProgress ? state.progress.clamp(0.0, 1.0) : 0.0;
        final screenWidth = MediaQuery.of(context).size.width;
        final popupWidth = (screenWidth * 0.34).clamp(260.0, 420.0);

        return Positioned(
          top: 16.h,
          right: 16.w,
          child: IgnorePointer(
            ignoring: !state.showPopup,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              offset: state.showPopup ? Offset.zero : const Offset(0.15, -0.15),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: state.showPopup ? 1 : 0,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: popupWidth,
                    minWidth: 240.w,
                  ),
                  child: Container(
                    constraints: BoxConstraints(minHeight: 82.h),
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.r),
                      gradient: LinearGradient(
                        colors: [
                          hasProgress ? const Color(0xF61A2536) : const Color(0xF622252A),
                          const Color(0xEE171A1F),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: hasProgress ? AppColors.primaryContainer.withValues(alpha: 0.36) : AppColors.outlineVariant,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 26,
                          spreadRadius: -10,
                          offset: const Offset(0, 14),
                        ),
                        if (hasProgress)
                          BoxShadow(
                            color: AppColors.primaryContainer.withValues(alpha: 0.22),
                            blurRadius: 18,
                            spreadRadius: -8,
                            offset: const Offset(0, 6),
                          ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: hasProgress
                                    ? AppColors.primaryContainer.withValues(alpha: 0.2)
                                    : AppColors.surfaceContainerHighest.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(999.r),
                                border: Border.all(
                                  color: hasProgress ? AppColors.primaryContainer.withValues(alpha: 0.5) : AppColors.outlineVariant,
                                ),
                              ),
                              child: Text(
                                hasProgress ? 'FILE TRANSFER' : 'NEW MESSAGE',
                                style: TextStyle(
                                  color: hasProgress ? AppColors.primary : AppColors.onSurfaceVariant,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 9.h),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38.w,
                              height: 38.w,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.r),
                                gradient: hasProgress
                                    ? const LinearGradient(
                                        colors: [Color(0xFF84B1FF), Color(0xFF4B8EFF)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : const LinearGradient(
                                        colors: [Color(0xFFA4ACB5), Color(0xFF7E8791)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                              ),
                              child: Icon(state.icon, size: 19.sp, color: Colors.white),
                            ),
                            SizedBox(width: 11.w),
                            Flexible(
                              child: Padding(
                                padding: EdgeInsets.only(top: 2.h),
                                child: Text(
                                  state.message,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.onSurface,
                                    fontSize: 13.5.sp,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                    letterSpacing: 0.1,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (hasProgress) ...[
                          SizedBox(height: 11.h),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999.r),
                            child: Container(
                              height: 8.h,
                              color: AppColors.surfaceContainerHighest.withValues(alpha: 0.55),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                  width: (popupWidth - (28.w)) * progressValue,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF7FAEFF), AppColors.primaryContainer],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${(progressValue * 100).toStringAsFixed(0)}% COMPLETE',
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.7,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
