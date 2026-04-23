import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:test/logic/cubits/hotdrop_cubit.dart';
import 'package:test/presentation/screens/history_screen.dart';
import 'package:test/presentation/theme/app_colors.dart';

class MainScreenHistory extends StatelessWidget {
  const MainScreenHistory({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HotdropCubit, HotdropState>(
      builder: (context, state) {
        final completedTransfers = state.completedTransfers.take(4).toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'HISTORY',
                  style: TextStyle(color: Colors.grey, fontSize: 10.sp, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryScreen()));
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    backgroundColor: AppColors.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                  ),
                  child: Text(
                    'VIEW HISTORY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              ],
            ),
            Gap(20.h),
            if (state.activeTransfer != null)
              _TransferCard(
                icon: Icons.insert_drive_file_rounded,
                filename: state.activeTransfer!.fileName,
                size: state.activeTransfer!.sizeLabel,
                speed: state.activeTransfer!.speedLabel,
                progress: state.activeTransfer!.progress,
                isActive: true,
              ),
            if (state.activeTransfer == null && completedTransfers.isEmpty)
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  'No recent transfers yet.',
                  style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                ),
              ),
            ...completedTransfers.map(
              (transfer) => _TransferCard(
                icon: _iconForFile(transfer.fileName),
                filename: transfer.fileName,
                size: transfer.sizeLabel,
                speed: transfer.speedLabel,
                progress: transfer.progress,
                statusText: transfer.statusLabel,
                isActive: false,
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _iconForFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.grid_on_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_rounded;
      case 'mp4':
        return Icons.videocam_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}

class _TransferCard extends StatelessWidget {
  final IconData icon;
  final String filename;
  final String size;
  final String? speed;
  final double? progress;
  final String? statusText;
  final bool isActive;

  const _TransferCard({
    required this.icon,
    required this.filename,
    required this.size,
    this.speed,
    this.progress,
    this.statusText,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 15.h),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 20.sp),
              ),
              Gap(15.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      filename,
                      style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Gap(5.h),
                    Text(
                      isActive
                          ? (speed != null && speed!.isNotEmpty ? '$size  •  $speed' : '$size  •  Receiving...')
                          : '$size  •  ${statusText ?? 'Completed'}',
                      style: TextStyle(color: Colors.grey, fontSize: 10.sp),
                    ),
                  ],
                ),
              ),
              if (isActive && progress != null)
                Text(
                  '${(progress! * 100).toInt()}%',
                  style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold),
                )
            ],
          ),
          if (isActive && progress != null) ...[
            Gap(20.h),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surfaceContainerHighest,
              color: AppColors.primaryContainer,
              minHeight: 4.h,
              borderRadius: BorderRadius.circular(10.r),
            ),
          ]
        ],
      ),
    );
  }
}
