import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:clipboard/clipboard.dart';
import '../widget/entry.dart' as widgets;
import '../tool/api.dart';
import '../type/image.dart';

class HomePage extends StatefulWidget {
  final String title;
  const HomePage({super.key, required this.title});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {

  bool loading = false;
  List<ImageSource> images = [];
  bool editMode = false;
  int imageSaved = 0;
  bool downloading = false;
  TextEditingController textEditingController = TextEditingController(
    text: ''
  );

  String lastPasteText = '';

  Future<void> saveToGallery() async {
    if (images.isNotEmpty) {
      if (images.every((ImageSource source) => source.saved)) {
        Fluttertoast.showToast(
            msg: '所有的图片都已经保存',
            gravity: ToastGravity.BOTTOM
        );
        return;
      }
      setState(() {
        imageSaved = 0;
        downloading = true;
      });
      for (final ImageSource source in images) {
        if (!source.saved) {
          try {
            await GallerySaver.saveImage(
                source.url,
                albumName: 'image-downloader'
            );
            source.saved = true;
          }
          catch (err) {
            source.failed = true;
          }
        }
        imageSaved ++;
        setState(() {});
      }
      setState(() {
        downloading = false;
      });
    }
  }

  Future<void> getImageList(String text) async {
    String url = text.trimLeft().trimRight();
    if (url.isNotEmpty) {
      setState(() {
        editMode = false;
        loading = true;
      });
      List<String> list = await getImages(url);
      setState(() {
        images = list.map((String url) => ImageSource(url)).toList();
        loading = false;
      });
    }
    else {
      Fluttertoast.showToast(
        msg: '目标地址找不到图片',
        gravity: ToastGravity.BOTTOM
      );
    }
  }

  Widget imageWidget(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (BuildContext context, String url) => const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (BuildContext context, String url, error) => const Icon(Icons.error),
    );
  }

  Future<void> readClipboard() async {
    String pasteText = await FlutterClipboard.paste();
    if (pasteText.startsWith('http') && pasteText != lastPasteText && context.mounted) {
      showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('从复制的链接查询'),
            content: const Text('检测到你刚刚复制了一个链接, 是否立即查询?', maxLines: 2, softWrap: true),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    textEditingController.text = pasteText;
                    getImageList(pasteText);
                  },
                  child: const Text('查询链接')
              ),
              TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消')
              )
            ],
          )
      );
      lastPasteText = pasteText;
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    readClipboard();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // TODO: implement didChangeAppLifecycleState
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      readClipboard();
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      backgroundColor: Colors.grey[200],
      body: Column(
        children: <Widget>[
          widgets.Card(
            child: TextField(
              controller: textEditingController,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '链接地址'
              ),
              spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.send,
              onSubmitted: (String text) {
                getImageList(text);
              },
            ),
          ),
          Expanded(
              child: Stack(
                children: [
                  widgets.Card(
                    margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Container(
                      constraints: const BoxConstraints.expand(),
                      child: images.isNotEmpty ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('获取到${images.length}张图片'),
                                IconButton(
                                    onPressed: () {
                                      if (!downloading) {
                                        setState(() {
                                          editMode = !editMode;
                                        });
                                      }
                                    },
                                    color: Colors.green,
                                    icon: Icon(
                                        editMode ? Icons.done : Icons.edit_note
                                    )
                                )
                              ],
                            ),
                          ),
                          Expanded(
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                GridView(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 1.0,
                                    crossAxisSpacing: 1.0
                                  ),
                                  children: images.map((ImageSource source) => Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      InkWell(
                                        child: imageWidget(source.url),
                                        onTap: () {
                                          showDialog(
                                              context: context,
                                              builder: (BuildContext context) => Scaffold(
                                                appBar: AppBar(
                                                  title: const Text('预览'),
                                                ),
                                                body: Center(
                                                  child: imageWidget(source.url),
                                                ),
                                                backgroundColor: Colors.black.withOpacity(.4),
                                              )
                                          );
                                        },
                                      ),
                                      Positioned(
                                        left: 0,
                                        top: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: Offstage(
                                          offstage: !editMode,
                                          child: Container(
                                            constraints: const BoxConstraints.expand(),
                                            color: Colors.black.withOpacity(.5),
                                            child: IconButton(
                                              icon: const Icon(Icons.delete_forever_outlined, color: Colors.red, size: 36),
                                              onPressed: () {
                                                images.remove(source);
                                                setState(() {});
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: Offstage(
                                          offstage: !source.saved || editMode,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            color: Colors.black.withOpacity(.5),
                                            child: const Icon(Icons.done, color: Colors.green),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: Offstage(
                                          offstage: !source.failed || editMode,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            color: Colors.black.withOpacity(.4),
                                            child: const Icon(Icons.error, color: Colors.red),
                                          ),
                                        ),
                                      )
                                    ],
                                  )).toList(),
                                ),
                                AnimatedPositioned(
                                  left: 0,
                                  bottom: downloading ? 0 : -60,
                                  right: 0,
                                  duration: const Duration(microseconds: 400),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
                                        color: Colors.black.withOpacity(.75),
                                        padding: const EdgeInsets.all(12.0),
                                        child: Text(
                                          '图片下载中 $imageSaved / ${images.length}',
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      LinearProgressIndicator(
                                          value: imageSaved / images.length
                                      )
                                    ],
                                  ),
                                )
                              ],
                            ),
                          )
                        ],
                      ) : const Center(
                        child: Text('暂无图片'),
                      ),
                    ),
                  ),
                  widgets.LoadingOverlay(
                    open: loading,
                  )
                ],
              )
          )
        ],
      ),
      floatingActionButton: (images.isNotEmpty && !downloading) ? FloatingActionButton(
        onPressed: saveToGallery,
        tooltip: '保存到相册',
        child: const Icon(Icons.download),
      ) : null, // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}