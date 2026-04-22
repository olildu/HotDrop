import 'package:get_it/get_it.dart';
import 'package:test/data/services/local_ai_service.dart';
import 'cubits/app_lifecycle_cubit.dart';
import 'cubits/connection_cubit.dart';
import 'cubits/message_cubit.dart';
import 'cubits/contact_cubit.dart';
import 'cubits/contact_ui_cubit.dart';
import 'cubits/hotdrop_cubit.dart';
import 'cubits/popup_cubit.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/contact_repository.dart';
import '../data/repositories/file_repository.dart';
import '../data/services/ble_interop_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  sl.registerFactory(() => AppLifecycleCubit(sl()));
  sl.registerFactory(() => ConnectionCubit());
  sl.registerLazySingleton(() => MessageCubit(sl()));
  sl.registerLazySingleton(() => ContactCubit());
  sl.registerFactory(() => ContactUiCubit());
  sl.registerLazySingleton(() => HotdropCubit(sl()));
  sl.registerLazySingleton(() => PopupCubit());

  sl.registerLazySingleton(() => ChatRepository());
  sl.registerLazySingleton(() => ContactRepository());
  sl.registerLazySingleton(() => FileRepository());
  sl.registerLazySingleton(() => LocalAiService());
  sl.registerLazySingleton(() => BleInteropService());
}



