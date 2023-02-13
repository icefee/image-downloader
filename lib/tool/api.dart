import 'dart:io';
import 'package:http/http.dart';

Future<List<String>> getImages(String url) async {
  Response response = await get(Uri.parse(url));
  Iterable<RegExpMatch> matches = RegExp(r'https?://[a-zA-Z\d(-|_|/)]+?\.jpe?g', caseSensitive: false).allMatches(response.body);
  return matches.map((m) => m.group(0)!).toSet().toList();
}

Future<void> downloadImage(String url, String path, { Function(double)? onProcess }) async {
  // RegExpMatch? match = RegExp(r'[^/]+?\.jpe?g', caseSensitive: false).firstMatch(url);
  // String filename = match?.group(0) ?? '${DateTime.now().millisecondsSinceEpoch}.jpg';
  HttpClient client = HttpClient();
  Uri target = Uri.parse(url);
  HttpClientRequest request = await client.getUrl(target);
  HttpClientResponse response = await request.close();
  int contentLength = response.contentLength;
  List<int> data = [];
  int downloaded = 0;
  response.listen((List<int> event) {
    data = [...data, ...event];
    downloaded += event.length;
    onProcess?.call(downloaded / contentLength);
  }, onError: (err) {
    throw err;
  }, onDone: () {
    Directory.current = path;
    File(target.pathSegments.last).writeAsBytes(data);
  });
}
