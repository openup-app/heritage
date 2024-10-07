import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:heritage/api.dart';
import 'package:heritage/profile_display.dart';
import 'package:heritage/util.dart';
import 'package:http/http.dart';

const height = 80.0;

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
              return MouseRegion(
                key: Key('$index'),
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
                                memory: (memory) => Future.value(memory.bytes),
                              );
                              final image =
                                  await showBlockingModal(context, imageFuture);
                              if (image == null || !context.mounted) {
                                return;
                              }
                              final cropped = await showCropperForImage(
                                context,
                                image: image,
                                faceMask: true,
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
              );
            },
          ),
          if (widget.gallery.length < 4)
            _AddImage(
              onPressed: () async {
                final photo = await pickPhotoWithCropper(context);
                if (photo != null && context.mounted) {
                  final newGallery = List.of(widget.gallery);
                  newGallery.add(photo);
                  widget.onChanged(newGallery);
                }
              },
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

class _AddImage extends StatelessWidget {
  final VoidCallback onPressed;

  const _AddImage({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return _Container(
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(),
          backgroundColor: Colors.grey,
        ),
        child: const Center(
          child: Icon(
            Icons.add_photo_alternate,
            color: Colors.white,
          ),
        ),
      ),
    );
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
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: SizedBox(
        height: height,
        child: ImageAspect(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(
                Radius.circular(8),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 12,
                  offset: Offset(0, 4),
                  color: Color.fromRGBO(0x00, 0x00, 0x00, 0.25),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

Future<Uint8List?> _download(String url) async {
  try {
    print('download');
    final response = await get(Uri.parse(url));
    print('response ${response.contentLength}');
    return response.bodyBytes;
  } catch (e) {
    print(e);
    return null;
  }
}
