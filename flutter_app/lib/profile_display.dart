import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:heritage/api.dart';
import 'package:heritage/heritage_app.dart';
import 'package:heritage/util.dart';
import 'package:path_drawing/path_drawing.dart' as path_drawing;

class AddConnectionButtons extends StatelessWidget {
  final bool canAddParent;
  final bool canAddSpouse;
  final bool canAddChildren;
  final double paddingWidth;
  final void Function(Relationship relationship) onAddConnectionPressed;

  const AddConnectionButtons({
    super.key,
    required this.canAddParent,
    required this.canAddSpouse,
    required this.canAddChildren,
    required this.paddingWidth,
    required this.onAddConnectionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _AddConnectionButton(
          onPressed: canAddParent
              ? () => onAddConnectionPressed(Relationship.parent)
              : null,
          paddingWidth: paddingWidth,
          icon: SvgPicture.asset(
            'assets/images/connection_parent.svg',
            width: 24,
          ),
          label: const Text('Parent'),
        ),
        SizedBox(width: paddingWidth * 2),
        _AddConnectionButton(
          onPressed: () => onAddConnectionPressed(Relationship.sibling),
          paddingWidth: paddingWidth,
          icon: SvgPicture.asset(
            'assets/images/connection_sibling.svg',
            width: 32,
          ),
          label: const Text('Sibling'),
        ),
        SizedBox(width: paddingWidth * 2),
        _AddConnectionButton(
          onPressed: canAddChildren
              ? () => onAddConnectionPressed(Relationship.child)
              : null,
          paddingWidth: paddingWidth,
          icon: SvgPicture.asset(
            'assets/images/connection_child.svg',
            width: 32,
          ),
          label: const Text('Child'),
        ),
        SizedBox(width: paddingWidth * 2),
        _AddConnectionButton(
          onPressed: canAddSpouse
              ? () => onAddConnectionPressed(Relationship.spouse)
              : null,
          paddingWidth: paddingWidth,
          icon: SvgPicture.asset(
            'assets/images/connection_spouse.svg',
            width: 32,
          ),
          label: const Text('Spouse'),
        ),
      ],
    );
  }
}

class _AddConnectionButton extends StatelessWidget {
  final double paddingWidth;
  final Widget icon;
  final Widget label;
  final VoidCallback? onPressed;

