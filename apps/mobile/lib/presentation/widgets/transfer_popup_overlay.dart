import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:test_mobile/logic/cubits/popup_cubit.dart';
import 'package:test_mobile/presentation/theme/app_colors.dart';

class TransferPopupOverlay extends StatelessWidget {
  const TransferPopupOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BlocBuilder<PopupCubit, PopupState>(
        builder: (context, state) {
          final isVisible = state.showPopup;

          return IgnorePointer(
            ignoring: !isVisible,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              offset: isVisible ? Offset.zero : const Offset(0, -0.12),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: isVisible ? 1 : 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 520.w),
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(color: AppColors.outlineVariant),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.28),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
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
                                    padding: EdgeInsets.all(10.w),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.14),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(state.icon, color: AppColors.primary, size: 22.sp),
                                  ),
                                  Gap(12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          state.message,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                color: AppColors.onSurface,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        Gap(2.h),
                                        Text(
                                          state.progress >= 0 && state.progress < 1
                                              ? 'Incoming transfer in progress'
                                              : state.progress >= 1
                                                  ? 'Transfer complete'
                                                  : 'Waiting for transfer data',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: AppColors.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (state.progress >= 0) ...[
                                Gap(14.h),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999.r),
                                  child: LinearProgressIndicator(
                                    value: state.progress.clamp(0.0, 1.0),
                                    minHeight: 6.h,
                                    backgroundColor: AppColors.surfaceContainerLowest,
                                    color: state.progress >= 1 ? AppColors.successAccent : AppColors.primaryContainer,
                                  ),
                                ),
                                Gap(8.h),
                                Text(
                                  '${(state.progress.clamp(0.0, 1.0) * 100).toInt()}%',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: AppColors.onSurfaceVariant,
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
              ),
            ),
          );
        },
      ),
    );
  }
}
