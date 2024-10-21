import 'package:heritage/analytics/analytics_platform.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

class MixpanelPlatform implements AnalyticsPlatform {
  final Mixpanel _mixpanel;

  MixpanelPlatform(this._mixpanel);

  @override
  Future<void> setUser({
    required String uid,
    required String? email,
    required String? phoneNumber,
    required String? firstName,
    required String? lastName,
    required String? fullName,
    required String? photo,
  }) async {
    await _mixpanel.identify(uid);
    final people = _mixpanel.getPeople();
    if (email != null) {
      people.set('\$email', email);
    }
    if (phoneNumber != null) {
      people.set('\$phone', phoneNumber);
    }
    if (firstName != null) {
      people.set('\$first_name', firstName);
    }
    if (lastName != null) {
      people.set('\$last_name', lastName);
    }
    if (fullName != null) {
      people.set('\$name', fullName);
    }
    if (photo != null) {
      people.set('\$avatar', photo);
    }
  }

  @override
  Future<void> unsetUser() async {
    await _mixpanel.reset();
  }

  @override
  Future<void> track(String event, {Map<String, dynamic>? properties}) async {
    await _mixpanel.track(event, properties: properties);
  }
}