  const _AddConnectionButton({
    super.key,
    required this.paddingWidth,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Opacity(
          opacity: onPressed == null ? 0.4 : 1.0,
          child: Greyscale(
            enabled: onPressed == null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.square(48),
                    foregroundColor:
                        const Color.fromRGBO(0x00, 0xAE, 0xFF, 1.0),
                    backgroundColor:
                        const Color.fromRGBO(0xEB, 0xEB, 0xEB, 1.0),
                  ),
                  child: icon,
                ),
                const SizedBox(height: 4),
                DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  child: label,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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

class HoverPersonDisplay extends StatefulWidget {
  final Widget child;

  const HoverPersonDisplay({
    super.key,
    required this.child,
  });

  @override
  State<HoverPersonDisplay> createState() => _HoverPersonDisplayState();
}

class _HoverPersonDisplayState extends State<HoverPersonDisplay> {
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
  final Person person;
  final String relatednessDescription;
  final bool showViewPerspective;
  final VoidCallback? onViewPerspectivePressed;

  const NodeProfile({
    super.key,
    required this.person,
    required this.relatednessDescription,
    required this.showViewPerspective,
    required this.onViewPerspectivePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 180,
          child: Stack(
            children: [
              Center(
                child: ImageAspect(
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      _DashedBorder(
                        radius: const Radius.circular(20),
                        child: Container(
                          clipBehavior: Clip.hardEdge,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.all(
                              Radius.circular(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                offset: Offset(0, 10),
                                blurRadius: 44,
                                spreadRadius: -11,
                                color: Color.fromRGBO(0x00, 0x00, 0x00, 0.4),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ProfileImage(person.profile.photo),
                              ),
                              const Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: 72,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(20),
                                      bottomRight: Radius.circular(20),
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Color.fromRGBO(0x00, 0x00, 0x00, 0.40),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      relatednessDescription,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      person.profile.firstName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ProfileImage extends StatelessWidget {
  final Photo photo;

  const ProfileImage(this.photo, {super.key});

  @override
  Widget build(BuildContext context) {
    return switch (photo) {
      NetworkPhoto(:final url) => Image.network(
          url,
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
              layoutBuilder:
                  (topChild, topChildKey, bottomChild, bottomChildKey) {
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
        ),
      MemoryPhoto(:final Uint8List bytes) => Image.memory(
          bytes,
          fit: BoxFit.cover,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _DashedBorder extends StatelessWidget {
  final Radius radius;
  final Widget child;

  const _DashedBorder({
    super.key,
    required this.radius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedPainter(
        radius: radius,
      ),
      child: child,
    );
  }
}

class _DashedPainter extends CustomPainter {
  final Radius radius;

  _DashedPainter({
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // canvas.drawRect(Offset.zero & size, Paint()..color = Colors.orange);

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, radius));
    final dashedPath = path_drawing.dashPath(
      path,
      dashArray: path_drawing.CircularIntervalList<double>([7.0, 12.0]),
    );
    canvas.drawPath(
      dashedPath,
      Paint()
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _DashedPainter oldDelegate) {
    return oldDelegate.radius != radius;
  }
}

class Scaler extends StatefulWidget {
  final Duration duration;
  final bool shouldScale;
  final double scale;
  final VoidCallback onEnd;
  final Widget child;

  const Scaler({
    super.key,
    required this.duration,
    required this.shouldScale,
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
        if (widget.shouldScale) {
          setState(() => _targetScale = widget.scale);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant Scaler oldWidget) {
    if (widget.shouldScale != oldWidget.shouldScale) {
      _targetScale = widget.shouldScale ? widget.scale : 1.0;
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
        if (!widget.shouldScale) {
          widget.onEnd();
        }
      },
      child: widget.child,
    );
  }
}

class MouseOverlay extends StatefulWidget {
  final bool enabled;
  final bool forceOverlay;
  final Widget Function(BuildContext context, bool overlay) builder;

  const MouseOverlay({
    super.key,
    this.enabled = true,
    this.forceOverlay = false,
    required this.builder,
  });

  @override
  State<MouseOverlay> createState() => _MouseOverlayState();
}

class _MouseOverlayState extends State<MouseOverlay> {
  final _controller = OverlayPortalController();
  final _layerLink = LayerLink();
  bool _entered = false;

  @override
  void didUpdateWidget(covariant MouseOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _controller.isShowing) {
      WidgetsBinding.instance.endOfFrame.then((_) {
        if (mounted) {
          setState(() => _controller.hide());
        }
      });
    }
    if (!oldWidget.forceOverlay && widget.forceOverlay) {
      WidgetsBinding.instance.endOfFrame.then((_) {
        if (mounted) {
          setState(() => _controller.show());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _controller,
        overlayChildBuilder: (context) {
          final shouldScale =
              widget.enabled && (_entered || widget.forceOverlay);
          return Align(
            alignment: Alignment.topLeft,
            child: CompositedTransformFollower(
              link: _layerLink,
              child: Scaler(
                duration: const Duration(milliseconds: 300),
                shouldScale: shouldScale,
                scale: 1.5,
                onEnd: () {
                  if (!shouldScale) {
                    setState(() => _controller.hide());
                  }
                },
                child: _MouseRegionWithWorkaround(
                  enabled: widget.enabled,
                  onEnter: () => setState(() => _entered = true),
                  onExit: () => setState(() => _entered = false),
                  child: widget.builder(context, _controller.isShowing),
                ),
              ),
            ),
          );
        },
        child: _MouseRegionWithWorkaround(
          enabled: widget.enabled,
          onEnter: () {
            setState(() {
              _entered = true;
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
              ignoring: _controller.isShowing,
              child: widget.builder(context, _controller.isShowing),
            ),
          ),
        ),
      ),
    );
  }
}

/// MouseRegion that handles the edge case where cursor starts inside widget.
/// Additionally ignores touch events causing mouse enter/exit events.
class _MouseRegionWithWorkaround extends StatefulWidget {
  final bool enabled;
  final VoidCallback? onEnter;
  final VoidCallback? onExit;
  final Widget child;

  const _MouseRegionWithWorkaround({
    super.key,
    required this.enabled,
    this.onEnter,
    this.onExit,
    required this.child,
  });

  @override
  State<_MouseRegionWithWorkaround> createState() =>
      _MouseRegionWithWorkaroundState();
}

class _MouseRegionWithWorkaroundState
    extends State<_MouseRegionWithWorkaround> {
  bool _entered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      opaque: false,
      onEnter: (p) {
        if (widget.enabled && !_entered && p.kind == PointerDeviceKind.mouse) {
          setState(() => _entered = true);
          widget.onEnter?.call();
        }
      },
      onHover: (p) {
        if (widget.enabled && !_entered && p.kind == PointerDeviceKind.mouse) {
          setState(() => _entered = true);
          widget.onEnter?.call();
        }
      },
      onExit: (p) {
        if (widget.enabled && _entered && p.kind == PointerDeviceKind.mouse) {
          setState(() => _entered = false);
          widget.onExit?.call();
        }
      },
      child: widget.child,
    );
  }
}

class Binoculars extends StatelessWidget {
  final double size;

  const Binoculars({
    super.key,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/binoculars.png',
      width: size,
      fit: BoxFit.cover,
    );
  }
}

class VerifiedBadge extends StatelessWidget {
  final double width;

  const VerifiedBadge({
    super.key,
    this.width = 80,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.9,
        child: SvgPicture.asset(
          'assets/images/badge.svg',
          width: width,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class ImageAspect extends StatelessWidget {
  static const ratio = 151 / 173;

  final Widget child;

  const ImageAspect({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: ratio,
      child: child,
    );
  }
}
