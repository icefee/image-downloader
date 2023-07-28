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
  final _gridController = ScrollController();
  bool isAborted = false;
  FocusNode textFieldFocus = FocusNode();

  String lastPasteText = '';
  int lastRequestExitTime = 0;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    imageListModel = ListModel<ImageSource>(listKey: _gridKey, removedItemBuilder: _buildRemovedItem);

    WidgetsBinding.instance.addObserver(this);
    readClipboard();
  }

  Future<bool> saveImageSource(ImageSource source) async {
    if (!source.saved) {
      try {
        await GallerySaver.saveImage(source.url,
            albumName: 'image-downloader', headers: {'referer': Uri.parse(source.url).origin});
        source.saved = true;
        source.failed = false;
        return true;
      } catch (err) {
        source.failed = true;
        return false;
      }
    }
    return true;
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
        isAborted = false;
      });
      for (final ImageSource source in imageListModel.items) {
        if (isAborted) {
          break;
        }
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
          _gridController.jumpTo(0);
          for (int i = imageListModel.length - 1; i >= 0; i--) {
            imageListModel.removeAt(i);
          }
          for (int j = 0; j < list.length; j++) {
            imageListModel.insert(imageListModel.length, ImageSource(list[j]));
          }
        } else {
          showToast('没有在链接地址找到图片');
        }
      } catch (err) {
        showToast('链接地址访问出错');
      }
      setState(() {
        loading = false;
      });
    } else {
      showToast('链接地址不能为空');
    }
  }

  void showToast(String msg) {
    Fluttertoast.showToast(msg: msg, gravity: ToastGravity.BOTTOM);
  }

  Future<void> readClipboard() async {
    String pasteText = await FlutterClipboard.paste();
    if (pasteText.startsWith('http') && pasteText != lastPasteText && context.mounted) {
      showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
                title: const Text('从复制的链接查询'),
                content: const Text('你刚刚复制了一个链接, 是否立即查询?', maxLines: 2, softWrap: true),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        textEditingController.text = pasteText;
                        getImageList(pasteText);
                      },
                      child: const Text('查询链接')),
                  TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'))
                ],
              ));
      lastPasteText = pasteText;
    }
  }

  Widget _buildAlertWidget(bool show, {required String label, required Icon icon}) {
    return AnimatedPositioned(
      left: 0,
      right: 0,
      bottom: show ? -40 : 0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
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
                pageBuilder: (BuildContext context, Animation<double> start, Animation<double> end) => Preview(
                      sources: imageListModel.items,
                      initIndex: imageListModel.indexOf(source),
                      onRemove: (int index) {
                        if (downloading) {
                          showToast('当前下载中, 无法删除图片');
                          return false;
                        }
                        setState(() {
                          imageListModel.removeAt(index);
                        });
                        return true;
                      },
                      onSave: (ImageSource source, int index) async {
                        if (downloading) {
                          showToast('当前有下载任务进行中, 请等待下载完成');
                          return;
                        }
                        bool done = await saveImageSource(source);
                        if (done) {
                          ImageSource associatedSource = imageListModel.items[index];
                          associatedSource.saved = true;
                          associatedSource.failed = false;
                        }
                        showToast(done ? '已成功保存到相册' : '下载失败, 可能是网络连接不畅');
                      },
                    ),
                transitionBuilder:
                    (BuildContext context, Animation<double> start, Animation<double> end, Widget child) {
                  return ScaleTransition(
                    scale: CurvedAnimation(parent: start, curve: Curves.easeInQuad),
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
                    child: const Icon(Icons.delete_outline, color: Colors.red, size: 36))),
          ),
        ),
        _buildAlertWidget(!source.saved || editMode,
            label: '下载成功', icon: const Icon(Icons.download_done, color: Colors.deepOrange)),
        _buildAlertWidget(!source.failed || editMode, label: '下载出错', icon: const Icon(Icons.error, color: Colors.red))
      ],
    );
  }

  Widget _gridItemBuilder(BuildContext context, int index, Animation<double> animation) {
    return widgets.ImageGrid(animation: animation, child: _buildGrid(imageListModel[index], () => onRemove(index)));
  }

  Widget _buildRemovedItem(ImageSource source, BuildContext context, Animation<double> animation) {
    return widgets.ImageGrid(
        animation: animation,
        removing: true,
        child: _buildGrid(source, () => onRemove(imageListModel.indexOf(source))));
  }

  int get imageCount => imageListModel.length;

  void onRemove(int index) {
    setState(() {
      imageListModel.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        child: Scaffold(
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
                        focusNode: textFieldFocus,
                        controller: textEditingController,
                        decoration:
                            const InputDecoration(border: OutlineInputBorder(), labelText: '链接地址', hintText: '输入链接地址'),
                        spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.send,
                        onSubmitted: getImageList,
                        onTapOutside: (PointerDownEvent event) {
                          textFieldFocus.unfocus();
                        },
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    TextButton(
                        onPressed: () => getImageList(textEditingController.text),
                        style: TextButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          child: const Text('获取'),
                        ))
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
                                      padding: const EdgeInsets.fromLTRB(5, 0, 0, 5),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                              color: Colors.deepOrange,
                                              icon: Icon(editMode ? Icons.done : Icons.edit_note))
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Stack(
                                        clipBehavior: Clip.hardEdge,
                                        children: [
                                          Theme(
                                            data: Theme.of(context).copyWith(
                                                scrollbarTheme: ScrollbarThemeData(
                                                    thumbColor:
                                                        MaterialStateProperty.all(Colors.deepOrange.withOpacity(.7)))),
                                            child: Scrollbar(
                                              radius: const Radius.circular(3),
                                              child: AnimatedGrid(
                                                key: _gridKey,
                                                controller: _gridController,
                                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                                    crossAxisCount: 3, mainAxisSpacing: 1.0, crossAxisSpacing: 1.0),
                                                initialItemCount: imageCount,
                                                itemBuilder: _gridItemBuilder,
                                              ),
                                            ),
                                          ),
                                          AnimatedPositioned(
                                            left: 0,
                                            bottom: (downloading && !isAborted) ? 0 : -60,
                                            right: 0,
                                            duration: const Duration(microseconds: 400),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                Container(
                                                  color: Colors.black.withOpacity(.75),
                                                  padding: const EdgeInsets.only(left: 8.0),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        '图片下载中 $imageSaved / $imageCount',
                                                        style: const TextStyle(color: Colors.white),
                                                      ),
                                                      IconButton(
                                                        onPressed: () {
                                                          setState(() {
                                                            isAborted = true;
                                                            loading = false;
                                                          });
                                                        },
                                                        icon: const Icon(Icons.close),
                                                        color: Colors.red,
                                                      )
                                                    ],
                                                  ),
                                                ),
                                                imageCount > 0
                                                    ? LinearProgressIndicator(value: imageSaved / imageCount)
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
                    label: '获取中..',
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
        ),
        onWillPop: () async {
          int nowTime = DateTime.now().millisecondsSinceEpoch;
          if (nowTime - lastRequestExitTime < 2e3) {
            return true;
          } else {
            showToast('再按一次返回退出');
            lastRequestExitTime = nowTime;
            return false;
          }
        });
  }
}
