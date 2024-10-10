import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heritage/api.dart';
import 'package:heritage/date.dart';

final firstDate = DateTime(1500);
final lastDate =
    DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

final profileUpdateProvider =
    StateNotifierProvider<ProfileUpdateNotifier, Profile>(
        (ref) => throw 'Uninitialized provider');

class ProfileUpdateNotifier extends StateNotifier<Profile> {
  final Profile initialProfile;

  ProfileUpdateNotifier({
    required this.initialProfile,
  }) : super(initialProfile);

  void firstName(String value) =>
      state = state.copyWith(firstName: value.trim());

  void lastName(String value) => state = state.copyWith(lastName: value.trim());

  void gender(Gender gender) => state = state.copyWith(gender: gender);

  void photo(Photo value) => state = state.copyWith(photo: value);

  void gallery(List<Photo> value) => state = state.copyWith(gallery: value);

  void birthday(String value) {
    if (value.isEmpty) {
      state = state.copyWith(birthday: null);
    } else {
      final birthday = tryParseSeparatedDate(value);
      if (birthday != null) {
        state = state.copyWith(birthday: _clampDateAndRemoveTime(birthday));
      }
    }
  }

  void birthdayObject(DateTime value) =>
      state = state.copyWith(birthday: value);

  void deathday(String value) {
    if (value.isEmpty) {
      state = state.copyWith(deathday: null);
    } else {
      final deathday = tryParseSeparatedDate(value);
      if (deathday != null) {
        state = state.copyWith(deathday: _clampDateAndRemoveTime(deathday));
      }
    }
  }

  void deathdayObject(DateTime value) =>
      state = state.copyWith(deathday: value);

  void birthplace(String value) =>
      state = state.copyWith(birthplace: value.trim());

  void occupation(String value) =>
      state = state.copyWith(occupation: value.trim());

  void hobbies(String value) => state = state.copyWith(hobbies: value.trim());
}

DateTime _clampDateAndRemoveTime(DateTime date) => date.isBefore(firstDate)
    ? firstDate
    : date.isAfter(lastDate)
        ? lastDate
        : DateTime(date.year, date.month, date.day);
