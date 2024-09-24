import 'dart:async';

import 'package:flutter/material.dart';
import 'package:heritage/api.dart';
import 'package:url_launcher/url_launcher.dart';

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

void launchEmail() {
  final uri = Uri.parse('mailto:tarloksinghfilms@gmail.com?subject=');
  launchUrl(uri);
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
