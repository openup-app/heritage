import 'package:heritage/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kUidKey = 'uid';

class Storage {
  final SharedPreferences sharedPreferences;

  Storage({
    required this.sharedPreferences,
  });

  void saveUid(Id id) => sharedPreferences.setString(_kUidKey, id);

  String? loadUid() => sharedPreferences.getString(_kUidKey);

  void clearUid() => sharedPreferences.remove(_kUidKey);
}
