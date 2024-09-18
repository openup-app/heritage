import 'package:flutter/widgets.dart';

class ZoomablePannableViewport extends StatefulWidget {
  final void Function(Matrix4 transform) onTransformed;
  final Widget child;

  const ZoomablePannableViewport({
    super.key,
    required this.onTransformed,
    required this.child,
  });

  @override
  State<ZoomablePannableViewport> createState() =>
      _ZoomablePannableViewportState();
}

class _ZoomablePannableViewportState extends State<ZoomablePannableViewport> {
  final _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(() {
      widget.onTransformed(_transformationController.value);
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _transformationController,
      constrained: false,
      maxScale: 4,
      minScale: 0.1,
      // boundaryMargin: const EdgeInsets.all(500),
      child: widget.child,
    );
  }
}
