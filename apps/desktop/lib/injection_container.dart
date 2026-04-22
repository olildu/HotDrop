import 'package:get_it/get_it.dart';
import 'package:test/services/local_ai_service.dart';
import 'blocs/connection_cubit.dart';
import 'blocs/message_cubit.dart';
import 'blocs/contact_cubit.dart';
import 'blocs/contact_ui_cubit.dart';
import 'blocs/hotdrop_cubit.dart';
import 'blocs/popup_cubit.dart';
import 'data/repositories/chat_repository.dart';
import 'data/repositories/contact_repository.dart';
import 'data/repositories/file_repository.dart';
import 'services/ble_interop_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  sl.registerFactory(() => ConnectionCubit());
  sl.registerFactory(() => MessageCubit(sl()));
  sl.registerFactory(() => ContactCubit());
  sl.registerFactory(() => ContactUiCubit());
  sl.registerFactory(() => HotdropCubit(sl()));
  sl.registerLazySingleton(() => PopupCubit());

  sl.registerLazySingleton(() => ChatRepository());
  sl.registerLazySingleton(() => ContactRepository());
  sl.registerLazySingleton(() => FileRepository());
  sl.registerLazySingleton(() => LocalAiService());
  sl.registerLazySingleton(() => BleInteropService());
}
