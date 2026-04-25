import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:test/logic/cubits/hotdrop_cubit.dart';
import 'package:test/data/models/file_model.dart';
import 'package:test/presentation/theme/app_colors.dart';

enum HistoryFilter { all, sent, received }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  HistoryFilter _selectedFilter = HistoryFilter.all;
  String _searchQuery = '';

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: BackButton(color: Colors.white),
        ),
      ),
      body: BlocBuilder<HotdropCubit, HotdropState>(
        builder: (context, state) {
          final allFiles = state.completedTransfers;
          final filteredFiles = allFiles.where((file) {
            final matchesTag = switch (_selectedFilter) {
              HistoryFilter.sent => file.isSent,
              HistoryFilter.received => !file.isSent,
              HistoryFilter.all => true,
            };

            final matchesQuery = _searchQuery.isEmpty || file.fileName.toLowerCase().contains(_searchQuery);

            return matchesTag && matchesQuery;
          }).toList();

          final emptyMessage = _searchQuery.isNotEmpty ? "No matching files found for this filter." : "No kinetic movement found in this sector.";

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ACTIVITY LOG",
                  style: TextStyle(
                    color: AppColors.primaryContainer,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                Gap(8.h),
                Text(
                  "History",
                  style: TextStyle(color: Colors.white, fontSize: 40.sp, fontWeight: FontWeight.bold),
                ),
                Gap(12.h),
                Text(
                  "Track every byte of your kinetic data movement.",
                  style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                ),
                Gap(32.h),

                // Tabs
                Row(
                  children: [
                    _tabPill("All Transfers", HistoryFilter.all),
                    Gap(12.w),
                    _tabPill("Sent", HistoryFilter.sent),
                    Gap(12.w),
                    _tabPill("Received", HistoryFilter.received),
                  ],
                ),
                Gap(18.h),

                // Search
                Container(
                  height: 44.h,
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: AppColors.surfaceContainerHigh),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: Colors.grey, size: 18.sp),
                      Gap(8.w),
                      Expanded(
                        child: TextField(
                          onChanged: _onSearchChanged,
                          style: TextStyle(color: Colors.white, fontSize: 13.sp),
                          decoration: InputDecoration(
                            hintText: 'Search files...',
                            hintStyle: TextStyle(color: Colors.grey, fontSize: 12.sp),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            filled: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Gap(32.h),

                // List
                if (filteredFiles.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.h),
                      child: Text(
                        emptyMessage,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredFiles.length,
                    separatorBuilder: (_, __) => Gap(16.h),
                    itemBuilder: (context, index) {
                      return _HistoryCard(transfer: filteredFiles[index]);
                    },
                  ),

                Gap(32.h),

                // Peak Card
                _TransferPeakCard(
                  totalData: context.read<HotdropCubit>().formatBytesForUI(state.totalBytesTransferred),
                ),
                Gap(40.h),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tabPill(String label, HistoryFilter filter) {
    final isSelected = _selectedFilter == filter;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = filter),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryContainer : AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final TransferHistoryItem transfer;

  const _HistoryCard({required this.transfer});

  IconData _getFileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (['jpg', 'png', 'jpeg'].contains(ext)) return Icons.image_rounded;
    if (['mp4', 'mov', 'avi'].contains(ext)) return Icons.movie_creation_rounded;
    if (['pdf', 'doc', 'txt'].contains(ext)) return Icons.description_rounded;
    return Icons.folder_zip_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (transfer.location != null) {
            context.read<HotdropCubit>().openLocalFile(
                  FileModel(name: transfer.fileName, location: transfer.location),
                );
          }
        },
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getFileIcon(transfer.fileName),
                  color: Colors.grey,
                  size: 20.sp,
                ),
              ),
              Gap(16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transfer.fileName,
                      style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Gap(4.h),
                    Row(
                      children: [
                        Icon(
                          transfer.isSent ? Icons.arrow_outward_rounded : Icons.south_west_rounded,
                          size: 12.sp,
                          color: AppColors.primaryContainer,
                        ),
                        Gap(4.w),
                        Text(
                          "${transfer.isSent ? 'SENT' : 'RECEIVED'}  •  ${DateFormat('MMM d, yyyy').format(DateTime.fromMillisecondsSinceEpoch(transfer.lastUpdatedMillis)).toUpperCase()}",
                          style: TextStyle(color: Colors.grey, fontSize: 10.sp, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    transfer.sizeLabel,
                    style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold),
                  ),
                  Gap(4.h),
                  Text(
                    transfer.statusLabel.toUpperCase(),
                    style: TextStyle(
                      color: transfer.isAvailable ? AppColors.primaryContainer : Colors.grey,
                      fontSize: 10.sp,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransferPeakCard extends StatelessWidget {
  final Map<String, String> totalData;

  const _TransferPeakCard({required this.totalData});

  @override
  Widget build(BuildContext context) {
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
            style: TextStyle(color: Colors.white, fontSize: 24.sp, fontWeight: FontWeight.bold),
          ),
          Gap(12.h),
          Text(
            "You shared ${totalData['value']} ${totalData['unit']} of data over the last 7 days. Your kinetic flow is increasing.",
            style: TextStyle(color: Colors.grey, fontSize: 14.sp, height: 1.5),
          ),
        ],
      ),
    );
  }
}
