import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heritage/api.dart';
import 'package:heritage/share.dart';
import 'package:url_launcher/url_launcher.dart';

Rect? locateWidget(GlobalKey key) {
  final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null) {
    return null;
  }
  final offset = renderBox.localToGlobal(Offset.zero);
  final size = renderBox.size;
  return offset & size;
}

Rect? locateWidgetLocal(GlobalKey key) {
  final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null) {
    return null;
  }
  final offset = renderBox.globalToLocal(Offset.zero);
  final size = renderBox.size;
  return offset & size;
}

String genderedRelationship(Relationship relationship, Gender gender) {
  switch (relationship) {
    case Relationship.parent:
      return gender == Gender.male ? 'Father' : 'Mother';
    case Relationship.sibling:
      return gender == Gender.male ? 'Brother' : 'Sister';
    case Relationship.spouse:
      return gender == Gender.male ? 'Husband' : 'Wife';
    case Relationship.child:
      return gender == Gender.male ? 'Son' : 'Daughter';
  }
}

Future<ShareType> shareInvite(String name, String id) async {
  final data = ShareData(
    title: '$name\'s family tree invite!',
    text: 'Verify your place on the family tree',
    url: 'https://breakfastsearch.xyz/$id',
  );
  if (!kDebugMode && await canShare(data)) {
    await shareContent(data);
    return ShareType.share;
  } else {
    await Clipboard.setData(ClipboardData(text: data.url!));
    return ShareType.clipboard;
  }
}

enum ShareType { share, clipboard }

void launchEmail() {
  final uri = Uri(
    scheme: 'mailto',
    path: 'tarloksinghfilms@gmail.com',
    queryParameters: {
      'subject': 'Stitchfam',
    },
  );
  launchUrl(uri);
}

Future<void> showShareSuccess({
  required BuildContext context,
  required ShareType type,
}) async {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(switch (type) {
        ShareType.share => 'Link   shared!',
        ShareType.clipboard => 'Link copied to clipboard!',
      }),
    ),
  );
}

Future<T> showBlockingModal<T>(BuildContext context, Future<T> future) async {
  final modalKey = GlobalKey();
  final displayCompleter = Completer<void>();
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return _BlockingModal(
        key: modalKey,
        onDisplayed: () => displayCompleter.complete(),
      );
    },
  );
  await displayCompleter.future;

  try {
    final result = await future;
    final modalContext = modalKey.currentContext;
    if (modalContext != null && modalContext.mounted) {
      Navigator.of(modalContext).pop();
    }
    return result;
  } catch (e) {
    final modalContext = modalKey.currentContext;
    if (modalContext != null && modalContext.mounted) {
      Navigator.of(modalContext).pop();
    }
    return Future.error(e);
  }
}

class _BlockingModal extends StatefulWidget {
  final VoidCallback onDisplayed;
  const _BlockingModal({
    super.key,
    required this.onDisplayed,
  });

  @override
  State<_BlockingModal> createState() => _BlockingModalState();
}

class _BlockingModalState extends State<_BlockingModal> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.endOfFrame.then(
      (_) {
        if (mounted) {
          widget.onDisplayed();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      ),
    );
  }
}
