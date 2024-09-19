import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

class ZoomablePannableViewport extends StatefulWidget {
  final List<GlobalKey> childKeys;
  final void Function(Matrix4 transform) onTransformed;
  final void Function(List<GlobalKey> keys) onWithinViewport;
  final Widget child;

  const ZoomablePannableViewport({
    super.key,
    required this.childKeys,
    required this.onTransformed,
    required this.onWithinViewport,
    required this.child,
  });

  @override
  State<ZoomablePannableViewport> createState() =>
      _ZoomablePannableViewportState();
}

class _ZoomablePannableViewportState extends State<ZoomablePannableViewport> {
  final _interactiveViewerKey = GlobalKey();
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
      key: _interactiveViewerKey,
      transformationController: _transformationController,
      constrained: false,
      maxScale: 4,
      minScale: 0.1,
      // boundaryMargin: const EdgeInsets.all(500),
      child: _ViewportWatcher(
        controller: _transformationController,
        interactiveViewerKey: _interactiveViewerKey,
        childKeys: widget.childKeys,
        onWithinViewport: widget.onWithinViewport,
        child: widget.child,
      ),
    );
  }
}

class _ViewportWatcher extends StatefulWidget {
  final TransformationController controller;
  final GlobalKey interactiveViewerKey;
  final List<GlobalKey> childKeys;
  final void Function(List<GlobalKey> keys) onWithinViewport;
  final Widget child;

  const _ViewportWatcher({
    super.key,
    required this.controller,
    required this.interactiveViewerKey,
    required this.childKeys,
    required this.onWithinViewport,
    required this.child,
  });

  @override
  State<_ViewportWatcher> createState() => _ViewportWatcherState();
}

class _ViewportWatcherState extends State<_ViewportWatcher> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTransformed);
  }

  void _onTransformed() {
    final interactiveViewerRect = _getWidgetRect(widget.interactiveViewerKey);
    if (interactiveViewerRect == null) {
      return;
    }
    final keysInViewport = widget.childKeys
        .map((e) => (rect: _getWidgetRect(e), key: e))
        .where((e) => e.rect != null)
        .where((e) => e.rect!.overlaps(interactiveViewerRect))
        .map((e) => e.key);
    if (keysInViewport.isNotEmpty) {
      widget.onWithinViewport(keysInViewport.toList());
    }
  }

  Rect? _getWidgetRect(GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    final position = renderBox?.localToGlobal(Offset.zero);
    final size = renderBox?.size;
    if (position != null && size != null) {
      return position & size;
    }
    return null;
  }

  Rect _transform(Matrix4 m, Rect rect) {
    final topLeft = Vector3(rect.left, rect.top, 0);
    final bottomRight = Vector3(rect.right, rect.bottom, 0);
    final Vector3 topLeftTransformed = m * topLeft;
    final Vector3 bottomRightTransformed = m * bottomRight;
    final width = bottomRightTransformed.x - topLeftTransformed.x;
    final height = bottomRightTransformed.y - topLeftTransformed.y;
    return Rect.fromLTWH(
      topLeftTransformed.x,
      topLeftTransformed.y,
      width,
      height,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
