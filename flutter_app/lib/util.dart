import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heritage/api.dart';
import 'package:heritage/file_picker.dart';
import 'package:heritage/image_croper.dart';
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

Future<Photo?> pickPhotoWithCropper(
  BuildContext context, {
  bool faceMask = false,
}) async {
  final image = await _pickImageWithCropper(
    context: context,
    faceMask: faceMask,
  );
  if (image == null) {
    return null;
  }
  return MemoryPhoto(key: '${Random().nextInt(1000000000)}', bytes: image);
}

Future<Photo?> showCropperForImage(
  BuildContext context, {
  required Uint8List image,
  bool faceMask = false,
}) async {
  final (frame, size) = await getFirstFrameAndSize(image);
  if (!context.mounted || frame == null) {
    return null;
  }
  final cropped =
      await showCropDialog(context, frame, size, faceMask: faceMask);
  return MemoryPhoto(key: '${Random().nextInt(1000000000)}', bytes: cropped);
}

Future<Uint8List?> _pickImageWithCropper({
  required BuildContext context,
  required bool faceMask,
}) async {
  final file = await pickPhoto(source: PhotoSource.gallery);
  final image = await file?.readAsBytes();
  if (!context.mounted || image == null) {
    return null;
  }
  final (frame, size) = await getFirstFrameAndSize(image);
  if (!context.mounted || frame == null) {
    return null;
  }
  return await showCropDialog(context, frame, size, faceMask: faceMask);
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
    url: 'https://stitchfam.com/$id',
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

Future<void> showProfileUpdateSuccess({required BuildContext context}) async {
  final textStyle = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (context) => Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 112),
        child: DefaultTextStyle(
          style: textStyle,
          child: _AnimatedSuccessPopup(
            onDone: overlayEntry.remove,
          ),
        ),
      ),
    ),
  );

  overlay.insert(overlayEntry);
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

bool canViewPerspective({
  required Id id,
  required Id primaryUserId,
  required Id focalPersonId,
  required bool isSibling,
  required bool isOwned,
}) =>
    id != primaryUserId && id != focalPersonId && !isSibling && isOwned;

bool canDeletePerson(Person person) {
  if (person.ownedBy != null) {
    return false;
  }
  if (person.children.isNotEmpty) {
    return false;
  }

  final hasParents = person.parents.isNotEmpty;
  final hasSpouses = person.spouses.isNotEmpty;
  return !(hasParents && hasSpouses);
}

class _AnimatedSuccessPopup extends StatefulWidget {
  final VoidCallback onDone;

  const _AnimatedSuccessPopup({
    super.key,
    required this.onDone,
  });

  @override
  State<_AnimatedSuccessPopup> createState() => _AnimatedSuccessPopupState();
}

class _AnimatedSuccessPopupState extends State<_AnimatedSuccessPopup>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this)
    ..duration = const Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future.delayed(const Duration(seconds: 1)).then((_) {
      _controller.reverse().then((_) {
        widget.onDone();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: const _SuccessPopup(),
    );
  }
}

class _SuccessPopup extends StatelessWidget {
  const _SuccessPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(
          Radius.circular(10),
        ),
        color: Color.fromRGBO(0x07, 0xCA, 0x35, 1.0),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 5),
            blurRadius: 15,
            color: Color.fromRGBO(0x00, 0x00, 0x00, 0.3),
          ),
        ],
      ),
      child: SizedBox(
        width: 150,
        height: 32,
        child: Center(
          child: Text(
            'Profile Saved',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
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

class Greyscale extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const Greyscale({
    super.key,
    this.enabled = true,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    // Copied from Lomski's answer: https://stackoverflow.com/a/62078847/1702627
    const ColorFilter greyscale = ColorFilter.matrix(<double>[
      0.2126, 0.7152, 0.0722, 0, 0, //
      0.2126, 0.7152, 0.0722, 0, 0, //
      0.2126, 0.7152, 0.0722, 0, 0, //
      0, 0, 0, 1, 0, //
    ]);

    return ColorFiltered(
      colorFilter: greyscale,
      child: child,
    );
  }
}

const cdn = 'https://d2xzkuyodufiic.cloudfront.net';
