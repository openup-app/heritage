import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:heritage/api.dart';
import 'package:heritage/graph_provider.dart';
import 'package:heritage/graph_view.dart';
import 'package:heritage/help.dart';
import 'package:heritage/heritage_app.dart';
import 'package:heritage/layout.dart';
import 'package:heritage/profile_display.dart';
import 'package:heritage/util.dart';

const _kMinPanelHeight = 310.0;
const _kAwaitingColor = Color.fromRGBO(0xFF, 0x39, 0x39, 1.0);

typedef AddConnectionButtonsBuilder = Widget Function(
    BuildContext context, double paddingWidth);

class Panels extends ConsumerStatefulWidget {
  final Person? selectedPerson;
  final Relatedness? relatedness;
  final bool isPerspectiveMode;
  final bool isPrimaryPersonSelected;
  final bool isFocalPersonSelected;
  final bool maybeShowDateOfPassing;
  final String focalPersonFullName;
  final PanelPopupState panelPopupState;
  final VoidCallback? onShareInvite;
  final VoidCallback? onEdit;
  final VoidCallback? onViewPerspective;
  final VoidCallback? onLeavePerspective;
  final void Function(Rect rect) onViewRectUpdated;
  final VoidCallback onRecenter;
  final void Function(Profile profile) onSaveProfile;
  final VoidCallback? onDeletePerson;
  final VoidCallback onInformPanelDismissed;
  final VoidCallback? onReselect;
  final AddConnectionButtonsBuilder? addConnectionButtonsBuilder;

  const Panels({
    super.key,
    required this.selectedPerson,
    required this.relatedness,
    required this.isPerspectiveMode,
    required this.isPrimaryPersonSelected,
    required this.isFocalPersonSelected,
    required this.maybeShowDateOfPassing,
    required this.focalPersonFullName,
    required this.panelPopupState,
    required this.onShareInvite,
    required this.onEdit,
    required this.onViewPerspective,
    required this.onLeavePerspective,
    required this.onViewRectUpdated,
    required this.onRecenter,
    required this.onSaveProfile,
    required this.onDeletePerson,
    required this.onInformPanelDismissed,
    required this.onReselect,
    required this.addConnectionButtonsBuilder,
  });

  @override
  ConsumerState<Panels> createState() => _PanelsState();
}

