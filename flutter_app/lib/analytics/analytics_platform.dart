import 'package:flutter/foundation.dart';
import 'package:heritage/analytics/analytics.dart';
import 'package:heritage/analytics/mixpanel_analytics.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

Future<Analytics> initAnalytics() async {
  if (kReleaseMode && kIsWeb) {
    const mixpanelToken = String.fromEnvironment('MIXPANEL_TOKEN');
    final mixpanel = await Mixpanel.init(
      mixpanelToken,
      trackAutomaticEvents: true,
    );
    return Analytics(
      platform: MixpanelPlatform(mixpanel),
    );
  } else {
    return Analytics(
      platform: const FakeAnalyticsPlatform(),
    );
  }
}

abstract class AnalyticsPlatform {
  Future<void> setUser({
    required String uid,
    required String? email,
    required String? phoneNumber,
    required String? firstName,
    required String? lastName,
    required String? fullName,
    required String? photo,
  });
  Future<void> unsetUser();
  Future<void> track(String event, {Map<String, dynamic>? properties});
}

class FakeAnalyticsPlatform implements AnalyticsPlatform {
  const FakeAnalyticsPlatform();

  @override
  Future<void> setUser({
    required String uid,
    required String? email,
    required String? phoneNumber,
    required String? firstName,
    required String? lastName,
    required String? fullName,
    required String? photo,
  }) {
    // ignore: avoid_print
    print(
        '[Analytics]: User is E:$email, P:$phoneNumber, N:$firstName $lastName ($fullName), Photo: $photo, UID: $uid)');
    return Future.value();
  }

  @override
  Future<void> unsetUser() {
    // ignore: avoid_print
    print('[Analytics]: User unset');
    return Future.value();
  }

  @override
  Future<void> track(String event, {Map<String, dynamic>? properties}) {
    // ignore: avoid_print
    print('[Analytics]: $event $properties');
    return Future.value();
  }
}
