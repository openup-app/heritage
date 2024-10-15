import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heritage/api.dart';
import 'package:heritage/file_picker.dart';
import 'package:heritage/graph.dart';
import 'package:heritage/image_croper.dart';
import 'package:heritage/share/share.dart';
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

Future<Photo?> pickPhotoWithCropper(BuildContext context) async {
  final image = await _pickImageWithCropper(context: context);
  if (image == null) {
    return null;
  }
  return MemoryPhoto(key: '${Random().nextInt(1000000000)}', bytes: image);
}

Future<Photo?> showCropperForImage(BuildContext context,
    {required Uint8List image}) async {
  final (frame, size) = await getFirstFrameAndSize(image);
  if (!context.mounted || frame == null) {
    return null;
  }
  final cropped = await showCropDialog(context, frame, size);
  return MemoryPhoto(key: '${Random().nextInt(1000000000)}', bytes: cropped);
}

Future<Uint8List?> _pickImageWithCropper({
  required BuildContext context,
}) async {
  final file = await pickFile('Pick a photo');
  final image = await file?.readAsBytes();
  if (!context.mounted || image == null) {
    return null;
  }
  final (frame, size) = await getFirstFrameAndSize(image);
  if (!context.mounted || frame == null) {
    return null;
  }
  return await showCropDialog(context, frame, size);
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

Future<ShareType> shareInvite({
  required String targetId,
  required String targetName,
  required String focalName,
  required String referrerId,
}) async {
  final data = ShareData(
    text:
        '$targetName has been invited by $focalName!\nJoin your family tree now!\n',
    url: 'https://stitchfam.com/invite/$targetId:$referrerId',
  );

  await shareContent(data);
  return ShareType.share;
}

Future<ShareType> shareLoginLink({
  required String targetId,
  required String targetName,
}) async {
  final data = ShareData(
    text:
        '$targetName\'s login link for Stitchfam.\nOnly share it with $targetName',
    url: 'https://stitchfam.com/login/$targetId',
  );

  await shareContent(data);
  return ShareType.share;
}

enum ShareType { share, clipboard }

void launchEmail() {
  final uri = Uri(
    scheme: 'mailto',
    path: 'support@stitchfam.com',
    queryParameters: {
      'subject': 'Stitchfam',
    },
  );
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

String _genderedParent(Gender? gender) => gender == null
    ? 'parent'
    : gender == Gender.male
        ? 'father'
        : 'mother';

String _genderedSibling(Gender? gender) => gender == null
    ? 'sibling'
    : gender == Gender.male
        ? 'brother'
        : 'sister';

String _genderedSpouse(Gender? gender) => gender == null
    ? 'spouse'
    : gender == Gender.male
        ? 'husband'
        : 'wife';

String _genderedChild(Gender? gender) => gender == null
    ? 'child'
    : gender == Gender.male
        ? 'son'
        : 'daughter';

String _genderedParentSibling(Gender? gender) => gender == null
    ? 'uncle/aunt'
    : gender == Gender.male
        ? 'uncle'
        : 'aunt';

String _genderedSiblingsChild(Gender? gender) => gender == null
    ? 'neice/nephew'
    : gender == Gender.male
        ? 'nephew'
        : 'neiece';

String _genderedGrandparent(Gender? gender) => gender == null
    ? 'grandparent'
    : gender == Gender.male
        ? 'grandfather'
        : 'grandmother';

String _genderedGrandchild(Gender? gender) => gender == null
    ? 'grandchild'
    : gender == Gender.male
        ? 'grandson'
        : 'granddaughter';

enum PointOfView { first, second, third }

String relatednessDescription(
  LinkedNode<Person> focal,
  LinkedNode<Person> target, {
  required PointOfView pov,
  bool capitalizeWords = false,
}) {
  final description = _relatednessDescriptionImpl(focal, target, pov);
  if (!capitalizeWords) {
    return description;
  }

  final buffer = StringBuffer();
  bool newWord = true;
  for (var i = 0; i < description.length; i++) {
    buffer.write(newWord ? (description[i].toUpperCase()) : description[i]);
    newWord = description[i] == ' ' || description[i] == '/';
  }
  return buffer.toString();
}

String _relatednessDescriptionImpl(
  LinkedNode<Person> focal,
  LinkedNode<Person> target,
  PointOfView pov,
) {
  if (focal.id == target.id) {
    return switch (pov) {
      PointOfView.first || PointOfView.second => 'me',
      PointOfView.third => focal.data.profile.firstName,
    };
  } else if (!target.isBloodRelative) {
    final genderedSpouse = _genderedSpouse(target.data.profile.gender);
    if (target.id == focal.spouse?.id) {
      return switch (pov) {
        PointOfView.first => 'my $genderedSpouse',
        PointOfView.second => 'their $genderedSpouse',
        PointOfView.third => genderedSpouse,
      };
    } else {
      return switch (pov) {
        PointOfView.first => genderedSpouse,
        PointOfView.second => 'their $genderedSpouse',
        PointOfView.third => genderedSpouse,
      };
    }
  }

  final isSibling = target.isSibling;
  final relativeLevel = target.relativeLevel;
  final isBloodRelative = target.isBloodRelative;
  final isAncestor = target.isAncestor;

  final targetGenderedRelationship =
      _genderedSibling(target.data.profile.gender);

  if (isSibling) {
    return switch (pov) {
      PointOfView.first => targetGenderedRelationship,
      PointOfView.second => 'their $targetGenderedRelationship',
      PointOfView.third => targetGenderedRelationship,
    };
  } else if (relativeLevel == 0) {
    if (isBloodRelative) {
      return switch (pov) {
        PointOfView.first => 'cousin',
        PointOfView.second => 'their cousin',
        PointOfView.third => 'cousin',
      };
    } else {
      // Spouse of sibling or cousin
      return _genderedSpouse(target.data.profile.gender);
    }
  }

  if (relativeLevel <= 0) {
    final parts = switch (pov) {
      PointOfView.first => isBloodRelative ? [] : [],
      PointOfView.second => ['their'],
      PointOfView.third => [],
    };
    if (relativeLevel == -1) {
      if (isAncestor) {
        parts.add(_genderedParent(target.data.profile.gender));
      } else {
        if (isBloodRelative) {
          parts.add(_genderedParentSibling(target.data.profile.gender));
        } else {
          parts.add(_genderedSpouse(target.data.profile.gender));
        }
      }
    } else if (relativeLevel == -2) {
      if (isAncestor) {
        parts.add(_genderedGrandparent(target.data.profile.gender));
      } else {
        final ancestorAtLevel = target.ancestorOnLevel;
        final lineageString =
            _genderedGrandparent(ancestorAtLevel?.data.profile.gender);
        if (isBloodRelative) {
          parts.add(
              '$lineageString\'s ${_genderedSibling(target.data.profile.gender)}');
        } else {
          parts.add(_genderedSpouse(target.data.profile.gender));
        }
      }
    } else {
      final greatCount = relativeLevel.abs() - 2;
      final greatString = List.generate(greatCount, (_) => 'great').join(' ');
      final ancestorAtLevel = target.ancestorOnLevel;
      final lineageString =
          '$greatString ${_genderedGrandparent(ancestorAtLevel?.data.profile.gender)}';
      if (isAncestor) {
        parts.add(lineageString);
      } else {
        if (isBloodRelative) {
          parts.add(
              '$lineageString\'s ${_genderedSibling(target.data.profile.gender)}');
        } else {
          parts.add(_genderedSpouse(target.data.profile.gender));
        }
      }
    }
    return parts.join(' ');
  } else {
    var rootNode = target;
    if (!target.isBloodRelative) {
      final spouse = target.spouses.firstWhereOrNull((e) => e.isBloodRelative);
      if (spouse == null) {
        return switch (pov) {
          PointOfView.first => 'relative',
          PointOfView.second => 'their relative',
          PointOfView.third => 'relative',
        };
      }
      rootNode = spouse;
    }
    while (rootNode.relativeLevel > 0) {
      final parent = rootNode.parents.firstOrNull;
      if (parent == null) {
        return switch (pov) {
          PointOfView.first => 'relative',
          PointOfView.second => 'their relative',
          PointOfView.third => 'relative',
        };
      }
      rootNode = parent;
    }

    // Prefer root node being focal node
    if (rootNode.spouse?.id == focal.id) {
      rootNode = focal;
    }

    final isRootFocal = rootNode.id == focal.id;
    final isRootSibling = rootNode.isSibling;
    final isRootCousin = !(isRootFocal || isRootSibling);
    final rootName = isRootFocal
        ? ''
        : isRootSibling
            ? _genderedSibling(rootNode.data.profile.gender)
            : 'cousin';

    final parts = <String>[];
    if (target.relativeLevel == 1) {
      if (isBloodRelative) {
        if (isRootFocal) {
          switch (pov) {
            case PointOfView.first:
              break;
            case PointOfView.second:
              parts.add('their');
            case PointOfView.third:
              break;
          }
          parts.add(_genderedChild(target.data.profile.gender));
        } else {
          // Siblings children
          switch (pov) {
            case PointOfView.first:
              break;
            case PointOfView.second:
              parts.add('their');
            case PointOfView.third:
              break;
          }
          parts.add(_genderedSiblingsChild(target.data.profile.gender));
        }
      } else {
        parts.add(_genderedSpouse(target.data.profile.gender));
      }
    } else if (target.relativeLevel == 2) {
      String part = '';
      if (rootNode.id == focal.id) {
        part = switch (pov) {
          PointOfView.first => '',
          PointOfView.second => 'their',
          PointOfView.third => '',
        };
      } else {
        part = switch (pov) {
          PointOfView.first => '$rootName\'s',
          PointOfView.second => 'their $rootName\'s',
          PointOfView.third => '',
        };
      }
      if (part.isNotEmpty) {
        parts.add(part);
      }
      if (isBloodRelative) {
        parts.add(_genderedGrandchild(target.data.profile.gender));
      } else {
        parts.add(_genderedSpouse(target.data.profile.gender));
      }
    } else {
      final greatCount = relativeLevel - 2;
      final greatString = List.generate(greatCount, (_) => 'great').join(' ');
      final lineageString = greatString;
      if (isBloodRelative) {
        parts.add(
            '$lineageString ${_genderedGrandchild(target.data.profile.gender)}');
      } else {
        parts.add(_genderedSpouse(target.data.profile.gender));
      }
    }
    return parts.join(' ');
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