class _PanelsState extends ConsumerState<Panels> {
  bool _hadInitialLayout = false;
  late LayoutType _layout;
  final _modalKey = GlobalKey();
  PersistentBottomSheetController? _bottomSheetController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hadInitialLayout) {
      _hadInitialLayout = true;
      _layout = Layout.of(context);
      _onChangeLayout();
    } else {
      final oldLayout = _layout;
      _layout = Layout.of(context);
      if (oldLayout != _layout) {
        _onChangeLayout();
        _onChangePopupState();
      }
    }
    _onEmitSize();
  }

  @override
  void didUpdateWidget(covariant Panels oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.panelPopupState != widget.panelPopupState) {
      _onChangePopupState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final small = _layout == LayoutType.small;
    return Stack(
      children: [
        if (small) ...[
          Align(
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LogoText(width: 250),
                if (widget.isPerspectiveMode)
                  _PerspectiveTitle(
                    fullName: widget.focalPersonFullName,
                  ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: _MenuButtons(
              onRecenterPressed: widget.onRecenter,
            ),
          ),
          if (widget.onLeavePerspective != null)
            Positioned(
              left: 16,
              bottom: 16,
              child: _LeavePerspectiveButton(
                onPressed: widget.onLeavePerspective,
              ),
            ),
        ] else ...[
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 7,
            width: 250,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LogoText(),
                  if (widget.isPerspectiveMode)
                    _PerspectiveTitle(
                      fullName: widget.focalPersonFullName,
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: 24,
            child: _MenuButtons(
              onRecenterPressed: widget.onRecenter,
            ),
          ),
          if (widget.onLeavePerspective != null)
            Positioned(
              left: 24,
              bottom: 24,
              child: _LeavePerspectiveButton(
                onPressed: widget.onLeavePerspective,
              ),
            ),
          Positioned(
            top: 128,
            left: 24,
            width: 390,
            bottom: 144,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 660),
                child: AnimatedSlideIn(
                  duration: const Duration(milliseconds: 300),
                  beginOffset: const Offset(-1, 0),
                  alignment: Alignment.centerLeft,
                  child: switch (widget.panelPopupState) {
                    PanelPopupStateNone() => null,
                    PanelPopupStateProfile(:final person, :final relatedness) =>
                      _SidePanelContainer(
                        key: Key('profile_${person.id}'),
                        child: Builder(builder: (context) {
                          final addConnectionButtonsBuilder =
                              widget.addConnectionButtonsBuilder;
                          if (addConnectionButtonsBuilder == null) {
                            return const SizedBox.shrink();
                          }
                          return _ProfileSheet(
                            person: person,
                            relatedness: relatedness,
                            isFocalPersonSelected: widget.isFocalPersonSelected,
                            isPrimaryPersonSelected:
                                widget.isPrimaryPersonSelected,
                            addConnectionButtonsBuilder:
                                addConnectionButtonsBuilder,
                            onEdit: widget.onEdit,
                            onInvite: widget.onShareInvite,
                            onViewPerspective: widget.onViewPerspective,
                            onDelete: widget.onDeletePerson,
                            onReselect: widget.onReselect,
                          );
                        }),
                      ),
                  },
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _onChangeLayout() {
    switch (_layout) {
      case LayoutType.small:
      // Ignored
      case LayoutType.large:
        // Dismiss any modals
        final context = _modalKey.currentContext;
        if (context != null) {
          Navigator.of(context).pop();
        }
        WidgetsBinding.instance.endOfFrame.then((_) {
          _bottomSheetController?.close();
        });
    }
  }

  void _onEmitSize() {
    switch (_layout) {
      case LayoutType.small:
        WidgetsBinding.instance.endOfFrame.then((_) {
          final context = this.context;
          if (context.mounted) {
            final windowSize = MediaQuery.of(context).size;
            const logoTextOffset = 16.0;
            widget.onViewRectUpdated(const Offset(0, logoTextOffset) &
                Size(windowSize.width, windowSize.height - _kMinPanelHeight));
          }
        });
      case LayoutType.large:
        WidgetsBinding.instance.endOfFrame.then((_) {
          final context = this.context;
          if (context.mounted) {
            final windowSize = MediaQuery.of(context).size;
            widget.onViewRectUpdated(Offset.zero & windowSize);
          }
        });
    }
  }

  void _onChangePopupState() {
    switch (_layout) {
      case LayoutType.small:
        switch (widget.panelPopupState) {
          case PanelPopupStateNone():
            // Ignore
            WidgetsBinding.instance.endOfFrame.then((_) {
              if (mounted) {
                _bottomSheetController?.close();
              }
            });
            break;
          case PanelPopupStateProfile(:final person, :final relatedness):
            WidgetsBinding.instance.endOfFrame.then((_) {
              if (mounted) {
                final controller = Scaffold.of(context).showBottomSheet(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  backgroundColor: const Color.fromRGBO(0xEC, 0xEC, 0xEC, 1.0),
                  (context) {
                    final addConnectionButtonsBuilder =
                        widget.addConnectionButtonsBuilder;
                    if (addConnectionButtonsBuilder == null) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: _DragHandle(),
                        ),
                        _ProfileSheet(
                          person: person,
                          relatedness: relatedness,
                          isFocalPersonSelected: widget.isFocalPersonSelected,
                          isPrimaryPersonSelected:
                              widget.isPrimaryPersonSelected,
                          addConnectionButtonsBuilder:
                              addConnectionButtonsBuilder,
                          onEdit: widget.onEdit,
                          onInvite: widget.onShareInvite,
                          onViewPerspective: widget.onViewPerspective,
                          onDelete: widget.onDeletePerson,
                          onReselect: widget.onReselect,
                        ),
                      ],
                    );
                  },
                );
                setState(() => _bottomSheetController = controller);
                controller.closed.then((_) {
                  if (mounted) {
                    if (Layout.of(context) == LayoutType.small) {
                      widget.onInformPanelDismissed();
                    }
                  }
                });
              }
            });
            break;
        }
      case LayoutType.large:
        // Displayed in build() by side panel
        WidgetsBinding.instance.endOfFrame.then((_) {
          if (mounted) {
            final windowSize = MediaQuery.of(context).size;
            widget.onViewRectUpdated(Offset.zero & windowSize);
          }
        });
    }
  }
}

Future<T?> showModalBottomSheetWithDragHandle<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    barrierColor: Colors.transparent,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(10),
        topRight: Radius.circular(10),
      ),
    ),
    builder: (context) {
      return Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: builder(context),
          ),
        ),
      );
    },
  );
}

