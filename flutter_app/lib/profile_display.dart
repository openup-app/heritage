import 'dart:math';

import 'package:flutter/material.dart';
import 'package:heritage/api.dart';
import 'package:heritage/graph.dart';
import 'package:heritage/heritage_app.dart';

class ProfileControls extends StatelessWidget {
  final bool show;
  final bool canAddParent;
  final void Function(Relationship relationship) onAddConnectionPressed;
  final Widget child;

  const ProfileControls({
    super.key,
    required this.show,
    required this.canAddParent,
    required this.onAddConnectionPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProfileControlAnimateIn(
          show: show,
          enabled: canAddParent,
          onPressed: !canAddParent
              ? null
              : () => onAddConnectionPressed(Relationship.parent),
          builder: (context) {
            return FilledButton.icon(
              onPressed: !canAddParent
                  ? null
                  : () => onAddConnectionPressed(Relationship.parent),
              icon: const Icon(Icons.person_add),
              label: const Text('Parent'),
            );
          },
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileControlAnimateIn(
              show: show,
              onPressed: () => onAddConnectionPressed(Relationship.spouse),
              builder: (context) {
                return FilledButton.icon(
                  onPressed: () => onAddConnectionPressed(Relationship.spouse),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Spouse'),
                );
              },
            ),
            child,
            ProfileControlAnimateIn(
              show: show,
              onPressed: () => onAddConnectionPressed(Relationship.sibling),
              builder: (context) {
                return FilledButton.icon(
                  onPressed: () => onAddConnectionPressed(Relationship.sibling),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Sibling'),
                );
              },
            ),
          ],
        ),
        ProfileControlAnimateIn(
          show: show,
          onPressed: () => onAddConnectionPressed(Relationship.child),
          builder: (context) {
            return FilledButton.icon(
              onPressed: () => onAddConnectionPressed(Relationship.child),
              icon: const Icon(Icons.person_add),
              label: const Text('Child'),
            );
          },
        ),
      ],
    );
  }
}

class ProfileControlAnimateIn extends StatefulWidget {
  final bool show;
  final bool enabled;
  final VoidCallback? onPressed;
  final WidgetBuilder builder;

  const ProfileControlAnimateIn({
    super.key,
    required this.show,
    this.enabled = true,
    required this.onPressed,
    required this.builder,
  });

  @override
  State<ProfileControlAnimateIn> createState() =>
      _ProfileControlAnimateInState();
}

class _ProfileControlAnimateInState extends State<ProfileControlAnimateIn> {
  var _crossFadeState = CrossFadeState.showFirst;

  @override
  void initState() {
    super.initState();
    if (widget.show) {
      _showAfterDelay();
    }
  }

  @override
  void didUpdateWidget(covariant ProfileControlAnimateIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.show != widget.show) {
      if (widget.show) {
        _showAfterDelay();
      } else {
        setState(() => _crossFadeState = CrossFadeState.showFirst);
      }
    }
  }

  void _showAfterDelay() {
    Future.delayed(const Duration(milliseconds: 500)).then((_) {
      if (mounted) {
        if (widget.show) {
          setState(() => _crossFadeState = CrossFadeState.showSecond);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: widget.show ? 1.0 : 0.0,
      child: SizedBox(
        width: 120,
        height: 60,
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          alignment: Alignment.center,
          crossFadeState: _crossFadeState,
          layoutBuilder: (topChild, topChildKey, bottomChild, bottomChildKey) {
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  key: bottomChildKey,
                  child: bottomChild,
                ),
                Positioned.fill(
                  key: topChildKey,
                  child: topChild,
                ),
              ],
            );
          },
          firstChild: MouseRegion(
            cursor:
                widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
            child: GestureDetector(
              onTap: widget.onPressed,
              child: ProfileControlDot(
                enabled: widget.enabled,
              ),
            ),
          ),
          secondChild: Center(
            child: widget.builder(context),
          ),
        ),
      ),
    );
  }
}

class ProfileControlDot extends StatelessWidget {
  final bool enabled;
  const ProfileControlDot({
    super.key,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? primaryColor : Colors.grey,
          boxShadow: const [
            BoxShadow(
              blurRadius: 11,
              offset: Offset(0, 4),
              color: Color.fromRGBO(0x00, 0x00, 0x00, 0.15),
            ),
          ],
        ),
      ),
    );
  }
}

class HoverNodeDisplay extends StatefulWidget {
  final Widget child;

  const HoverNodeDisplay({
    super.key,
    required this.child,
  });

  @override
  State<HoverNodeDisplay> createState() => _HoverNodeDisplayState();
}

class _HoverNodeDisplayState extends State<HoverNodeDisplay> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Transform.scale(
        scale: _hover ? 1.5 : 1.0,
        child: IgnorePointer(
          child: widget.child,
        ),
      ),
    );
  }
}

class NodeProfile extends StatelessWidget {
  final Node node;

  const NodeProfile({
    super.key,
    required this.node,
  });

