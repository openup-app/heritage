import 'package:flutter/material.dart';
import 'package:heritage/api.dart';
import 'package:heritage/heritage_app.dart';

class AddConnectionButtons extends StatelessWidget {
  final bool enabled;
  final bool canAddParent;
  final bool canAddChildren;
  final void Function(Relationship relationship) onAddConnectionPressed;

  const AddConnectionButtons({
    super.key,
    required this.enabled,
    required this.canAddParent,
    required this.canAddChildren,
    required this.onAddConnectionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _AddConnectionButton(
          onPressed: !(enabled && canAddParent)
              ? null
              : () => onAddConnectionPressed(Relationship.parent),
          icon: const Icon(Icons.person_add),
          label: const Text('Parent'),
        ),
        _AddConnectionButton(
          onPressed: !enabled
              ? null
              : () => onAddConnectionPressed(Relationship.spouse),
          icon: const Icon(Icons.person_add),
          label: const Text('Spouse'),
        ),
        _AddConnectionButton(
          onPressed: !enabled
              ? null
              : () => onAddConnectionPressed(Relationship.sibling),
          icon: const Icon(Icons.person_add),
          label: const Text('Sibling'),
        ),
        _AddConnectionButton(
          onPressed: !(enabled && canAddChildren)
              ? null
              : () => onAddConnectionPressed(Relationship.child),
          icon: const Icon(Icons.person_add),
          label: const Text('Child'),
        ),
      ],
    );
  }
}

class _AddConnectionButton extends StatelessWidget {
  final Widget icon;
  final Widget label;
  final VoidCallback? onPressed;

  const _AddConnectionButton({
    super.key,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                fixedSize: const Size.square(60),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(13),
                  ),
                ),
                foregroundColor: const Color.fromRGBO(0x00, 0xAE, 0xFF, 1.0),
                backgroundColor: const Color.fromRGBO(0xEB, 0xEB, 0xEB, 1.0),
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

  const NodeProfile({
    super.key,
    required this.person,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(
        color: Colors.black,
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
        children: [
          SizedBox(
            width: 260,
            child: Center(
              child: ImageAspect(
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
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
                      child: ProfileImage(person.profile.imageUrl),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: FilledButton(
                        onPressed: () {},
                        style: FilledButton.styleFrom(
                          fixedSize: const Size.square(64),
                          backgroundColor:
                              const Color.fromRGBO(0x00, 0x00, 0x00, 0.6),
                          shape: const CircleBorder(),
                        ),
                        child: const _Binoculars(),
                      ),
                    ),
                    if (person.ownedBy != null)
                      const Positioned(
                        right: 4,
                        bottom: -32,
                        child: _VerifiedBadge(),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Text(
            person.profile.name,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            person.profile.birthday?.year.toString() ?? '',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
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
  final bool enabled;
  final bool forceHover;
  final VoidCallback onMouseEnter;
  final VoidCallback onMouseExit;
  final VoidCallback onHoverAnimationEnd;
  final Widget child;

  const MouseHoverAnimation({
    super.key,
    this.enabled = true,
    this.forceHover = false,
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
  void didUpdateWidget(covariant MouseHoverAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) {
      if (_isScaling) {
        setState(() => _isScaling = false);
        WidgetsBinding.instance.endOfFrame.then((_) {
          if (mounted) {
            widget.onMouseExit();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaler(
      duration: const Duration(milliseconds: 300),
      shouldScale: _isScaling || widget.forceHover,
      scale: 1.5,
      onEnd: () {
        if (!_isScaling) {
          widget.onHoverAnimationEnd();
        }
      },
      child: MouseRegion(
        opaque: false,
        onEnter: (_) {
          if (widget.enabled) {
            setState(() => _isScaling = true);
            widget.onMouseEnter();
          }
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

class MouseHover extends StatefulWidget {
  final bool enabled;
  final bool forceHover;

  final Widget Function(BuildContext context, bool hovering) builder;

  const MouseHover({
    super.key,
    this.enabled = true,
    this.forceHover = false,
    required this.builder,
  });

  @override
  State<MouseHover> createState() => _MouseHoverState();
}

class _MouseHoverState extends State<MouseHover> {
  bool _hovering = false;
  final _controller = OverlayPortalController();
  final _layerLink = LayerLink();

  @override
  void didUpdateWidget(covariant MouseHover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.forceHover && widget.forceHover) {
      _hovering = true;
      WidgetsBinding.instance.endOfFrame.then((_) {
        if (mounted) {
          _controller.show();
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
          return Align(
            alignment: Alignment.topLeft,
            child: CompositedTransformFollower(
              link: _layerLink,
              child: MouseHoverAnimation(
                enabled: widget.enabled,
                forceHover: widget.forceHover,
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
            if (widget.enabled) {
              setState(() {
                _hovering = true;
                _controller.show();
              });
            }
          },
          onHover: (_) {
            // Edge case where mouse starts inside widget
            if (widget.enabled && !_hovering) {
              setState(() {
                _hovering = true;
                _controller.show();
              });
            }
          },
          child: Visibility(
            visible: !_controller.isShowing,
            maintainSize: true,
            maintainState: true,
            maintainAnimation: true,
            maintainSemantics: true,
            child: IgnorePointer(
              ignoring: _hovering,
              child: widget.builder(context, _hovering),
            ),
          ),
        ),
      ),
    );
  }
}

class _Binoculars extends StatelessWidget {
  const _Binoculars({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/binoculars.png',
      width: 48,
      fit: BoxFit.cover,
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Image.asset(
        'assets/images/badge.webp',
        width: 64,
        fit: BoxFit.cover,
      ),
    );
  }
}

class ImageAspect extends StatelessWidget {
  static const ratio = 102 / 117;

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
