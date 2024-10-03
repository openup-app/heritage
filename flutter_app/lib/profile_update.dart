import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:heritage/api.dart';
import 'package:heritage/date.dart';
import 'package:heritage/file_picker.dart';

part 'profile_update.freezed.dart';

final profileUpdateProvider =
    StateNotifierProvider<ProfileUpdateNotifier, ProfileUpdate>(
        (ref) => throw 'Uninitialized provider');

class ProfileUpdateNotifier extends StateNotifier<ProfileUpdate> {
  final Profile initialProfile;

  ProfileUpdateNotifier({
    required this.initialProfile,
  }) : super(ProfileUpdate(profile: initialProfile));

  void firstName(String value) =>
      state = state.copyWith.profile(firstName: value);

  void lastName(String value) =>
      state = state.copyWith.profile(lastName: value);

  void gender(Gender gender) => state = state.copyWith.profile(gender: gender);

  void birthday(String value) {
    if (value.isEmpty) {
      state = state.copyWith.profile(birthday: null);
    } else {
      final birthday = tryParseSeparatedDate(value);
      if (birthday != null) {
        state = state.copyWith.profile(
            birthday: DateTime(birthday.year, birthday.month, birthday.day));
      }
    }
  }

  void birthdayObject(DateTime value) =>
      state = state.copyWith.profile(birthday: value);

  void deathday(String value) {
    if (value.isEmpty) {
      state = state.copyWith.profile(deathday: null);
    } else {
      final deathday = tryParseSeparatedDate(value);
      if (deathday != null) {
        state = state.copyWith.profile(
            deathday: DateTime(deathday.year, deathday.month, deathday.day));
      }
    }
  }

  void deathdayObject(DateTime value) =>
      state = state.copyWith.profile(deathday: value);

  void birthplace(String value) =>
      state = state.copyWith.profile(birthplace: value);

  Future<void> image(Uint8List value) async {
    final downscaled = await downscaleImage(value, size: 300);
    if (!mounted) {
      return Future.value();
    }
    if (downscaled == null) {
      return;
    }
    state = state.copyWith(image: downscaled);
  }
}

@freezed
class ProfileUpdate with _$ProfileUpdate {
  const factory ProfileUpdate({
    required Profile profile,
    @Default(null) Uint8List? image,
  }) = _ProfileUpdate;

  const ProfileUpdate._();

  String get firstName => profile.firstName;
  String get lastName => profile.lastName;
  String get fullName => profile.fullName;
  Gender get gender => profile.gender;
  String? get imageUrl => profile.imageUrl;
  DateTime? get birthday => profile.birthday;
  DateTime? get deathday => profile.deathday;
  String get birthplace => profile.birthplace;
}
