import 'package:flutter/material.dart';
import '../widgets/entry.dart';
import '../types/image.dart';

class Preview extends StatefulWidget {
  final List<ImageSource> sources;
  final int initIndex;
  final String Function(String)? urlTransform;
  final Future<void> Function(ImageSource, int) onSave;
  final bool Function(int) onRemove;

  const Preview(
      {super.key,
      required this.sources,
      this.initIndex = 0,
      this.urlTransform,
      required this.onSave,
      required this.onRemove});

  @override
  State<StatefulWidget> createState() => PreviewState();
}

class PreviewState extends State<Preview> {
  late List<ImageSource> sources;
  late PageController _controller;
  late int pageIndex;

  bool downloading = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    sources =
        List.generate(widget.sources.length, (index) => widget.sources[index]);
    pageIndex = widget.initIndex;
    _controller = PageController(initialPage: pageIndex, keepPage: true);
  }

  ImageSource get activeSource => sources[pageIndex];

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      appBar: AppBar(
        title: Text('预览 - ${pageIndex + 1} / ${sources.length}',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            children: sources
                .map((ImageSource source) => Stack(
                      alignment: Alignment.center,
                      children: [
                        CachedImage(
                            url: widget.urlTransform != null
                                ? widget.urlTransform!(source.url)
                                : source.url),
                        Positioned(
                            left: 0,
                            right: 0,
                            bottom: 20,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedOpacity(
                                  opacity: (downloading || activeSource.saved)
                                      ? .75
                                      : 1,
                                  duration: const Duration(milliseconds: 400),
                                  child: IconButton(
                                      onPressed: () async {
                                        if (!downloading &&
                                            !activeSource.saved) {
                                          setState(() {
                                            downloading = true;
                                          });
                                          await widget.onSave(
                                              activeSource, pageIndex);
                                          if (mounted) {
                                            setState(() {
                                              downloading = false;
                                            });
                                          }
                                        }
                                      },
                                      icon: Icon(activeSource.saved
                                          ? Icons.download_done
                                          : Icons.download)),
                                ),
                                const SizedBox(
                                  width: 20,
                                ),
                                IconButton(
                                    onPressed: () async {
                                      bool canRemove =
                                          widget.onRemove(pageIndex);
                                      if (canRemove) {
                                        if (sources.length > 1) {
                                          sources.removeAt(pageIndex);
                                          if (pageIndex > 0) {
                                            await _controller.previousPage(
                                                duration: const Duration(
                                                    milliseconds: 250),
                                                curve: Curves.linear);
                                          }
                                          setState(() {});
                                        } else if (mounted) {
                                          Navigator.pop(context);
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red))
                              ],
                            ))
                      ],
                    ))
                .toList(),
            onPageChanged: (int nextPage) {
              setState(() {
                pageIndex = nextPage;
              });
            },
          ),
          LoadingOverlay(
            open: downloading,
            label: '下载中..',
          )
        ],
      ),
      backgroundColor: Colors.black.withOpacity(.75),
    );
  }
}
