import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:test/logic/cubits/hotdrop_cubit.dart';
import 'package:test/presentation/screens/main_screen_view_model.dart';
import 'package:test/presentation/theme/app_colors.dart';

class MainScreenTransferHub extends StatefulWidget {
  final MainScreenActions actions;

  const MainScreenTransferHub({super.key, required this.actions});

  @override
  State<MainScreenTransferHub> createState() => _MainScreenTransferHubState();
}

class _MainScreenTransferHubState extends State<MainScreenTransferHub> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(30.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(30.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transfer Hub',
                        style: TextStyle(color: Colors.white, fontSize: 24.sp, fontWeight: FontWeight.bold),
                      ),
                      Gap(5.h),
                      Text(
                        'Secure P2P Encrypted Channels',
                        style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: widget.actions.disconnect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceContainerHighest,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 15.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                      elevation: 0,
                    ),
                    child: Text('DISCONNECT', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ],
              ),
              Gap(30.h),
              DropTarget(
                onDragEntered: (_) {
                  if (!mounted) return;
                  setState(() => _isDragging = true);
                },
                onDragExited: (_) {
                  if (!mounted) return;
                  setState(() => _isDragging = false);
                },
                onDragDone: (details) async {
                  if (!mounted) return;
                  setState(() => _isDragging = false);

                  final droppedPaths =
                      details.files.whereType<DropItemFile>().map((item) => item.path).where((path) => path.isNotEmpty).toList(growable: false);

                  if (droppedPaths.isEmpty) {
                    return;
                  }

                  await context.read<HotdropCubit>().sendDroppedFiles(droppedPaths);
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => context.read<HotdropCubit>().pickAndSendFile(),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 60.h),
                      decoration: BoxDecoration(
                        color: _isDragging
                            ? AppColors.primaryContainer.withValues(alpha: 0.2)
                            : AppColors.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: _isDragging ? AppColors.primaryContainer : AppColors.surfaceContainerHighest,
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(15.w),
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 30.sp),
                          ),
                          Gap(20.h),
                          Text(
                            _isDragging ? 'Release to Send Files' : 'Drop Files to Beam',
                            style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
                          ),
                          Gap(10.h),
                          Text(
                            'Instantly stream encrypted data fragments\nacross the peer network.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 12.sp, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
