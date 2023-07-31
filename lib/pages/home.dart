import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:clipboard/clipboard.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../widgets/entry.dart' as widgets;
import '../tools/const.dart';
import '../tools/theme.dart';
import '../tools/api.dart';
import '../types/image.dart';
import '../models/list.dart';
import '../models/setting.dart';
import './preview.dart';
import './setting.dart';

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

  SettingParams settingParams = SettingParams();

  final storage = const FlutterSecureStorage();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    imageListModel = ListModel<ImageSource>(
        listKey: _gridKey, removedItemBuilder: _buildRemovedItem);

    WidgetsBinding.instance.addObserver(this);

    readClipboard();
    restoreSetting();
  }

  String getProxyUrl(String url) {
    return settingParams.enableProxy ? proxyUrl(url) : url;
  }

  Future<void> restoreSetting() async {
    String? store = await storage.read(key: Keys.settingStorage);
    if (store != null) {
      settingParams = SettingParams.fromJson(store);
    }
  }

  Future<bool> saveImageSource(ImageSource source) async {
    if (!source.saved) {
      try {
        await GallerySaver.saveImage(getProxyUrl(source.url),
            albumName: Keys.albumName,
            headers: settingParams.enableProxy
                ? null
                : {'referer': Uri.parse(source.url).origin});
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
    String url = text.trim();
    if (url.isNotEmpty) {
      setState(() {
        editMode = false;
        loading = true;
      });
      try {
        List<String> list = await getImages(getProxyUrl(url));
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
    if (pasteText.startsWith('http') &&
        pasteText != lastPasteText &&
        context.mounted) {
      showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
                title: const Text('从复制的链接查询'),
                content: const Text('你刚刚复制了一个链接, 是否立即查询?',
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
          child: widgets.CachedImage(url: getProxyUrl(source.url)),
          onTap: () {
            showGeneralDialog(
                context: context,
                pageBuilder: (BuildContext context, Animation<double> start,
                        Animation<double> end) =>
                    Preview(
                      sources: imageListModel.items,
                      initIndex: imageListModel.indexOf(source),
                      urlTransform: getProxyUrl,
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
                          ImageSource associatedSource =
                              imageListModel.items[index];
                          associatedSource.saved = true;
                          associatedSource.failed = false;
                        }
                        showToast(done ? '已成功保存到相册' : '下载失败, 可能是网络连接不畅');
                      },
                    ),
                transitionBuilder: (BuildContext context,
                    Animation<double> start,
                    Animation<double> end,
                    Widget child) {
                  return ScaleTransition(
                    scale: CurvedAnimation(
                        parent: start, curve: Curves.easeInQuad),
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
            label: '下载成功',
            icon: Icon(Icons.download_done, color: AppTheme.themeColor)),
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

  void showSetting() async {
    settingParams = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (BuildContext context) => Setting(params: settingParams)));
    await storage.write(
        key: Keys.settingStorage, value: settingParams.toJson());
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            actions: [
              IconButton(
                  onPressed: showSetting, icon: const Icon(Icons.settings))
            ],
          ),
          backgroundColor: Colors.grey[200],
          body: Column(
            children: <Widget>[
              widgets.Card(
                child: TextField(
                  focusNode: textFieldFocus,
                  controller: textEditingController,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      labelText: '链接地址',
                      hintText: '输入链接地址'),
                  spellCheckConfiguration:
                      const SpellCheckConfiguration.disabled(),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.send,
                  onSubmitted: getImageList,
                  onTapOutside: (PointerDownEvent event) {
                    textFieldFocus.unfocus();
                  },
                ),
              ),
              Expanded(
                  child: Stack(
                children: [
                  widgets.Card(
                      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                                          Scrollbar(
                                            radius: const Radius.circular(3),
                                            child: AnimatedGrid(
                                              key: _gridKey,
                                              controller: _gridController,
                                              gridDelegate:
                                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                                      crossAxisCount: 3,
                                                      mainAxisSpacing: 1.0,
                                                      crossAxisSpacing: 1.0),
                                              initialItemCount: imageCount,
                                              itemBuilder: _gridItemBuilder,
                                            ),
                                          ),
                                          AnimatedPositioned(
                                            left: 0,
                                            bottom: (downloading && !isAborted)
                                                ? 0
                                                : -60,
                                            right: 0,
                                            duration: const Duration(
                                                microseconds: 400),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Container(
                                                  color: Colors.black
                                                      .withOpacity(.75),
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 8.0),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        '图片下载中 $imageSaved / $imageCount',
                                                        style: const TextStyle(
                                                            color:
                                                                Colors.white),
                                                      ),
                                                      IconButton(
                                                        onPressed: () {
                                                          setState(() {
                                                            isAborted = true;
                                                            loading = false;
                                                          });
                                                        },
                                                        icon: const Icon(
                                                            Icons.close),
                                                        color: Colors.red,
                                                      )
                                                    ],
                                                  ),
                                                ),
                                                imageCount > 0
                                                    ? LinearProgressIndicator(
                                                        value: imageSaved /
                                                            imageCount)
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
                            opacity: (imageCount > 0 || loading) ? 0 : 1,
                            duration: const Duration(milliseconds: 200),
                            child: Center(
                              child: Text('输入网址获取图片',
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600)),
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
