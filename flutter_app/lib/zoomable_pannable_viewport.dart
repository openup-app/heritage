import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

class ZoomablePannableViewport extends StatefulWidget {
  final List<GlobalKey> childKeys;
  final GlobalKey? selectedKey;
  final void Function(Matrix4 transform) onTransformed;
  final void Function(List<GlobalKey> keys)? onWithinViewport;
  final Widget child;

  const ZoomablePannableViewport({
    super.key,
    required this.childKeys,
    required this.selectedKey,
    required this.onTransformed,
    this.onWithinViewport,
    required this.child,
  });

  @override
  State<ZoomablePannableViewport> createState() =>
      _ZoomablePannableViewportState();
}

class _ZoomablePannableViewportState extends State<ZoomablePannableViewport>
    with SingleTickerProviderStateMixin {
  final _interactiveViewerKey = GlobalKey();
  final _transformationController = TransformationController();
  final _childKey = GlobalKey();

  late final _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  Animation? _animation;

  Matrix4 _oldMatrix = Matrix4.identity();
  Matrix4 _targetMatrix = Matrix4.identity();

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(() {
      widget.onTransformed(_transformationController.value);
    });

    _animationController
        .addListener(() => _transformationController.value = _animation?.value);
  }

  @override
  void didUpdateWidget(covariant ZoomablePannableViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedKey = widget.selectedKey;
    if (oldWidget.selectedKey != selectedKey && selectedKey != null) {
      _centerOnWidgetWithKey(selectedKey);
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
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
      boundaryMargin: const EdgeInsets.all(500),
      child: KeyedSubtree(
        key: _childKey,
        child: widget.child,
      ),
    );
  }

  void _centerOnWidgetWithKey(GlobalKey key) {
    final targetRect = locate(key);
    final childRect = locate(_childKey);
    if (targetRect == null || childRect == null) {
      return;
    }

    final windowSize = MediaQuery.of(context).size;
    final relative = targetRect.shift(-childRect.topLeft);
    _targetMatrix = Matrix4.identity()
      ..translate(
        relative.left + windowSize.width / 2 - targetRect.width / 2,
        relative.top + windowSize.height / 2 - targetRect.height / 2,
      );
    _oldMatrix = Matrix4.copy(_transformationController.value);

    setState(() {
      _animation = Matrix4Tween(
        begin: _oldMatrix,
        end: _targetMatrix,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutCubic,
        ),
      );
    });
    _animationController.forward(from: 0);
  }

  Rect? locate(GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return null;
    }
    final offset = renderBox.globalToLocal(Offset.zero);
    final size = renderBox.size;
    return offset & size;
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