class _DismissWhenNoPersonSelected extends StatefulWidget {
  final Person? selectedPerson;
  final Relatedness? relatedness;
  final Widget Function(BuildContext context, Key childKey,
      Person selectedPerson, Relatedness relatedness) builder;

  const _DismissWhenNoPersonSelected({
    super.key,
    required this.selectedPerson,
    required this.relatedness,
    required this.builder,
  });

  @override
  State<_DismissWhenNoPersonSelected> createState() =>
      _DismissWhenNoPersonSelectedState();
}

class _DismissWhenNoPersonSelectedState
    extends State<_DismissWhenNoPersonSelected>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  Person? _selectedPerson;
  Relatedness? _relatedness;
  late Key _childKey;

  @override
  void initState() {
    super.initState();
    _selectedPerson = widget.selectedPerson;
    _relatedness = widget.relatedness;
    _childKey = UniqueKey();
  }

  @override
  void didUpdateWidget(covariant _DismissWhenNoPersonSelected oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPerson != widget.selectedPerson ||
        oldWidget.relatedness != widget.relatedness) {
      final shouldShow = widget.selectedPerson != null &&
          widget.relatedness != null &&
          widget.selectedPerson?.isAwaiting == false;
      _selectedPerson = widget.selectedPerson ?? _selectedPerson;
      _relatedness = widget.relatedness ?? _relatedness;
      if (!shouldShow) {
        _controller.reverse();
      } else {
        _childKey = UniqueKey();
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedPerson = _selectedPerson;
    final relatedness = _relatedness;
    return SlideTransition(
      position: Tween(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOut,
        ),
      ),
      child: FadeTransition(
        opacity: _controller,
        child: Builder(
          builder: (context) {
            if (selectedPerson == null || relatedness == null) {
              return const SizedBox.shrink();
            }
            return widget.builder(
                context, _childKey, selectedPerson, relatedness);
          },
        ),
      ),
    );
  }
}

class _ProfileSheet extends StatefulWidget {
  final Person person;
  final Relatedness relatedness;
  final bool isFocalPersonSelected;
  final bool isPrimaryPersonSelected;
  final AddConnectionButtonsBuilder addConnectionButtonsBuilder;
  final VoidCallback? onEdit;
  final VoidCallback? onInvite;
  final VoidCallback? onViewPerspective;
  final VoidCallback? onDelete;
  final VoidCallback? onReselect;

