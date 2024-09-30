import 'package:flutter/cupertino.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:share_plus/share_plus.dart';

part 'share.freezed.dart';

@freezed
class ShareData with _$ShareData {
  const factory ShareData({
    @Default(null) String? title,
    @Default(null) String? text,
    @Default(null) String? url,
  }) = _ShareData;
}

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

class ShareButtonBuilder extends StatefulWidget {
  final ShareData data;
  final Widget Function(BuildContext context, bool canShare) builder;

  const ShareButtonBuilder({
    super.key,
    required this.data,
    required this.builder,
  });

  @override
  State<ShareButtonBuilder> createState() => _ShareButtonBuilderState();
}

class _ShareButtonBuilderState extends State<ShareButtonBuilder> {
  bool _canShare = false;

  @override
  void initState() {
    super.initState();
    _checkShareData(widget.data);
  }

  @override
  void didUpdateWidget(covariant ShareButtonBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _checkShareData(widget.data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _canShare);
  }

  void _checkShareData(ShareData data) async {
    final result = await canShare(data);
    if (mounted) {
      setState(() => _canShare = result);
    }
  }
}
