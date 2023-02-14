import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:clipboard/clipboard.dart';
import '../widget/entry.dart' as widgets;
import '../tool/api.dart';
import '../type/image.dart';
import '../model/list.dart';

class HomePage extends StatefulWidget {
  final String title;
  const HomePage({super.key, required this.title});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool loading = false;
  late ListModel<ImageSource> imageListModel;
  bool editMode = false;
  int imageSaved = 0;
  bool downloading = false;
  TextEditingController textEditingController = TextEditingController(text: '');
  final GlobalKey<AnimatedGridState> _gridKey = GlobalKey<AnimatedGridState>();

  String lastPasteText = '';

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    imageListModel = ListModel<ImageSource>(
        listKey: _gridKey,
        removedItemBuilder: _buildRemovedItem
    );

    WidgetsBinding.instance.addObserver(this);
    readClipboard();
  }

  Future<void> saveToGallery() async {
    if (imageListModel.isNotEmpty) {
      if (imageListModel.items.every((ImageSource source) => source.saved)) {
        Fluttertoast.showToast(msg: '所有的图片都已经保存', gravity: ToastGravity.BOTTOM);
        return;
      }
      setState(() {
        editMode = false;
        downloading = true;
      });
      for (final ImageSource source in imageListModel.items) {
        if (!source.saved) {
          try {
            await GallerySaver.saveImage(source.url,
                albumName: 'image-downloader');
            source.saved = true;
          } catch (err) {
            source.failed = true;
          }
        }
        imageSaved++;
        setState(() {});
      }
      setState(() {
        downloading = false;
        imageSaved = 0;
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
        imageListModel.setItems(
          list.map((String url) => ImageSource(url)).toList()
        );
        loading = false;
      });
    } else {
      Fluttertoast.showToast(msg: '目标地址找不到图片', gravity: ToastGravity.BOTTOM);
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
      errorWidget: (BuildContext context, String url, error) =>
          const Icon(Icons.error),
    );
  }

  Future<void> readClipboard() async {
    String pasteText = await FlutterClipboard.paste();
    if (pasteText.startsWith('http') &&
        pasteText != lastPasteText &&
        context.mounted) {
      showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
                title: const Text('从复制的链接查询'),
                content: const Text('检测到你刚刚复制了一个链接, 是否立即查询?',
                    maxLines: 2, softWrap: true),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        textEditingController.text = pasteText;
                        getImageList(pasteText);
                      },
                      child: const Text('查询链接')),
                  TextButton(
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade600),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'))
                ],
              ));
      lastPasteText = pasteText;
    }
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

  Widget _buildGrid(ImageSource source, VoidCallback? onRemove) {
    return Stack(
      fit: StackFit.expand,
      children: [
        InkWell(
          child: imageWidget(source.url),
          onTap: () {
            showDialog(
                context: context,
                builder: (BuildContext
                context) =>
                    Scaffold(
                      appBar: AppBar(
                        title:
                        const Text('预览'),
                      ),
                      body: Center(
                        child: imageWidget(
                            source.url),
                      ),
                      backgroundColor: Colors
                          .black
                          .withOpacity(.4),
                    ));
          },
        ),
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          bottom: 0,
          child: AnimatedScale(
            scale: editMode ? 1 : 0,
            duration: const Duration(
                milliseconds: 400),
            child: TextButton(
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero
                ),
                onPressed: onRemove,
                child: Container(
                    constraints:
                    const BoxConstraints
                        .expand(),
                    color: Colors.black
                        .withOpacity(.5),
                    child: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 36
                    )
                )
            ),
          ),
        ),
        AnimatedPositioned(
          left: 0,
          right: 0,
          bottom: (!source.saved || editMode)
              ? -40
              : 0,
          duration: const Duration(
              milliseconds: 400),
          child: Container(
            padding: const EdgeInsets.all(8),
            color:
            Colors.black.withOpacity(.5),
            child: const Icon(Icons.done,
                color: Colors.green),
          ),
        ),
        AnimatedPositioned(
            left: 0,
            right: 0,
            bottom:
            (!source.failed || editMode)
                ? -40
                : 0,
            duration: const Duration(
                milliseconds: 400),
            child: Container(
              padding:
              const EdgeInsets.all(8),
              color: Colors.black
                  .withOpacity(.4),
              child: const Icon(Icons.error,
                  color: Colors.red),
            ))
      ],
    );
  }

  Widget _gridItemBuilder(BuildContext context, int index, Animation<double> animation) {
    return widgets.ImageGrid(
        animation: animation,
        child: _buildGrid(imageListModel[index], () => onRemove(index))
    );
  }

  Widget _buildRemovedItem(
      ImageSource source, BuildContext context, Animation<double> animation) {
    return widgets.ImageGrid(
      animation: animation,
      removing: true,
      child: _buildGrid(source, () => onRemove(imageListModel.indexOf(source)))
    );
  }

  int get imageCount => imageListModel.length;

  void onRemove(int index) {
    setState(() {
      imageListModel.removeAt(index);
    });
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
                  border: OutlineInputBorder(), labelText: '链接地址'),
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
                  child: imageListModel.isNotEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('获取到$imageCount张图片'),
                                  IconButton(
                                      onPressed: () {
                                        if (!downloading) {
                                          setState(() {
                                            editMode = !editMode;
                                          });
                                        }
                                      },
                                      color: Colors.green,
                                      icon: Icon(editMode
                                          ? Icons.done
                                          : Icons.edit_note))
                                ],
                              ),
                            ),
                            Expanded(
                              child: Stack(
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  AnimatedGrid(
                                    key: _gridKey,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 3,
                                            mainAxisSpacing: 1.0,
                                            crossAxisSpacing: 1.0),
                                    initialItemCount: imageCount,
                                    itemBuilder: _gridItemBuilder,
                                  ),
                                  AnimatedPositioned(
                                    left: 0,
                                    bottom: downloading ? 0 : -60,
                                    right: 0,
                                    duration: const Duration(microseconds: 400),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          color: Colors.black.withOpacity(.75),
                                          padding: const EdgeInsets.all(12.0),
                                          child: Text(
                                            '图片下载中 $imageSaved / $imageCount',
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                        ),
                                        LinearProgressIndicator(
                                            value: imageSaved / imageCount)
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            )
                          ],
                        )
                      : const Center(
                          child: Text('暂无图片'),
                        ),
                ),
              ),
              widgets.LoadingOverlay(
                open: loading,
              )
            ],
          ))
        ],
      ),
      floatingActionButton: (imageListModel.isNotEmpty && !downloading)
          ? FloatingActionButton(
              onPressed: saveToGallery,
              tooltip: '保存到相册',
              child: const Icon(Icons.download),
            )
          : null, // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
