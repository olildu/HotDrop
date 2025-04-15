import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

class ContactList extends StatelessWidget {
  final List<dynamic> filteredList;

  const ContactList({required this.filteredList, super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text("Name", style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                Expanded(child: Text("Phone number", style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
              ],
            ),
            const Divider(),
            Gap(20.h),
            Expanded(
              child: ListView.separated(
                itemCount: filteredList.length,
                separatorBuilder: (_, __) => Gap(10.h),
                itemBuilder: (context, index) {
                  final name = filteredList[index]["name"] ?? "";
                  final phone = filteredList[index]["normalizedNumber"] ?? "";
                  if (name.trim().isEmpty) return const SizedBox();
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(vertical: 5.h, horizontal: 10.w),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.r)),
                    leading: CircleAvatar(
                      radius: 17.r,
                      backgroundColor: Colors.blue,
                      child: Text(name[0], style: GoogleFonts.poppins(color: Colors.white)),
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w500))),
                        Expanded(child: Text(phone, style: GoogleFonts.poppins(fontWeight: FontWeight.w500))),
                      ],
                    ),
                    trailing: PopupMenuButton<int>(
                      icon: const Icon(Icons.more_vert),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 0, child: Text('✏️  Edit')),
                        PopupMenuItem(value: 1, child: Text('🗑️  Delete')),
                        PopupMenuItem(value: 2, child: Text('📞  Call')),
                      ],
                    ),
                    onTap: () {},
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
