import 'csv_download_stub.dart'
    if (dart.library.html) 'csv_download_web.dart';

Future<String> downloadCsvString(String content, String fileName) {
  return saveCsvString(content, fileName);
}
