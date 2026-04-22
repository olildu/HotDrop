import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:test_mobile/logic/cubits/file_detail_cubit.dart';
import 'package:test_mobile/presentation/theme/app_colors.dart';
import 'package:test_mobile/data/models/file_model.dart';

class SharedFilesScreen extends StatefulWidget {
  const SharedFilesScreen({super.key});

  @override
  State<SharedFilesScreen> createState() => _SharedFilesScreenState();
}

class _SharedFilesScreenState extends State<SharedFilesScreen> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: const BackButton(color: AppColors.onSurface),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 20.w),
            child: Icon(Icons.account_circle_outlined, color: colorScheme.onSurface, size: 28.sp),
          ),
        ],
      ),
      body: BlocBuilder<FileDetailCubit, FileDetailState>(
        builder: (context, state) {
          final cubit = context.read<FileDetailCubit>();
          final filteredFiles = cubit.getFilteredFiles();

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ACTIVITY LOG",
                  style: textTheme.labelSmall?.copyWith(letterSpacing: 1.5, color: colorScheme.primary),
                ),
                Gap(8.h),
                Text(
                  "History",
                  style: textTheme.displayLarge?.copyWith(fontSize: 56.sp),
                ),
                Gap(12.h),
                Text(
                  "Track every byte of your kinetic data movement.",
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                Gap(32.h),

                // Pill Tabs
                _buildTabs(context, state.selectedFilter),
                Gap(32.h),

                // History List
                if (filteredFiles.isEmpty)
                  _buildEmptyState(textTheme, colorScheme)
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredFiles.length,
                    separatorBuilder: (context, index) => Gap(16.h),
                    itemBuilder: (context, index) {
                      return _HistoryCard(file: filteredFiles[index], cubit: cubit);
                    },
                  ),

                Gap(32.h),
                // Transfer Peak Card

                _TransferPeakCard(stats: cubit.getStats()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabs(BuildContext context, FileHistoryFilter selectedFilter) {
    return Row(
      children: [
        _tabPill(context, "All Transfers", FileHistoryFilter.all, selectedFilter),
        Gap(12.w),
        _tabPill(context, "Sent", FileHistoryFilter.sent, selectedFilter),
        Gap(12.w),
        _tabPill(context, "Received", FileHistoryFilter.received, selectedFilter),
      ],
    );
  }

  Widget _tabPill(BuildContext context, String label, FileHistoryFilter filter, FileHistoryFilter selectedFilter) {
    final isSelected = selectedFilter == filter;
    return GestureDetector(
      onTap: () => context.read<FileDetailCubit>().setHistoryFilter(filter),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.surface : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(TextTheme textTheme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h),
        child: Text(
          "No kinetic movement found in this sector.",
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final FileModel file;
  final FileDetailCubit cubit;

  const _HistoryCard({required this.file, required this.cubit});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => cubit.openFile(file),
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getFileIcon(file.name),
                color: colorScheme.onSurfaceVariant,
                size: 24.sp,
              ),
            ),
            Gap(16.w),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: textTheme.titleMedium?.copyWith(fontSize: 16.sp, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Gap(4.h),
                  Row(
                    children: [
                      Icon(
                        file.isSent ? Icons.arrow_outward_rounded : Icons.south_west_rounded,
                        size: 12.sp,
                        color: colorScheme.primary,
                      ),
                      Gap(4.w),
                      Text(
                        "${file.isSent ? 'SENT' : 'RECEIVED'}  •  ${DateFormat('MMM d, yyyy').format(file.timestamp).toUpperCase()}",
                        style: textTheme.labelSmall?.copyWith(fontSize: 10.sp, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Size & Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  cubit.formatDataSize(file.size.toDouble()),
                  style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Gap(4.h),
                Text(
                  "SUCCESS",
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary.withOpacity(0.7),
                    fontSize: 10.sp,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (['jpg', 'png', 'dng', 'jpeg'].contains(ext)) return Icons.image_rounded;
    if (['mp4', 'mov', 'avi'].contains(ext)) return Icons.movie_creation_rounded;
    if (['pdf', 'doc', 'txt'].contains(ext)) return Icons.description_rounded;
    return Icons.folder_zip_rounded;
  }
}

class _TransferPeakCard extends StatelessWidget {
  final Map<String, String> stats;
  const _TransferPeakCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(32.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Transfer Peak",
            style: textTheme.headlineMedium?.copyWith(fontSize: 24.sp),
          ),
          Gap(12.h),
          Text(
            "You shared ${stats['total_data']} of data over the last 7 days. Your kinetic flow is increasing.",
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
