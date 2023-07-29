import 'dart:convert';

class SettingParams {
  bool enableProxy;
  SettingParams({this.enableProxy = false});

  Map toMap() {
    Map map = {};
    map['enableProxy'] = enableProxy;
    return map;
  }

  String toJson() {
    return jsonEncode(toMap());
  }

  factory SettingParams.fromJson(String json) {
    Map map = jsonDecode(json);
    return SettingParams(
      enableProxy: map['enableProxy']
    );
  }
}
