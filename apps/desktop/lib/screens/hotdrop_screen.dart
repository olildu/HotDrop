import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import '../blocs/hotdrop_cubit.dart';
import '../data/models/file_model.dart';
import '../utils/common/search_bar.dart';

class HotdropScreen extends StatefulWidget {
  const HotdropScreen({super.key});

  @override
  State<HotdropScreen> createState() => _HotdropScreenState();
}

class _HotdropScreenState extends State<HotdropScreen> {
  String searchQuery = '';

  IconData _getFileIcon(String fileName) {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: const Color(0xFFE7E7E7), width: 1.w)),
          ),
          child: AppBar(
            backgroundColor: Colors.white,
            actions: [
              IconButton(icon: const Icon(Icons.upload_file), onPressed: () => context.read<HotdropCubit>().pickAndSendFile()),
            ],
            title: Row(
              children: [
                IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, size: 15.sp), onPressed: () {}),
                IconButton(icon: Icon(Icons.arrow_forward_ios_rounded, size: 15.sp), onPressed: () {}),
                Gap(20.w),
                Text("HotDrop", style: TextStyle(fontSize: 20.sp)),
                const Spacer(),
                SearchInput(onChanged: (value) => setState(() => searchQuery = value)),
              ],
            ),
          ),
        ),
        Expanded(
          child: BlocBuilder<HotdropCubit, List<FileModel>>(
            builder: (context, files) {
              final filteredFiles = files.where((file) {
                return file.name.toLowerCase().contains(searchQuery.toLowerCase());
              }).toList();

              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 1,
                ),
                itemCount: filteredFiles.length,
                padding: EdgeInsets.all(10.sp),
                itemBuilder: (context, index) {
                  final file = filteredFiles[index];
                  return GestureDetector(
                    onTap: () => context.read<HotdropCubit>().openLocalFile(file),
                    child: Column(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[400]!),
                            ),
                            child: Center(child: Icon(_getFileIcon(file.name), size: 40.sp)),
                          ),
                        ),
                        Gap(10.h),
                        Expanded(child: Text(file.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
