import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:heritage/api.dart';
import 'package:heritage/profile_display.dart';
import 'package:heritage/util.dart';
import 'package:http/http.dart';
import 'package:path_drawing/path_drawing.dart' as path_drawing;

const height = 71.0;
const _greyColor = Color.fromRGBO(0xB7, 0xB7, 0xB7, 1.0);

class PhotoManagement extends StatefulWidget {
  final UnmodifiableListView<Photo> gallery;
  final void Function(List<Photo> gallery) onChanged;
  final void Function(Photo photo) onProfilePhotoChanged;

  PhotoManagement({
    super.key,
    required List<Photo> gallery,
    required this.onChanged,
    required this.onProfilePhotoChanged,
  }) : gallery = UnmodifiableListView(gallery);

  @override
  State<PhotoManagement> createState() => _PhotoManagementState();
}

class _PhotoManagementState extends State<PhotoManagement> {
  final _keys = <GlobalKey>[];

  @override
  void initState() {
    super.initState();
    _updateKeys();
  }

  @override
  void didUpdateWidget(covariant PhotoManagement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gallery.length != widget.gallery.length) {
      _updateKeys();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: widget.gallery.length,
            buildDefaultDragHandles: false,
            proxyDecorator: (child, index, animation) {
              return Material(
                type: MaterialType.transparency,
                child: child,
              );
            },
            onReorder: (oldIndex, newIndex) {
              final newGallery = List.of(widget.gallery);
              final item = newGallery.removeAt(oldIndex);
              newGallery.insert(
                  oldIndex < newIndex ? newIndex - 1 : newIndex, item);
              widget.onChanged(newGallery);
            },
            itemBuilder: (context, index) {
              final photo = widget.gallery[index];
              final key = _keys[index];
              return Padding(
                key: Key('$index'),
                padding: const EdgeInsets.only(right: 12.0),
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: ReorderableDragStartListener(
                    index: index,
                    child: _Thumbnail(
                      key: key,
                      photo: photo,
                      onTap: () async {
                        final rect = locateWidget(key) ?? Rect.zero;
                        showMenu(
                          context: context,
                          popUpAnimationStyle: AnimationStyle.noAnimation,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(12),
                            ),
                          ),
                          position: RelativeRect.fromLTRB(
                            rect.left,
                            rect.top,
                            rect.right,
                            rect.bottom,
                          ).shift(const Offset(10, height)),
                          items: [
                            PopupMenuItem(
                              onTap: () async {
                                final imageFuture = photo.map(
                                  network: (network) => _download(network.url),
                                  memory: (memory) =>
                                      Future.value(memory.bytes),
                                );
                                final image = await showBlockingModal(
                                    context, imageFuture);
                                if (image == null || !context.mounted) {
                                  return;
                                }
                                final cropped = await showCropperForImage(
                                  context,
                                  image: image,
                                );
                                if (cropped == null || !context.mounted) {
                                  return;
                                }
                                widget.onProfilePhotoChanged(cropped);
                              },
                              child: const Text('Use as profile photo'),
                            ),
                            PopupMenuItem(
                              onTap: () async {
                                final delete = await showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('Delete photo?'),
                                      actions: [
                                        TextButton(
                                          onPressed: Navigator.of(context).pop,
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.black,
                                          ),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                                if (delete == true && context.mounted) {
                                  final newGallery = List.of(widget.gallery);
                                  newGallery.removeAt(index);
                                  widget.onChanged(newGallery);
                                }
                              },
                              child: const Text('Delete'),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          if (widget.gallery.length < 4)
            _AddImageButton(
              onPressed: () async {
                final photo = await pickPhotoWithCropper(context);
                if (photo != null && context.mounted) {
                  final newGallery = List.of(widget.gallery);
                  newGallery.add(photo);
                  widget.onChanged(newGallery);
                }
              },
              child: SvgPicture.asset(
                'assets/images/add_photo.svg',
                colorFilter: const ColorFilter.mode(
                  Color.fromRGBO(0xB7, 0xB7, 0xB7, 1.0),
                  BlendMode.srcIn,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _updateKeys() {
    setState(() => _keys
      ..clear()
      ..addAll(List.generate(widget.gallery.length, (_) => GlobalKey())));
  }
}

class _AddImageButton extends StatelessWidget {
  final bool withDashes;
  final VoidCallback onPressed;
  final Widget child;

  const _AddImageButton({
    super.key,
    this.withDashes = true,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _Container(
      child: _DashedBorder(
        enabled: withDashes,
        color: _greyColor,
        radius: const Radius.circular(12),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            shape: const RoundedRectangleBorder(),
            backgroundColor: Colors.transparent,
          ),
          child: Center(
            child: child,
          ),
        ),
      ),
    );
  }
}

class AddProfilePhotoButton extends StatefulWidget {
  final Photo photo;
  final void Function(Photo photo) onPhoto;
  final VoidCallback onDelete;

  const AddProfilePhotoButton({
    super.key,
    required this.photo,
    required this.onPhoto,
    required this.onDelete,
  });

  @override
  State<AddProfilePhotoButton> createState() => _AddProfilePhotoButtonState();
}

class _AddProfilePhotoButtonState extends State<AddProfilePhotoButton> {
  final _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _hasPhoto();
    return _AddImageButton(
      key: _key,
      withDashes: !hasPhoto,
      onPressed: _onPressed,
      child: Builder(
        builder: (context) {
          if (!hasPhoto) {
            return const Icon(
              Icons.person_add,
              color: _greyColor,
              size: 30,
            );
          }
          return switch (widget.photo) {
            NetworkPhoto(:final url) => Image.network(
                url,
                fit: BoxFit.cover,
              ),
            MemoryPhoto(:final Uint8List bytes) => Image.memory(
                bytes,
                fit: BoxFit.cover,
              ),
            _ => const SizedBox.shrink(),
          };
        },
      ),
    );
  }

  void _onPressed() {
    final hasPhoto = _hasPhoto();
    if (!hasPhoto) {
      _pickPhoto();
      return;
    }
    final rect = locateWidget(_key) ?? Rect.zero;
    showMenu(
      context: context,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(12),
        ),
      ),
      position: RelativeRect.fromLTRB(
        rect.left,
        rect.top,
        rect.right,
        rect.bottom,
      ).shift(const Offset(10, height)),
      items: [
        PopupMenuItem(
          onTap: _pickPhoto,
          child: const Text('Replace photo'),
        ),
        PopupMenuItem(
          onTap: () async {
            final delete = await showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text('Delete photo?'),
                  actions: [
                    TextButton(
                      onPressed: Navigator.of(context).pop,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                );
              },
            );
            if (delete == true && context.mounted) {
              widget.onDelete();
            }
          },
          child: const Text('Delete'),
        ),
      ],
    );
  }

  bool _hasPhoto() {
    return widget.photo.map(
      network: (network) {
        if (network.key == 'public/no_image.png') {
          return false;
        }
        return true;
      },
      memory: (_) => true,
    );
  }

  void _pickPhoto() async {
    final photo = await pickPhotoWithCropper(context);
    if (context.mounted && photo != null) {
      widget.onPhoto(photo);
    }
  }
}

class _Thumbnail extends StatelessWidget {
  final Photo photo;
  final VoidCallback onTap;

  const _Thumbnail({
    super.key,
    required this.photo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Container(
      child: FittedBox(
        fit: BoxFit.cover,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(12),
              ),
            ),
          ),
          child: switch (photo) {
            NetworkPhoto(:final url) => Image.network(
                url,
                fit: BoxFit.cover,
              ),
            MemoryPhoto(:final Uint8List bytes) => Image.memory(
                bytes,
                fit: BoxFit.cover,
              ),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }
}

class _Container extends StatelessWidget {
  final Widget child;

  const _Container({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ImageAspect(
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(
              Radius.circular(12),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DashedBorder extends StatelessWidget {
  final bool enabled;
  final Color color;
  final Radius radius;
  final Widget child;

  const _DashedBorder({
    super.key,
    this.enabled = true,
    required this.color,
    required this.radius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    return CustomPaint(
      foregroundPainter: _DashedPainter(
        color: color,
        radius: radius,
      ),
      child: child,
    );
  }
}

class _DashedPainter extends CustomPainter {
  final Color color;
  final Radius radius;

  _DashedPainter({
    required this.color,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, radius));
    final dashedPath = path_drawing.dashPath(
      path,
      dashArray: path_drawing.CircularIntervalList<double>([4.0, 6.0]),
    );
    canvas.drawPath(
      dashedPath,
      Paint()
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _DashedPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

Future<Uint8List?> _download(String url) async {
  try {
    final response = await get(Uri.parse(url));
    return response.bodyBytes;
  } catch (e) {
    return null;
  }
}
