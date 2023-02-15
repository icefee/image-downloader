import 'package:flutter/material.dart';
import '../widget/entry.dart';
import '../type/image.dart';

class Preview extends StatefulWidget {
  final List<ImageSource> sources;
  final int initIndex;
  final Future<void> Function(int) onSave;
  final ValueChanged<int> onRemove;

  const Preview(
      {super.key,
      required this.sources,
      this.initIndex = 0,
      required this.onSave,
      required this.onRemove});

  @override
  State<StatefulWidget> createState() => PreviewState();
}

class PreviewState extends State<Preview> {
  late List<ImageSource> sources;
  late PageController _controller;
  late int pageIndex;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    sources =
        List.generate(widget.sources.length, (index) => widget.sources[index]);
    pageIndex = widget.initIndex;
    _controller = PageController(initialPage: pageIndex, keepPage: true);
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      appBar: AppBar(
        title: Text('预览 - ${pageIndex + 1} / ${sources.length}'),
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close)),
        centerTitle: true,
      ),
      body: PageView(
        controller: _controller,
        children: sources
            .map((ImageSource source) => Stack(
                  alignment: Alignment.center,
                  children: [
                    CachedImage(url: source.url),
                    Positioned(
                        left: 0,
                        right: 0,
                        bottom: 20,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: () async {
                                widget.onRemove(pageIndex);
                                sources.removeAt(pageIndex);
                                if (pageIndex > 0) {
                                  await _controller.previousPage(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      curve: Curves.linear);
                                }
                                setState(() {});
                              },
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red,
                            ),
                            const SizedBox(
                              width: 20,
                            ),
                            IconButton(
                              onPressed: () async {
                                await widget.onSave(pageIndex);
                                sources[pageIndex].saved = true;
                                setState(() {});
                              },
                              icon: Icon(sources[pageIndex].saved
                                  ? Icons.download_done
                                  : Icons.download),
                              color: Colors.green,
                            )
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
      backgroundColor: Colors.black.withOpacity(.75),
    );
  }
}
