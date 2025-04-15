import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:test/providers/hotdrop_provider.dart';
import 'package:test/utils/common/search_bar.dart';

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
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.attach_file_rounded;
      case 'mp3':
      case 'wav':
      case 'ogg':
        return Icons.music_note_rounded;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return Icons.videocam_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return Icons.image_rounded;
      case 'txt':
        return Icons.note_alt_rounded;
      case 'apk':
        return Icons.android_rounded;
      case 'exe':
        return Icons.computer_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final HotdropProvider hotdropProvider = Provider.of<HotdropProvider>(context, listen: true);

    final filteredFiles = hotdropProvider.files.where((file) {
      final name = file["name"].toString().toLowerCase();
      return name.contains(searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: const Color.fromARGB(255, 231, 231, 231),
                width: 1.w,
              ),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.white,
            title: SizedBox(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    onPressed: () {
                      // Provider.of<PopupProvider>(context, listen: false).showTest();
                    },
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 15.sp),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    onPressed: () {},
                    icon: Icon(Icons.arrow_forward_ios_rounded, size: 15.sp),
                  ),
                  Gap(20.w),
                  Text(
                    "HotDrop",
                    style: TextStyle(fontSize: 20.sp),
                  ),
                  const Spacer(),

                  // Search Bar
                  SearchInput(
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  )
                ],
              ),
            ),
          ),
        ),

        // Files Grid
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1,
            ),
            itemCount: filteredFiles.length,
            padding: EdgeInsets.all(10.sp),
            itemBuilder: (context, index) {
              final fileName = filteredFiles[index]["name"];
              final filePath = filteredFiles[index]["location"];
              return GestureDetector(
                onTap: () async {
                  await OpenFilex.open(filePath);
                },
                onSecondaryTapDown: (TapDownDetails details) {
                  showMenu(
                    context: context,
                    color: Colors.white,
                    position: RelativeRect.fromLTRB(
                      details.globalPosition.dx,
                      details.globalPosition.dy,
                      details.globalPosition.dx,
                      details.globalPosition.dy,
                    ),
                    items: [
                      PopupMenuItem(
                        child: Text('Open file location'),
                        onTap: () {
                          final directoryPath = File(filePath).parent.path;
                          OpenFilex.open(directoryPath);
                        },
                      ),
                      PopupMenuItem(
                        child: Text('Delete'),
                        onTap: () {
                          File(filePath).deleteSync();
                        },
                      ),
                    ],
                  );
                },
                child: Column(
                  children: [
                    // File Icon
                    Expanded(
                      flex: 3,
                      child: Container(
                        width: 100.w,
                        height: 100.h,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[400]!),
                        ),
                        child: Center(
                          child: Icon(
                            _getFileIcon(fileName),
                            size: 40.sp,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),

                    Gap(10.h),

                    // File name
                    Expanded(
                      child: Text(
                        fileName,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.black87,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