  const _ProfileSheet({
    super.key,
    required this.person,
    required this.relatedness,
    required this.isFocalPersonSelected,
    required this.isPrimaryPersonSelected,
    required this.addConnectionButtonsBuilder,
    required this.onEdit,
    required this.onInvite,
    required this.onViewPerspective,
    required this.onDelete,
    required this.onReselect,
  });

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  @override
  Widget build(BuildContext context) {
    final ownershipUnableReason = widget.person.ownershipUnableReason;
    return Container(
      height: _kMinPanelHeight,
      clipBehavior: Clip.none,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: Stack(
        children: [
          Column(
            key: Key(widget.person.id),
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                clipBehavior: Clip.none,
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Spacer(),
                    if (widget.onDelete != null)
                      FilledButton(
                        onPressed: () async {
                          final delete = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text(
                                    'Delete ${widget.person.profile.fullName} from the tree?'),
                                actions: [
                                  TextButton(
                                    onPressed: Navigator.of(context).pop,
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: _kAwaitingColor,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                          if (mounted && delete == true) {
                            widget.onDelete?.call();
                          }
                        },
                        style: FilledButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size.square(40),
                          foregroundColor: _kAwaitingColor,
                          backgroundColor: Colors.white,
                        ),
                        child: const Icon(
                          Icons.delete_rounded,
                          size: 20,
                        ),
                      )
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  children: [
                    if (widget.onEdit != null)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: FilledButton.icon(
                            onPressed: widget.onEdit,
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(24),
                                ),
                              ),
                              minimumSize: const Size.square(48),
                              foregroundColor: widget.person.isAwaiting
                                  ? _kAwaitingColor
                                  : primaryColor,
                              backgroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit'),
                          ),
                        ),
                      ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 64.0),
                        child: ProfileNameSection(
                          person: widget.person,
                          relatedness: widget.relatedness,
                          isPrimaryPersonSelected:
                              widget.isPrimaryPersonSelected,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 128,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(
                    Radius.circular(10),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            widget.isPrimaryPersonSelected
                                ? 'Add my...'
                                : 'Add ${widget.person.profile.firstName}\'s...',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color.fromRGBO(0x88, 0x88, 0x88, 1.0),
                            ),
                          ),
                          const SizedBox(height: 8),
                          widget.addConnectionButtonsBuilder.call(context, 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FilledButton(
                  onPressed: widget.person.isAwaiting
                      ? widget.onInvite
                      : widget.isFocalPersonSelected
                          ? null
                          : widget.onViewPerspective,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size.fromHeight(64),
                    foregroundColor: Colors.white,
                    backgroundColor: widget.person.isAwaiting
                        ? _kAwaitingColor
                        : primaryColor,
                  ),
                  child: widget.person.isAwaiting
                      ? Text('Invite ${widget.person.profile.firstName}')
                      : Text('View ${widget.person.profile.firstName}\'s Tree'),
                ),
              ),
            ],
          ),
          if (widget.person.isAwaiting)
            Positioned(
              left: 0,
              top: 0,
              child: Transform.scale(
                scale: 0.7,
                child: const AwaitingInvite(),
              ),
            )
          else if (ownershipUnableReason != null)
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Consumer(
                  builder: (context, ref, child) {
                    return _OwnershipUnableReasonDisplay(
                      reason: ownershipUnableReason,
                      onPressed: widget.onEdit == null
                          ? null
                          : () async {
                              final remove = await showDialog<bool>(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text('Remove label?'),
                                    actions: [
                                      TextButton(
                                        onPressed: Navigator.of(context).pop,
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.black,
                                        ),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text(
                                          'Remove',
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                              if (context.mounted && remove == true) {
                                final notifier =
                                    ref.read(graphProvider.notifier);
                                final ownableFuture =
                                    notifier.updateOwnershipUnableReason(
                                        widget.person.id, null);
                                await showBlockingModal(context, ownableFuture);
                                if (context.mounted) {
                                  widget.onReselect?.call();
                                }
                              }
                            },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: const BoxDecoration(
        color: Colors.grey,
        borderRadius: BorderRadius.all(
          Radius.circular(2),
        ),
      ),
    );
  }
}

class _LeavePerspectiveButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _LeavePerspectiveButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _bottomButtonDecoration,
      child: FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size.square(48),
          foregroundColor: Colors.black,
          backgroundColor: Colors.white,
        ),
        onPressed: onPressed,
        child: const RotatedBox(
          quarterTurns: 2,
          child: Icon(Icons.logout),
        ),
      ),
    );
  }
}

class _MenuButtons extends StatelessWidget {
  final VoidCallback onRecenterPressed;

