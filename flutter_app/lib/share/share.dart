import 'package:flutter/cupertino.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:heritage/share/share_stub.dart';

export 'share_stub.dart'
    if (dart.library.io) 'share_io.dart'
    if (dart.library.js_interop) 'share_web.dart' show canShare, shareContent;

part 'share.freezed.dart';

@freezed
class ShareData with _$ShareData {
  const factory ShareData({
    @Default(null) String? title,
    @Default(null) String? text,
    @Default(null) String? url,
  }) = _ShareData;
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
