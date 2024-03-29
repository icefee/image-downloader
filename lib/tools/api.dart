import 'dart:io';
import 'package:http/http.dart';

Future<List<String>> getImages(String url) async {
  Response response = await get(Uri.parse(url));
  Iterable<RegExpMatch> matches =
      RegExp(r'(https?://)?[\w\u4e00-\u9fa5-./@%?:]+?\.((jpe?|pn)g|gif|webp)', caseSensitive: false)
          .allMatches(response.body.replaceAll(RegExp(r'\\/'), '/'));
  List<String> images = matches.map((m) => m.group(0)!).toSet().toList();
  Uri uri = Uri.parse(url);
  for (int i = 0; i < images.length; i++) {
    String image = images[i];
    if (!image.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      if (image.startsWith('/')) {
        if (image.startsWith('//')) {
          images[i] = '${uri.scheme}:$image';
        } else {
          images[i] = uri.origin + image;
        }
      } else {
        images[i] = uri.origin + (uri.path.isNotEmpty ? uri.path : '/') + image;
      }
    }
  }
  return images;
}

String proxyUrl(String url) {
  const String proxyUrl = 'https://spacedeta-3-f1000878.deta.app/api/proxy';
  String encoded = Uri.encodeComponent(url);
  return '$proxyUrl?url=$encoded';
}

Future<void> downloadImage(String url, String path, {Function(double)? onProcess}) async {
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
