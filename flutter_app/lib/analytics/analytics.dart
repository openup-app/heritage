import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heritage/analytics/analytics_platform.dart';

final analyticsProvider =
    Provider<Analytics>((ref) => throw 'Uninitialized provider');

class Analytics {
  final AnalyticsPlatform platform;

  Analytics({
    required this.platform,
  });

  Future<void> setUser({
    required String uid,
    String? email,
    String? phoneNumber,
    String? firstName,
    String? lastName,
    String? fullName,
    String? photo,
  }) {
    return platform.setUser(
      uid: uid,
      email: email,
      phoneNumber: phoneNumber,
      firstName: firstName,
      lastName: lastName,
      fullName: fullName,
      photo: photo,
    );
  }

  Future<void> unsetUser() => platform.unsetUser();

  void trackPress(TrackedButton type) {
    platform.track('button_pressed', properties: {
      'type': type.name,
    });
  }
}

enum TrackedButton {
  profile,
  inviteFromCreation,
  inviteFromProfile,
  editPerson,
  deletePerson,
  addPerson,
  viewPerspective,
  recenter
}
