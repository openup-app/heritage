import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

Future<Uint8List?> showCropDialog(
    BuildContext context, Uint8List image, Size size) async {
  final transform = await showDialog(
    context: context,
    builder: (context) {
      return _CropDialog(
        image: image,
      );
    },
  );
  if (!context.mounted || transform == null) {
    return null;
  }
  return _cropImage(image, transform);
}

class _CropDialog extends StatefulWidget {
  final Uint8List image;
  const _CropDialog({
    super.key,
    required this.image,
  });

  @override
  State<_CropDialog> createState() => __CropDialogState();
}

class __CropDialogState extends State<_CropDialog> {
  Matrix4 _transform = Matrix4.identity();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crop Photo'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_transform),
          child: const Text('Confirm'),
        ),
      ],
      content: ImageCropper(
        image: widget.image,
        onTransform: (transform) {
          setState(() => _transform = transform);
        },
      ),
    );
  }
}

class ImageCropper extends StatefulWidget {
  final Uint8List image;
  final void Function(Matrix4 transform) onTransform;

  const ImageCropper({
    super.key,
    required this.image,
    required this.onTransform,
  });

  @override
  State<ImageCropper> createState() => _ImageCropperState();
}

class _ImageCropperState extends State<ImageCropper> {
  final _controller = TransformationController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransform);
  }

  void _onTransform() {
    widget.onTransform(_controller.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Vector3 getTopLeftInChildCoordinates(Matrix4 matrix, Vector3 childSize) {
    // Extract the translation (shift) from the matrix
    final translation = matrix.getTranslation();

    // Extract the scale from the matrix (assuming uniform scaling on all axes)
    final scale = matrix.getMaxScaleOnAxis();

    // The translation represents the shift of the content.
    // Since we need to map it back to the child coordinates,
    // we divide by the scale to reverse the zoom effect.
    final topLeftX = -translation.x / scale;
    final topLeftY = -translation.y / scale;

    return Vector3(topLeftX, topLeftY, 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 300,
          height: 400,
          child: AspectRatio(
            aspectRatio: 0.75,
            child: _BorderOverlay(
              child: MouseRegion(
                cursor: SystemMouseCursors.move,
                child: InteractiveViewer(
                  clipBehavior: Clip.none,
                  transformationController: _controller,
                  constrained: false,
                  minScale: 0.1,
                  maxScale: 3.5,
                  child: Image.memory(
                    widget.image,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BorderOverlay extends StatelessWidget {
  final Widget child;
  const _BorderOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    const borderColor = Color.fromRGBO(0xFF, 0xFF, 0xFF, 0.6);
    const borderSize = 48.0;
    return ClipRect(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Padding(
            padding: const EdgeInsets.all(borderSize),
            child: child,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.all(borderSize),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(width: 4, color: Colors.blue),
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: borderSize,
            child: IgnorePointer(
              child: ColoredBox(
                color: borderColor,
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: borderSize,
            child: IgnorePointer(
              child: ColoredBox(
                color: borderColor,
              ),
            ),
          ),
          const Positioned(
            left: 0,
            top: borderSize,
            bottom: borderSize,
            width: borderSize,
            child: IgnorePointer(
              child: ColoredBox(
                color: borderColor,
              ),
            ),
          ),
          const Positioned(
            right: 0,
            top: borderSize,
            bottom: borderSize,
            width: borderSize,
            child: IgnorePointer(
              child: ColoredBox(
                color: borderColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<Uint8List?> _cropImage(Uint8List imageBytes, Matrix4 transform) async {
  final image = await decodeImageFromList(imageBytes);
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.transform(transform.storage);
  canvas.drawImage(image, Offset.zero, Paint());
  final picture = recorder.endRecording();
  final cropped = await picture.toImage(image.width, image.height);
  final byteData = await cropped.toByteData(format: ImageByteFormat.png);
  image.dispose();
  return byteData?.buffer.asUint8List();
}
