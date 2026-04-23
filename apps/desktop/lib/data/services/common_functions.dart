import 'dart:io';

import 'package:path_provider/path_provider.dart';

class CommonFunctions {
  Future<Directory> getHotDropDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    Directory hotDropFileLocation = Directory('${directory.path}/NDrop/HotDrop');

    return hotDropFileLocation;
  }

  Future<File> getHotDropHistoryFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final storageDirectory = Directory('${directory.path}/NDrop');

    if (!await storageDirectory.exists()) {
      await storageDirectory.create(recursive: true);
    }

    return File('${storageDirectory.path}/hotdrop_history.json');
  }
}
