import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:heritage/util.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

class ZoomablePannableViewport extends StatefulWidget {
  final void Function(Matrix4 transform) onTransformed;
  final VoidCallback? onStartInteraction;
  final Widget child;

  const ZoomablePannableViewport({
    super.key,
    required this.onTransformed,
    this.onStartInteraction,
    required this.child,
  });

  @override
  State<ZoomablePannableViewport> createState() =>
      ZoomablePannableViewportState();
}

class ZoomablePannableViewportState extends State<ZoomablePannableViewport>
    with SingleTickerProviderStateMixin {
  final _interactiveViewerKey = GlobalKey();
  final _transformationController = TransformationController();
  final _childKey = GlobalKey();

  late final _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
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
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final windowSize = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _transformationController,
      builder: (context, child) {
        final scale = _transformationController.value.getMaxScaleOnAxis();
        return InteractiveViewer(
          key: _interactiveViewerKey,
          transformationController: _transformationController,
          constrained: false,
          maxScale: 1,
          minScale: 0.15,
          onInteractionStart: (_) {
            _animationController.stop();
            widget.onStartInteraction?.call();
          },
          boundaryMargin: EdgeInsets.symmetric(
            horizontal: windowSize.width / 2 / scale,
            vertical: windowSize.height / 2 / scale,
          ),
          child: child!,
        );
      },
      child: KeyedSubtree(
        key: _childKey,
        child: RepaintBoundary(
          child: widget.child,
        ),
      ),
    );
  }

  void centerOnWidgetWithKey(
    GlobalKey key, {
    bool animate = true,
    Rect? viewRect,
  }) {
    final targetRect = locateWidgetLocal(key);
    final childRect = locateWidgetLocal(_childKey);
    if (targetRect == null || childRect == null) {
      return;
    }

    final viewport = viewRect ?? Offset.zero & MediaQuery.of(context).size;
    final localOffset = targetRect.shift(-childRect.topLeft);

    const maxScale = 0.5;
    _targetMatrix = Matrix4.identity()
      ..translate(viewport.center.dx, viewport.center.dy)
      ..scale(maxScale)
      ..translate(
        localOffset.left - targetRect.width / 2,
        localOffset.top - targetRect.height / 2,
      );
    _oldMatrix = Matrix4.copy(_transformationController.value);

    if (animate) {
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
    } else {
      setState(() => _animation = AlwaysStoppedAnimation(_targetMatrix));
    }
    _animationController.forward(from: 0);
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
    final interactiveViewerRect = locateWidget(widget.interactiveViewerKey);
    if (interactiveViewerRect == null) {
      return;
    }
    final keysInViewport = widget.childKeys
        .map((e) => (rect: locateWidget(e), key: e))
        .where((e) => e.rect != null)
        .where((e) => e.rect!.overlaps(interactiveViewerRect))
        .map((e) => e.key);
    if (keysInViewport.isNotEmpty) {
      widget.onWithinViewport(keysInViewport.toList());
    }
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