  const _MenuButtons({
    super.key,
    required this.onRecenterPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: _bottomButtonDecoration,
          child: FilledButton(
            onPressed: onRecenterPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size.square(48),
              foregroundColor: Colors.black,
              backgroundColor: Colors.white,
            ),
            child: const Icon(
              CupertinoIcons.location_fill,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 16),
        DecoratedBox(
          decoration: _bottomButtonDecoration,
          child: FilledButton(
            onPressed: () => showHelpDialog(context: context),
            style: FilledButton.styleFrom(
              minimumSize: const Size.square(48),
              foregroundColor: Colors.black,
              backgroundColor: Colors.white,
            ),
            child: const Icon(
              Icons.question_mark,
            ),
          ),
        ),
      ],
    );
  }
}

BoxDecoration get _bottomButtonDecoration => const BoxDecoration(
      borderRadius: BorderRadius.all(
        Radius.circular(13),
      ),
      boxShadow: [
        BoxShadow(
          offset: Offset(0, 1),
          blurRadius: 10,
          color: Color.fromRGBO(0x00, 0x00, 0x00, 0.2),
        ),
      ],
    );

class AnimatedSlideIn extends StatefulWidget {
  final Duration duration;
  final Offset beginOffset;
  final Alignment alignment;
  final Widget? child;

  const AnimatedSlideIn({
    super.key,
    required this.duration,
    required this.beginOffset,
    this.alignment = Alignment.center,
    required this.child,
  });

  @override
  State<AnimatedSlideIn> createState() => _AnimatedSlideInState();
}

class _AnimatedSlideInState extends State<AnimatedSlideIn> {
  Widget? _child;

  @override
  void initState() {
    super.initState();
    _child = widget.child;
  }

  @override
  void didUpdateWidget(covariant AnimatedSlideIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {
      _child = widget.child;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      duration: widget.duration,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: widget.beginOffset,
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: widget.alignment,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: _child,
    );
  }
}

class _SidePanelContainer extends StatelessWidget {
  final Widget child;
  const _SidePanelContainer({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        color: Color.fromRGBO(0xEC, 0xEC, 0xEC, 1.0),
        borderRadius: BorderRadius.all(Radius.circular(10)),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 4),
            blurRadius: 16,
            color: Color.fromRGBO(0x00, 0x00, 0x00, 0.25),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: child,
      ),
    );
  }
}

class AddConnectionButtons extends StatelessWidget {
  final bool isAwaiting;
  final bool canAddParent;
  final bool canAddSpouse;
  final bool canAddChildren;
  final double paddingWidth;
  final void Function(Relationship relationship)? onAddConnectionPressed;

  const AddConnectionButtons({
    super.key,
    required this.isAwaiting,
    required this.canAddParent,
    required this.canAddSpouse,
    required this.canAddChildren,
    required this.paddingWidth,
    required this.onAddConnectionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final addConnectionPressed = onAddConnectionPressed;
    final foregroundColor = isAwaiting ? _kAwaitingColor : primaryColor;
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _AddConnectionButton(
          onPressed: canAddParent && addConnectionPressed != null
              ? () => addConnectionPressed(Relationship.parent)
              : null,
          foregroundColor: foregroundColor,
          icon: SvgPicture.asset(
            !isAwaiting
                ? 'assets/images/connection_parent.svg'
                : 'assets/images/connection_parent_awaiting.svg',
            width: 32,
          ),
          label: const Text('Parent'),
        ),
        _AddConnectionButton(
          onPressed: addConnectionPressed != null
              ? () => addConnectionPressed(Relationship.sibling)
              : null,
          foregroundColor: foregroundColor,
          icon: SvgPicture.asset(
            !isAwaiting
                ? 'assets/images/connection_sibling.svg'
                : 'assets/images/connection_sibling_awaiting.svg',
            width: 32,
          ),
          label: const Text('Sibling'),
        ),
        _AddConnectionButton(
          onPressed: canAddChildren && addConnectionPressed != null
              ? () => addConnectionPressed(Relationship.child)
              : null,
          foregroundColor: foregroundColor,
          icon: SvgPicture.asset(
            !isAwaiting
                ? 'assets/images/connection_child.svg'
                : 'assets/images/connection_child_awaiting.svg',
            width: 32,
          ),
          label: const Text('Child'),
        ),
        _AddConnectionButton(
          onPressed: canAddSpouse && addConnectionPressed != null
              ? () => addConnectionPressed(Relationship.spouse)
              : null,
          foregroundColor: foregroundColor,
          icon: SvgPicture.asset(
            !isAwaiting
                ? 'assets/images/connection_spouse.svg'
                : 'assets/images/connection_spouse_awaiting.svg',
            width: 32,
          ),
          label: const Text('Spouse'),
        ),
      ],
    );
  }
}

