import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formats text as a date by adding in slashes in and limiting the length
class DateTextFormatter extends TextInputFormatter {
  static const _kMaxLength = 8;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = _format(newValue.text, '/');
    return newValue.copyWith(
      text: text,
      selection: TextSelection.fromPosition(TextPosition(offset: text.length)),
    );
  }

  String _format(String value, String separator) {
    final nonDigits = RegExp(r'[^0-9]+');
    value = value.replaceAll(nonDigits, '');
    var formatted = '';

    final datePattern = getFormattedDatePattern();
    final length = min(value.length, _kMaxLength);
    for (int i = 0; i < length; i++) {
      formatted += value[i];

      final isAtSeparatorIndex = switch (datePattern) {
        DatePattern.ddmmyyyy || DatePattern.mmddyyyy => i == 1 || i == 3,
        DatePattern.yyyymmdd => i == 3 || i == 5,
      };
      final isAtEnd = i >= value.length - 1;
      if (isAtSeparatorIndex && !isAtEnd) {
        formatted += separator;
      }
    }

    return formatted;
  }
}

DateTime? tryParseSeparatedDate(String text) {
  final pattern = getFormattedDatePattern();
  final numbers = text.split('/').map(int.tryParse).whereNotNull().toList();
  if (numbers.length != 3) {
    return null;
  }
  return switch (pattern) {
    DatePattern.ddmmyyyy => DateTime(numbers[2], numbers[1], numbers[0]),
    DatePattern.mmddyyyy => DateTime(numbers[2], numbers[0], numbers[1]),
    DatePattern.yyyymmdd => DateTime(numbers[0], numbers[1], numbers[2]),
  };
}

String formatDate(DateTime date) {
  final dateFormat = DateFormat.yMd();
  return dateFormat.format(date);
}

DatePattern getFormattedDatePattern() {
  final dateFormat = DateFormat.yMd().pattern;
  if (dateFormat == 'd/M/y') {
    return DatePattern.ddmmyyyy;
  } else if (dateFormat == 'y/M/d') {
    return DatePattern.yyyymmdd;
  } else {
    return DatePattern.mmddyyyy;
  }
}

enum DatePattern {
  ddmmyyyy('DD/MM/YYYY'),
  yyyymmdd('YYYY/MM/DD'),
  mmddyyyy('MM/DD/YYYY');

  const DatePattern(this.formatted);

  final String formatted;
}
