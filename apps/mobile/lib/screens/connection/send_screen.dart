import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:test_mobile/blocs/connection/connection_cubit.dart';
import 'package:test_mobile/core/theme/app_colors.dart';
import 'widgets/radar_state_view.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ConnectionCubit>().startScanning();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectionCubit, ConnectionCubitState>(
      listener: (context, state) {
        if (state.status == ConnectionStatus.connected) Navigator.pop(context);
        if (state.status == ConnectionStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.errorMessage ?? "Error")));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: _buildAppBar(context),
        body: const RadarStateView(isReceiving: false),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: const BackButton(color: AppColors.onSurface),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bubble_chart, color: AppColors.primary, size: 28.sp),
          Gap(8.w),
          Text("HotDrop", style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 22.sp)),
        ],
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: 20.w),
          child: Icon(Icons.account_circle_outlined, color: AppColors.onSurface, size: 28.sp),
        ),
      ],
    );
  }
}