class _AddConnectionButton extends StatelessWidget {
  final Color foregroundColor;
  final Widget icon;
  final Widget label;
  final VoidCallback? onPressed;

  const _AddConnectionButton({
    super.key,
    required this.foregroundColor,
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
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, 84),
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                foregroundColor: foregroundColor,
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(height: 4),
                  label,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LogoText extends StatelessWidget {
  final double width;
  const LogoText({
    super.key,
    this.width = 290,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Image.asset(
        'assets/images/logo_text.png',
        width: width,
      ),
    );
  }
}

class TaglineText extends StatelessWidget {
  const TaglineText({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Text(
        'Collaborative Family Tree',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class ProfileNameSection extends StatelessWidget {
  final Person person;
  final Relatedness relatedness;
  final bool isPrimaryPersonSelected;

  const ProfileNameSection({
    super.key,
    required this.person,
    required this.relatedness,
    required this.isPrimaryPersonSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              person.profile.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (person.isOwned)
              const Positioned(
                right: -30,
                child: VerifiedBadge(size: 32),
              ),
          ],
        ),
        if (isPrimaryPersonSelected)
          const Text(
            'Me',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color.fromRGBO(0x3B, 0x3B, 0x3B, 1.0),
            ),
          )
        else
          Text(
            relatedness.description,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color.fromRGBO(0x3B, 0x3B, 0x3B, 1.0),
            ),
          ),
      ],
    );
  }
}

class _OwnershipUnableReasonDisplay extends StatelessWidget {
  final OwnershipUnableReason reason;
  final VoidCallback? onPressed;

  const _OwnershipUnableReasonDisplay({
    super.key,
    required this.reason,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(
          Radius.circular(12),
        ),
      ),
      child: GestureDetector(
        onTap: onPressed,
        child: switch (reason) {
          OwnershipUnableReason.child => const Text('Child'),
          OwnershipUnableReason.deceased => const Text('Deceased'),
          OwnershipUnableReason.disabled => const Text('Disabled'),
        },
      ),
    );
  }
}

class _PerspectiveTitle extends StatelessWidget {
  final String fullName;
  const _PerspectiveTitle({
    super.key,
    required this.fullName,
  });

  @override
  Widget build(BuildContext context) {
    const darkColor = Color.fromRGBO(0x3B, 0x3B, 0x3B, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8.0,
        vertical: 6.0,
      ),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(
          Radius.circular(10),
        ),
        color: Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ColorFiltered(
            colorFilter: ColorFilter.mode(
              darkColor,
              BlendMode.srcIn,
            ),
            child: Binoculars(
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$fullName\'s Tree',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: darkColor,
              shadows: const [
                Shadow(
                  color: Color.fromRGBO(0x00, 0x00, 0x00, 0.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

sealed class PanelPopupState {}

class PanelPopupStateNone implements PanelPopupState {
  const PanelPopupStateNone();
}

class PanelPopupStateProfile implements PanelPopupState {
  final Person person;
  final Relatedness relatedness;

  PanelPopupStateProfile({
    required this.person,
    required this.relatedness,
  });

  @override
  int get hashCode => Object.hash(person, relatedness);

  @override
  bool operator ==(Object other) {
    return other is PanelPopupStateProfile &&
        other.person == person &&
        other.relatedness == relatedness;
  }
}
