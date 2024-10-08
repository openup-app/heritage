import 'dart:ui';

import 'package:heritage/share/share.dart';
import 'package:share_plus/share_plus.dart';

Future<bool> canShare(ShareData data) => Future.value(true);

Future<void> shareContent(ShareData data) async {
  final text = data.url ?? data.text;
  if (text == null) {
    return Future.error('Sharing requires url or text');
  }
  await Share.share(
    text,
    subject: data.title,
    sharePositionOrigin: Rect.zero,
  );
}
