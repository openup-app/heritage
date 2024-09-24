import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:heritage/profile_display.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

Future<Uint8List?> showCropDialog(
    BuildContext context, Uint8List image, Size size) async {
  final rect = await showDialog<Rect>(
    context: context,
    builder: (context) {
      return _CropDialog(
        image: image,
        size: size,
      );
    },
  );
  if (!context.mounted || rect == null) {
    return null;
  }
  return _cropImage(image, Offset.zero & size);
}

class _CropDialog extends StatefulWidget {
  final Uint8List image;
  final Size size;

  const _CropDialog({
    super.key,
    required this.image,
    required this.size,
  });

  @override
  State<_CropDialog> createState() => _CropDialogState();
}

class _CropDialogState extends State<_CropDialog> {
  Rect _rect = Rect.zero;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crop Photo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ImageCropper(
            image: widget.image,
            size: widget.size,
            onRect: (rect) {
              setState(() => _rect = rect);
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_rect),
            style: FilledButton.styleFrom(
              fixedSize: const Size.fromHeight(73),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class ImageCropper extends StatefulWidget {
  final Uint8List image;
  final Size size;
  final void Function(Rect rect) onRect;

  const ImageCropper({
    super.key,
    required this.image,
    required this.size,
    required this.onRect,
  });

  @override
  State<ImageCropper> createState() => _ImageCropperState();
}

class _ImageCropperState extends State<ImageCropper> {
  late final TransformationController _controller;

  @override
  void initState() {
    super.initState();
    const outputSize = Size(300, 400);
    final fittedSizes = applyBoxFit(BoxFit.cover, widget.size, outputSize);
    final scale = fittedSizes.destination.height / fittedSizes.source.height;
    final translation = fittedSizes.source.width / widget.size.width;
    final outputRect =
        Alignment.center.inscribe(fittedSizes.source, Offset.zero & outputSize);
    final t = outputRect.topLeft;
    final s = outputSize.height / outputRect.height;
    final matrix = Matrix4.identity()
      ..translate(t.dx, 0.0, 0.0)
      // ..translate(widget.size.width / 2, widget.size.height / 2, 0.0)
      ..scale(s);
    // ..translate(-widget.size.width / 2, -widget.size.height / 2, 0.0);

    _controller = TransformationController(matrix);
    _controller.addListener(_onTransform);
  }

  void _onTransform() {
    final matrix = _controller.value;
    final scale = matrix.getMaxScaleOnAxis();
    final Vector3 tl = -(matrix * Vector3.zero()) / scale;
    final Vector3 br = Vector3.zero();
    final rect = Rect.fromLTWH(tl.x, tl.y, br.x - tl.x, br.y - tl.y);
    widget.onRect(rect);
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
          width: 400,
          child: ImageAspect(
            child: _BorderOverlay(
              child: MouseRegion(
                cursor: SystemMouseCursors.move,
                child: InteractiveViewer(
                  clipBehavior: Clip.none,
                  transformationController: _controller,
                  constrained: false,

                  // alignment: Alignment.center,
                  minScale: 0.1,
                  maxScale: 3.5,
                  child: SizedBox(
                    height: 400,
                    width: 400,
                    child: Image.memory(
                      widget.image,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Row(
            children: [
              const Icon(Icons.zoom_out),
              Expanded(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Slider(
                      min: 0.1,
                      max: 3.5,
                      value:
                          _controller.value.getMaxScaleOnAxis().clamp(0.1, 3.5),
                      onChanged: (scale) {
                        final centerX = widget.size.width / 2;
                        final centerY = widget.size.height / 2;
                        _controller.value = Matrix4.identity()
                          ..translate(centerX, centerY, 0.0)
                          ..scale(scale)
                          ..translate(-centerX, -centerY, 0.0);
                      },
                    );
                  },
                ),
              ),
              const Icon(Icons.zoom_in),
            ],
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

Future<Uint8List?> _cropImage(Uint8List imageBytes, Rect rect) async {
  final image = await decodeImageFromList(imageBytes);
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    image,
    Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
    rect,
    Paint(),
  );
  final picture = recorder.endRecording();
  final cropped = await picture.toImage(image.width, image.height);
  final byteData = await cropped.toByteData(format: ImageByteFormat.png);
  image.dispose();
  return byteData?.buffer.asUint8List();
}
