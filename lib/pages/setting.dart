import 'package:flutter/material.dart';
import '../widgets/entry.dart' as widgets;
import '../models/setting.dart';

class Setting extends StatefulWidget {
  const Setting({super.key, required this.params});

  final SettingParams params;

  @override
  State<StatefulWidget> createState() => SettingState();
}

class SettingState extends State<Setting> {
  late SettingParams params;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    params = widget.params;
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return WillPopScope(
        onWillPop: () async {
          Navigator.pop<SettingParams>(context, params);
          return true;
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('设置')),
          backgroundColor: Colors.grey[200],
          body: ListView(
            children: [
              widgets.FormField(
                title: '启用代理',
                formWidget: Switch(
                    value: params.enableProxy,
                    onChanged: (bool value) {
                      setState(() {
                        params.enableProxy = value;
                      });
                    }),
              )
            ],
          ),
        )
    );
  }
}
