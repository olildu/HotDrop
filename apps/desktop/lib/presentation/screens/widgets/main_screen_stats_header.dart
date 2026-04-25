import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:test/logic/cubits/hotdrop_cubit.dart';
import 'package:test/presentation/screens/main_screen_view_model.dart';
import 'package:test/presentation/theme/app_colors.dart';

class MainScreenStatsHeader extends StatelessWidget {
  final MainScreenViewModel viewModel;

  const MainScreenStatsHeader({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SYSTEM TRANSMISSION MATRIX',
          style: TextStyle(color: Colors.grey, fontSize: 10.sp, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        Gap(10.h),
        BlocBuilder<HotdropCubit, HotdropState>(
          builder: (context, state) {
            final formattedBytes = context.read<HotdropCubit>().formatBytesForUI(state.totalBytesTransferred);
            final formattedSpeed = context.read<HotdropCubit>().formatAverageSpeedForUI();

            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      formattedBytes['value']!,
                      style: TextStyle(color: Colors.white, fontSize: 90.sp, fontWeight: FontWeight.bold, height: 1),
                    ),
                    Gap(10.w),
                    Text(
                      formattedBytes['unit']!,
                      style: TextStyle(color: Colors.grey, fontSize: 30.sp, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Spacer(),
                _StatItem(label: 'AVERAGE SPEED', value: formattedSpeed['value']!, unit: formattedSpeed['unit']!),
                Gap(40.w),
                _StatItem(label: "FILES SENT", value: state.transferCount.toString(), unit: "FILES"),
              ],
            );
          },
        ),
        Gap(5.h),
        Row(
          children: [
            Text(
              'Total Data Beamed',
              style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.w600),
            ),
            Gap(15.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8.w,
                    height: 8.w,
                    decoration: BoxDecoration(
                      color: viewModel.hasConnection ? AppColors.primaryContainer : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Gap(8.w),
                  Text(
                    viewModel.hasConnection ? 'KINETIC PULSE ACTIVE' : 'SYSTEM STANDBY',
                    style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _StatItem({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey, fontSize: 9.sp, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        Gap(5.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(color: Colors.white, fontSize: 28.sp, fontWeight: FontWeight.bold),
            ),
            if (unit.isNotEmpty) Gap(5.w),
            if (unit.isNotEmpty)
              Text(
                unit,
                style: TextStyle(color: Colors.grey, fontSize: 12.sp, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ],
    );
  }
}
