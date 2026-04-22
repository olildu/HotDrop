import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../blocs/connection_cubit.dart';

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: BlocBuilder<ConnectionCubit, ConnectionState>(
          builder: (context, state) {
            if (state.selectedRole == ConnectionRole.none) {
              return _buildSelectionUI(context);
            }

            return _buildActiveUI(context, state);
          },
        ),
      ),
    );
  }

  Widget _buildSelectionUI(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('HotDrop Windows', style: TextStyle(fontSize: 30.sp, fontWeight: FontWeight.bold)),
        Gap(50.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _choiceCard('Be the Host', Icons.wifi_tethering, () => context.read<ConnectionCubit>().startHosting()),
            Gap(30.w),
            _choiceCard('Join a Peer', Icons.search, () => context.read<ConnectionCubit>().startJoining()),
          ],
        ),
      ],
    );
  }

  Widget _choiceCard(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(30.sp),
        decoration: BoxDecoration(border: Border.all(color: Colors.blue), borderRadius: BorderRadius.circular(15.r)),
        child: Column(children: [Icon(icon, size: 50.sp, color: Colors.blue), Gap(10.h), Text(title)]),
      ),
    );
  }

  Widget _buildActiveUI(BuildContext context, ConnectionState state) {
    if (state.isProcessing) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [const CircularProgressIndicator(), Gap(20.h), Text(state.loadingStatus)],
      );
    }

    if (state.isAdminError) {
      return _buildAdminErrorUI();
    }

    if (state.selectedRole == ConnectionRole.host) {
      return _buildQRUI(state);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(state.loadingStatus, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
        if (state.loadingStatus == 'Scanning for nearby peers...')
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: LinearProgressIndicator(),
          ),
        Gap(20.h),
        SizedBox(
          height: 350.h,
          width: 500.w,
          child: state.availableHosts.isEmpty && state.loadingStatus != 'Scanning for nearby peers...'
              ? Center(child: Text('No devices found.', style: TextStyle(color: Colors.grey[600])))
              : ListView.builder(
                  itemCount: state.availableHosts.length,
                  itemBuilder: (context, index) {
                    final host = state.availableHosts[index];
                    return ListTile(
                      leading: const Icon(Icons.computer, color: Colors.blue),
                      title: Text(host['name']?.toString() ?? 'Unknown device'),
                      subtitle: Text(host['address']?.toString() ?? ''),
                      onTap: () => context.read<ConnectionCubit>().connectToPeer(
                            host['address'].toString(),
                            host['name'].toString(),
                          ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                    );
                  },
                ),
        ),
        TextButton(onPressed: () => context.read<ConnectionCubit>().startJoining(), child: const Text('Rescan')),
        TextButton(onPressed: () => context.read<ConnectionCubit>().reset(), child: const Text('Go Back')),
      ],
    );
  }

  Widget _buildAdminErrorUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.admin_panel_settings_rounded, size: 80.sp, color: Colors.redAccent),
        Gap(20.h),
        Text(
          'Administrator Privileges Required',
          style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
        ),
        Gap(10.h),
        SizedBox(
          width: 400.w,
          child: Text(
            "To automatically enable the Windows Mobile Hotspot, this app needs to be run as an Administrator. Please close the app, right-click the icon, and select 'Run as Administrator'.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Widget _buildQRUI(ConnectionState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        state.qrData == null
            ? Column(
                children: [
                  const CircularProgressIndicator(),
                  Gap(20.h),
                  Text(state.loadingStatus, style: TextStyle(fontSize: 16.sp, color: Colors.grey[600])),
                ],
              )
            : QrImageView(
                data: state.qrData!,
                version: QrVersions.auto,
                size: 320.sp,
                gapless: false,
              ),
        Gap(50.h),
        if (state.qrData != null)
          Column(
            children: [
              Text('Connect to get started', style: TextStyle(fontSize: 23.sp)),
              Gap(10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bluetooth_audio, size: 20.sp, color: Colors.blue),
                  Gap(5.w),
                  Text('Broadcasting via BLE', style: TextStyle(color: Colors.blue, fontSize: 14.sp)),
                ],
              ),
            ],
          ),
        if (state.currentServerIp != null)
          Padding(
            padding: EdgeInsets.only(top: 10.h),
            child: Text('IP: ${state.currentServerIp}', style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
          ),
      ],
    );
  }
}
