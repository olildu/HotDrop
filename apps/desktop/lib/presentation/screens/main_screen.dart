import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:test/logic/cubits/connection_cubit.dart';
import 'package:test/logic/constants/globals.dart' as globals;
import 'package:test/presentation/screens/main_screen_view_model.dart';
import 'package:test/presentation/screens/widgets/main_screen_connection_selection.dart';
import 'package:test/presentation/screens/widgets/main_screen_history.dart';
import 'package:test/presentation/screens/widgets/main_screen_stats_header.dart';
import 'package:test/presentation/screens/widgets/main_screen_top_bar.dart';
import 'package:test/presentation/screens/widgets/main_screen_transfer_hub.dart';
import 'package:test/presentation/theme/app_colors.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String _fileSearchQuery = '';

  void _handleFileSearchChanged(String query) {
    if (_fileSearchQuery == query) {
      return;
    }

    setState(() {
      _fileSearchQuery = query;
    });
  }

  @override
  void initState() {
    super.initState();
    globals.currentScreen = globals.AppScreen.main;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectionCubit, ConnectionState>(
      builder: (context, connectionState) {
        final viewModel = MainScreenViewModel.fromState(connectionState);
        final actions = MainScreenActions(context.read<ConnectionCubit>());

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: Column(
              children: [
                MainScreenTopBar(
                  viewModel: viewModel,
                  onSearchChanged: _handleFileSearchChanged,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 20.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MainScreenStatsHeader(viewModel: viewModel),
                        Gap(40.h),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 13,
                              child: viewModel.showTransferHub
                                  ? MainScreenTransferHub(actions: actions)
                                  : MainScreenConnectionSelection(viewModel: viewModel, actions: actions),
                            ),
                            Gap(40.w),
                            Expanded(
                              flex: 7,
                              child: MainScreenHistory(searchQuery: _fileSearchQuery),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
