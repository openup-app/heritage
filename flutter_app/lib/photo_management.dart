import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:heritage/api.dart';
import 'package:heritage/file_picker.dart';
import 'package:heritage/image_croper.dart';
import 'package:heritage/profile_display.dart';

const height = 80.0;

class PhotoManagement extends StatelessWidget {
  final UnmodifiableListView<Photo> gallery;
  final void Function(List<Photo> gallery) onChanged;

  PhotoManagement({
    super.key,
    required List<Photo> gallery,
    required this.onChanged,
  }) : gallery = UnmodifiableListView(gallery);

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
            itemCount: gallery.length,
            buildDefaultDragHandles: false,
            proxyDecorator: (child, index, animation) {
              return Material(
                type: MaterialType.transparency,
                child: child,
              );
            },
            onReorder: (oldIndex, newIndex) {
              final newGallery = List.of(gallery);
              final item = newGallery.removeAt(oldIndex);
              newGallery.insert(
                  oldIndex < newIndex ? newIndex - 1 : newIndex, item);
              onChanged(newGallery);
            },
            itemBuilder: (context, index) {
              final photo = gallery[index];
              final child = _Thumbnail(
                photo: photo,
                onReplace: () async {
                  final photo = await _pickPhoto(context);
                  if (photo != null && context.mounted) {
                    final newGallery = List.of(gallery);
                    newGallery.replaceRange(index, index + 1, [photo]);
                    onChanged(newGallery);
                  }
                },
                onDelete: () {
                  final newGallery = List.of(gallery);
                  newGallery.removeAt(index);
                  onChanged(newGallery);
                },
              );
              return MouseRegion(
                key: Key('$index'),
                cursor: SystemMouseCursors.move,
                child: ReorderableDragStartListener(
                  index: index,
                  child: child,
                ),
              );
            },
          ),
          if (gallery.length < 4)
            _AddImage(
              onPressed: () async {
                final photo = await _pickPhoto(context);
                if (photo != null && context.mounted) {
                  final newGallery = List.of(gallery);
                  newGallery.add(photo);
                  onChanged(newGallery);
                }
              },
            ),
        ],
      ),
    );
  }

  Future<Photo?> _pickPhoto(BuildContext context) async {
    final image = await _pickImage(context: context);
    if (image == null) {
      return null;
    }
    return MemoryPhoto(key: '${Random().nextInt(1000000000)}', bytes: image);
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
  final VoidCallback onReplace;
  final VoidCallback onDelete;

  const _Thumbnail({
    super.key,
    required this.photo,
    required this.onReplace,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _Container(
      child: Stack(
        children: [
          Positioned.fill(
            child: FilledButton(
              onPressed: onReplace,
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
          ),
          Positioned(
            top: 4,
            right: 4,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.square(30),
                shape: const CircleBorder(),
              ),
              onPressed: () async {
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
                  onDelete();
                }
              },
              child: const Icon(
                Icons.close,
                color: Colors.black,
                size: 16,
              ),
            ),
          ),
        ],
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

Future<Uint8List?> _pickImage({
  required BuildContext context,
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
  return await showCropDialog(context, frame, size);
}
