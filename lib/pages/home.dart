import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:clipboard/clipboard.dart';
import '../widget/entry.dart' as widgets;
import '../tool/api.dart';
import '../type/image.dart';
import '../model/list.dart';
import './preview.dart';

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
        listKey: _gridKey, removedItemBuilder: _buildRemovedItem);

    WidgetsBinding.instance.addObserver(this);
    readClipboard();
  }

  Future<void> saveImageSource(ImageSource source) async {
    if (!source.saved) {
      try {
        await GallerySaver.saveImage(source.url,
            albumName: 'image-downloader');
        source.saved = true;
      } catch (err) {
        source.failed = true;
      }
    }
  }

  Future<void> saveToGallery() async {
    if (imageCount > 0) {
      if (imageListModel.items.every((ImageSource source) => source.saved)) {
        showToast('所有的图片都已经保存');
        return;
      }
      setState(() {
        editMode = false;
        downloading = true;
      });
      for (final ImageSource source in imageListModel.items) {
        await saveImageSource(source);
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
      try {
        List<String> list = await getImages(url);
        if (list.isNotEmpty) {
          for (int i = imageListModel.length - 1; i >= 0; i--) {
            imageListModel.removeAt(i);
          }
          for (int j = 0; j < list.length; j++) {
            imageListModel.insert(imageListModel.length, ImageSource(list[j]));
          }
          loading = false;
          setState(() {});
        }
        else {
          showToast('没有在链接地址找到图片');
        }
      }
      catch (err) {
        showToast('链接地址访问出错');
      }
    } else {
      showToast('链接地址不能为空');
    }
  }

  void showToast(String msg) {
    Fluttertoast.showToast(msg: msg, gravity: ToastGravity.BOTTOM);
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

  Widget _buildAlertWidget(bool show,
      {required String label, required Icon icon}) {
    return AnimatedPositioned(
      left: 0,
      right: 0,
      bottom: show ? -40 : 0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(8),
        color: Colors.black.withOpacity(.5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            icon,
            const SizedBox(
              width: 8,
            ),
            Text(label, style: const TextStyle(color: Colors.white))
          ],
        ),
      ),
    );
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
          child: widgets.CachedImage(url: source.url),
          onTap: () {
            showGeneralDialog(
                context: context,
                pageBuilder: (BuildContext context, Animation<double> start,
                    Animation<double> end) => Preview(
                  sources: imageListModel.items,
                  initIndex: imageListModel.indexOf(source),
                  onRemove: (int index) {
                    setState(() {
                      imageListModel.removeAt(index);
                    });
                  },
                  onSave: (int index) async {
                    ImageSource source = imageListModel.items[index];
                    await saveImageSource(source);
                    showToast('已成功保存到相册');
                  },
                ),
                transitionBuilder: (BuildContext context,
                    Animation<double> start,
                    Animation<double> end,
                    Widget child) {
                  return ScaleTransition(
                    scale: CurvedAnimation(
                      parent: start,
                      curve: Curves.easeInQuad
                    ),
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 400));
          },
        ),
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          bottom: 0,
          child: AnimatedScale(
            scale: editMode ? 1 : 0,
            duration: const Duration(milliseconds: 400),
            child: TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: onRemove,
                child: Container(
                    constraints: const BoxConstraints.expand(),
                    color: Colors.black.withOpacity(.5),
                    child: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 36))),
          ),
        ),
        _buildAlertWidget(!source.saved || editMode,
            label: '下载成功', icon: const Icon(Icons.download_done, color: Colors.green)),
        _buildAlertWidget(!source.failed || editMode,
            label: '下载出错', icon: const Icon(Icons.error, color: Colors.red))
      ],
    );
  }

  Widget _gridItemBuilder(
      BuildContext context, int index, Animation<double> animation) {
    return widgets.ImageGrid(
        animation: animation,
        child: _buildGrid(imageListModel[index], () => onRemove(index)));
  }

  Widget _buildRemovedItem(
      ImageSource source, BuildContext context, Animation<double> animation) {
    return widgets.ImageGrid(
        animation: animation,
        removing: true,
        child:
            _buildGrid(source, () => onRemove(imageListModel.indexOf(source))));
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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: textEditingController,
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: '链接地址',
                        hintText: '输入链接地址'
                    ),
                    spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.send,
                    onSubmitted: getImageList
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                TextButton(
                    onPressed: () => getImageList(textEditingController.text),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white
                    ),
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      child: const Text('获取'),
                    )
                )
              ],
            ),
          ),
          Expanded(
              child: Stack(
            children: [
              widgets.Card(
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Stack(
                    children: [
                      AnimatedOpacity(
                        opacity: imageCount > 0 ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                            constraints: const BoxConstraints.expand(),
                            child: Column(
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
                                        duration:
                                            const Duration(microseconds: 400),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Container(
                                              color:
                                                  Colors.black.withOpacity(.75),
                                              padding:
                                                  const EdgeInsets.all(12.0),
                                              child: Text(
                                                '图片下载中 $imageSaved / $imageCount',
                                                style: const TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                            imageCount > 0
                                                ? LinearProgressIndicator(
                                                    value:
                                                        imageSaved / imageCount)
                                                : Container()
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                )
                              ],
                            )),
                      ),
                      AnimatedOpacity(
                        opacity: imageCount > 0 ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: const Center(
                          child: Text('输入网址获取图片'),
                        ),
                      )
                    ],
                  )),
              widgets.LoadingOverlay(
                open: loading,
              )
            ],
          ))
        ],
      ),
      floatingActionButton: (imageCount > 0 && !downloading)
          ? FloatingActionButton(
              onPressed: saveToGallery,
              tooltip: '保存到相册',
              child: const Icon(Icons.download),
            )
          : null, // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