  @override
  Widget build(BuildContext context) {
    final random = Random(node.id.hashCode);
    return Container(
      width: 313,
      height: 347,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(
          Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 22),
            blurRadius: 44,
            spreadRadius: -11,
            color: Color.fromRGBO(0x00, 0x00, 0x00, 0.33),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ProfileImage(
          //   'https://d2xzkuyodufiic.cloudfront.net/avatars/${random.nextInt(70)}.jpg',
          // ),
          ProfileImage(
            'https://picsum.photos/${200 + random.nextInt(30)}',
          ),
          Positioned(
            left: 21,
            bottom: 21,
            right: 21,
            child: DefaultTextStyle(
              style: const TextStyle(
                shadows: [
                  Shadow(
                    offset: Offset(0, 5),
                    blurRadius: 4.8,
                    color: Color.fromRGBO(0x00, 0x00, 0x00, 0.25),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    node.id,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    node.profile.name,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileImage extends StatelessWidget {
  final String src;

  const ProfileImage(this.src, {super.key});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      src,
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          return child;
        }
        return AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: frame == null
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          layoutBuilder: (topChild, topChildKey, bottomChild, bottomChildKey) {
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  key: bottomChildKey,
                  child: bottomChild,
                ),
                Positioned.fill(
                  key: topChildKey,
                  child: topChild,
                ),
              ],
            );
          },
          firstChild: const ColoredBox(
            color: Colors.grey,
          ),
          secondChild: child,
        );
      },
    );
  }
}

class MouseHoverAnimation extends StatefulWidget {
  final VoidCallback onMouseEnter;
  final VoidCallback onMouseExit;
  final VoidCallback onHoverAnimationEnd;
  final Widget child;

  const MouseHoverAnimation({
    super.key,
    required this.onMouseEnter,
    required this.onMouseExit,
    required this.onHoverAnimationEnd,
    required this.child,
  });

  @override
  State<MouseHoverAnimation> createState() => _MouseHoverAnimationState();
}

class _MouseHoverAnimationState extends State<MouseHoverAnimation> {
  bool _isScaling = false;

  @override
  Widget build(BuildContext context) {
    return Scaler(
      duration: const Duration(milliseconds: 300),
      isScaling: _isScaling,
      scale: 1.5,
      onEnd: () {
        if (!_isScaling) {
          widget.onHoverAnimationEnd();
        }
      },
      child: MouseRegion(
        opaque: false,
        onEnter: (_) {
          setState(() => _isScaling = true);
          widget.onMouseEnter();
        },
        onExit: (_) {
          setState(() => _isScaling = false);
          widget.onMouseExit();
        },
        child: widget.child,
      ),
    );
  }
}

class Scaler extends StatefulWidget {
  final Duration duration;
  final bool isScaling;
  final double scale;
  final VoidCallback onEnd;
  final Widget child;

  const Scaler({
    super.key,
    required this.duration,
    required this.isScaling,
    required this.scale,
    required this.onEnd,
    required this.child,
  });

  @override
  State<Scaler> createState() => _HoverState();
}

class _HoverState extends State<Scaler> {
  var _targetScale = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) {
        if (widget.isScaling) {
          setState(() => _targetScale = widget.scale);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant Scaler oldWidget) {
    if (widget.isScaling != oldWidget.isScaling) {
      _targetScale = widget.isScaling ? widget.scale : 1.0;
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: widget.duration,
      curve: Curves.easeOutQuart,
      scale: _targetScale,
      onEnd: () {
        if (!widget.isScaling) {
          widget.onEnd();
        }
      },
      child: widget.child,
    );
  }
}

class MouseHover extends StatefulWidget {
  final ValueNotifier<Matrix4> transformNotifier;
  final Widget Function(BuildContext context, bool hovering) builder;

  const MouseHover({
    super.key,
    required this.transformNotifier,
    required this.builder,
  });

  @override
  State<MouseHover> createState() => _MouseHoverState();
}

class _MouseHoverState extends State<MouseHover> {
  bool _hovering = false;
  final _controller = OverlayPortalController();
  final _childKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _controller,
      overlayChildBuilder: (context) {
        return Align(
          alignment: Alignment.topLeft,
          child: ValueListenableBuilder(
            valueListenable: widget.transformNotifier,
            builder: (context, value, child) {
              final scale = value[0];
              final renderBox =
                  _childKey.currentContext?.findRenderObject() as RenderBox?;
              final pos = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
              final matrix = Matrix4.identity()
                ..translate(pos.dx, pos.dy, 0.0)
                ..scale(scale);
              return Transform(
                transform: matrix,
                child: child,
              );
            },
            child: MouseHoverAnimation(
              onMouseEnter: () => setState(() => _hovering = true),
              onMouseExit: () => setState(() => _hovering = false),
              onHoverAnimationEnd: () => setState(() => _controller.hide()),
              child: widget.builder(context, _hovering),
            ),
          ),
        );
      },
      child: MouseRegion(
        opaque: false,
        onEnter: (_) {
          setState(() {
            _hovering = true;
            _controller.show();
          });
        },
        child: Visibility(
          visible: !_controller.isShowing,
          maintainSize: true,
          maintainState: true,
          maintainAnimation: true,
          maintainSemantics: true,
          child: IgnorePointer(
            ignoring: _hovering,
            child: KeyedSubtree(
              key: _childKey,
              child: widget.builder(context, _hovering),
            ),
          ),
        ),
      ),
    );
  }
}
