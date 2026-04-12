import 'package:get_it/get_it.dart';
import 'blocs/message_cubit.dart';
import 'blocs/contact_cubit.dart';
import 'blocs/hotdrop_cubit.dart';
import 'blocs/popup_cubit.dart';
import 'data/repositories/chat_repository.dart';
import 'data/repositories/contact_repository.dart';
import 'data/repositories/file_repository.dart';
import 'services/ble_interop_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  //! Blocs / Cubits
  sl.registerFactory(() => MessageCubit(sl()));
  sl.registerFactory(() => ContactCubit());
  sl.registerFactory(() => HotdropCubit(sl()));
  sl.registerLazySingleton(() => PopupCubit()); // LazySingleton for global access

  //! Repositories
  sl.registerLazySingleton(() => ChatRepository());
  sl.registerLazySingleton(() => ContactRepository());
  sl.registerLazySingleton(() => FileRepository());

  //! Services
  sl.registerLazySingleton(() => BleInteropService());
}
