import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:heritage/profile_display.dart';
import 'package:heritage/util.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

Future<Uint8List?> showCropDialog(
    BuildContext context, Uint8List image, Size imageSize) async {
  final rect = await showDialog<Rect>(
    context: context,
    builder: (context) {
      return _CropDialog(
        image: image,
        size: imageSize,
      );
    },
  );
  if (!context.mounted || rect == null) {
    return null;
  }
  return _cropImage(image, rect);
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
          Flexible(
            child: ImageCropper(
              image: widget.image,
              imageSize: widget.size,
              onRect: (rect) => setState(() => _rect = rect),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_rect),
            style: FilledButton.styleFrom(
              fixedSize: const Size.fromHeight(50),
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
  final Size imageSize;
  final void Function(Rect rect) onRect;

  const ImageCropper({
    super.key,
    required this.image,
    required this.imageSize,
    required this.onRect,
  });

  @override
  State<ImageCropper> createState() => _ImageCropperState();
}

class _ImageCropperState extends State<ImageCropper> {
  final _controller = TransformationController();
  final _interactiveViewerKey = GlobalKey();

  Size _windowSize = Size.zero;
  bool _hasSize = false;
  Size _viewportSize = Size.zero;
  Size _contentSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransform);
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) {
        _setInitialSizesAndTransform();
        _hasSize = true;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final windowSize = MediaQuery.of(context).size;
    if (windowSize != _windowSize && _hasSize) {
      WidgetsBinding.instance.endOfFrame.then((_) {
        _windowSize = windowSize;
        // Reset crop
        _setInitialSizesAndTransform();
      });
    }
  }

  void _setInitialSizesAndTransform() {
    final viewportSize = locateWidget(_interactiveViewerKey)?.size ?? Size.zero;

    // Content covering viewport (usually larger than FittedSizes.destination)
    final imageAspectRatio = widget.imageSize.width / widget.imageSize.height;
    final viewportAspectRatio = viewportSize.width / viewportSize.height;
    final double scale;
    if (imageAspectRatio > viewportAspectRatio) {
      scale = viewportSize.height / widget.imageSize.height;
    } else {
      scale = viewportSize.width / widget.imageSize.width;
    }
    final contentSize = widget.imageSize * scale;
    final viewportRect =
        Alignment.center.inscribe(contentSize, Offset.zero & viewportSize);
    final transform = Matrix4.identity()
      ..translate(viewportRect.left, viewportRect.top, 0.0);

    _viewportSize = viewportSize;
    _contentSize = contentSize;
    _controller.value = transform;
  }

  void _onTransform() {
    final matrix = _controller.value;
    final rect =
        getCropRect(matrix, _contentSize, widget.imageSize, _viewportSize);
    widget.onRect(rect);
  }

  void _onSliderScale(double scale) {
    // Relative zoom
    final matrix = _controller.value.clone();
    final scaleFactor = scale / matrix.getMaxScaleOnAxis();
    final scalePivot = _viewportSize / 2;
    final newMatrix = Matrix4.identity()
      ..translate(scalePivot.width, scalePivot.height)
      ..scale(scaleFactor)
      ..translate(-scalePivot.width, -scalePivot.height)
      ..multiply(matrix);

    // Stops going out of bounds when zooming out
    final scaledContent = _contentSize * scale;
    final t = newMatrix.getTranslation();
    double tx = t.x;
    double ty = t.y;
    tx = tx.clamp(_viewportSize.width - scaledContent.width, 0);
    ty = ty.clamp(_viewportSize.height - scaledContent.height, 0);
    newMatrix.setTranslationRaw(tx, ty, 0.0);

    _controller.value = newMatrix;
  }

  Rect getCropRect(Matrix4 matrix, Size scaledImageSize, Size originalImageSize,
      Size viewportSize) {
    final m = Matrix4.inverted(matrix);
    final topLeft = m.transform3(Vector3.zero());
    final bottomRight =
        m.transform3(Vector3(viewportSize.width, viewportSize.height, 0));

    final scale = originalImageSize.width / scaledImageSize.width;
    return Rect.fromLTRB(
      topLeft.x * scale,
      topLeft.y * scale,
      bottomRight.x * scale,
      bottomRight.y * scale,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _hasSize ? 1.0 : 0.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
              child: ImageAspect(
                child: _BorderOverlay(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.move,
                    child: InteractiveViewer(
                      key: _interactiveViewerKey,
                      clipBehavior: Clip.none,
                      transformationController: _controller,
                      constrained: false,
                      minScale: 1,
                      maxScale: 3.5,
                      child: SizedBox(
                        width: _contentSize.width,
                        height: _contentSize.height,
                        child: Image.memory(
                          widget.image,
                          fit: BoxFit.cover,
                        ),
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
                        min: 1,
                        max: 3.5,
                        value:
                            _controller.value.getMaxScaleOnAxis().clamp(1, 3.5),
                        onChanged: _onSliderScale,
                      );
                    },
                  ),
                ),
                const Icon(Icons.zoom_in),
              ],
            ),
          ),
        ],
      ),
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
    const borderColor = Color.fromRGBO(0xFF, 0xFF, 0xFF, 0.5);
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
    rect,
    Offset.zero & rect.size,
    Paint(),
  );
  final picture = recorder.endRecording();
  final cropped =
      await picture.toImage(rect.size.width.toInt(), rect.size.height.toInt());
  final byteData = await cropped.toByteData(format: ImageByteFormat.png);
  image.dispose();
  return byteData?.buffer.asUint8List();
}
