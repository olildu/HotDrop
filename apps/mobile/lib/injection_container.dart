import 'package:get_it/get_it.dart';
import 'package:test_mobile/blocs/hotdrop_cubit.dart';
import 'package:test_mobile/blocs/message_cubit.dart';
import 'package:test_mobile/blocs/session/session_cubit.dart';
import 'package:test_mobile/data/repositories/chat_repository.dart';
import 'package:test_mobile/data/repositories/connection_repository.dart';
import 'package:test_mobile/data/repositories/contact_repository.dart';
import 'package:test_mobile/data/repositories/file_repository.dart';
import 'package:test_mobile/services/file_storage_service.dart';
import 'package:test_mobile/services/message_storage_service.dart';
import 'package:test_mobile/services/file_hosting_services.dart';

final sl = GetIt.instance;

Future<void> init() async {
  sl.registerLazySingleton(() => FileStorageService());
  sl.registerLazySingleton(() => MessageStorageService());
  sl.registerLazySingleton(() => FileHostingService());

  sl.registerLazySingleton(() => ChatRepository());
  sl.registerLazySingleton(() => ConnectionRepository());
  sl.registerLazySingleton(() => FileRepository());
  sl.registerLazySingleton(() => ContactRepository());
  sl.registerLazySingleton(() => SessionCubit(sl(), sl()));
  sl.registerLazySingleton(() => HotDropCubit(sl<FileHostingService>()));
  sl.registerLazySingleton(() => MessageCubit(sl<ChatRepository>()));
}
