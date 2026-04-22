import 'dart:io';

import 'package:path_provider/path_provider.dart';

class CommonFunctions {

  Future<Directory> getHotDropDirectory () async {
    final directory = await getApplicationDocumentsDirectory();
    Directory hotDropFileLocation = Directory('${directory.path}/NDrop/HotDrop');

    return hotDropFileLocation;
  }
  
}