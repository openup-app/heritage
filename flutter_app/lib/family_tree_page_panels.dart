import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heritage/api.dart';
import 'package:heritage/date.dart';
import 'package:heritage/graph.dart';
import 'package:heritage/graph_provider.dart';
import 'package:heritage/graph_view.dart';
import 'package:heritage/help.dart';
import 'package:heritage/heritage_app.dart';
import 'package:heritage/layout.dart';
import 'package:heritage/photo_management.dart';
import 'package:heritage/profile_display.dart';
import 'package:heritage/profile_update.dart';
import 'package:heritage/util.dart';

const _kMinPanelHeight = 200.0;

class Panels extends ConsumerStatefulWidget {
  final Person? selectedPerson;
  final Relatedness? relatedness;
  final Person focalPerson;
  final ViewHistory viewHistory;
  final PanelPopupState panelPopupState;
  final VoidCallback onDismissPanelPopup;
  final void Function(Relationship relationship) onAddConnectionPressed;
  final void Function(Id id) onSelectPerson;
  final VoidCallback? onShare;
  final VoidCallback? onTakeOwnership;
  final VoidCallback onViewPerspective;
  final void Function(Rect rect) onViewRectUpdated;
  final VoidCallback onRecenter;
  final void Function(Profile update) onSaveProfile;

  const Panels({
    super.key,
    required this.selectedPerson,
    required this.relatedness,
    required this.focalPerson,
    required this.viewHistory,
    required this.panelPopupState,
    required this.onDismissPanelPopup,
    required this.onAddConnectionPressed,
    required this.onSelectPerson,
    required this.onShare,
    required this.onTakeOwnership,
    required this.onViewPerspective,
    required this.onViewRectUpdated,
    required this.onRecenter,
    required this.onSaveProfile,
  });

  @override
  ConsumerState<Panels> createState() => _PanelsState();
}

class _PanelsState extends ConsumerState<Panels> {
  bool _hadInitialLayout = false;
  late LayoutType _layout;
  final _modalKey = GlobalKey();
  final _modalKey2 = GlobalKey();

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
    final selectedPerson = widget.selectedPerson;
    final relatedness = widget.relatedness;
    final isPrimaryUser =
        widget.focalPerson.id == widget.viewHistory.primaryUserId;
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
                if (widget.viewHistory.perspectiveUserId != null)
                  _PerspectiveTitle(
                      fullName: widget.focalPerson.profile.fullName),
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
          if (widget.viewHistory.perspectiveUserId != null)
            Positioned(
              left: 16,
              bottom: 16,
              child: _LeavePerspectiveButton(
                onPressed: _goHome,
              ),
            ),
          Positioned(
            left: 16,
            bottom: 216,
            width: 48,
            height: 48,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: selectedPerson != null &&
                      relatedness != null &&
                      canViewPerspective(
                        id: selectedPerson.id,
                        primaryUserId: widget.viewHistory.primaryUserId,
                        focalPersonId: widget.focalPerson.id,
                        isSibling: relatedness.isSibling,
                        isOwned: selectedPerson.ownedBy != null,
                      )
                  ? 1.0
                  : 0.0,
              child: FilledButton(
                onPressed: widget.onViewPerspective,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.square(48),
                  backgroundColor: Colors.transparent,
                ),
                child: Image.asset(
                  'assets/images/perspective_portal.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: _DismissWhenNull(
              selectedPerson: selectedPerson,
              relatedness: relatedness,
              builder: (context, childKey, selectedPerson, relatedness) {
                return _DraggableSheet(
                  key: childKey,
                  selectedPerson: selectedPerson,
                  relatedness: relatedness,
                  isFocalUser: selectedPerson.id == widget.focalPerson.id,
                  primaryUserId: widget.viewHistory.primaryUserId,
                  isPerspectiveMode:
                      widget.viewHistory.perspectiveUserId != null,
                  isOwnedByMe: selectedPerson.ownedBy == widget.focalPerson.id,
                  onAddConnectionPressed: widget.onAddConnectionPressed,
                  onDismissPanelPopup: widget.onDismissPanelPopup,
                  onViewPerspective: canViewPerspective(
                    id: selectedPerson.id,
                    primaryUserId: widget.viewHistory.primaryUserId,
                    focalPersonId: widget.focalPerson.id,
                    isSibling: relatedness.isSibling,
                    isOwned: selectedPerson.ownedBy != null,
                  )
                      ? widget.onViewPerspective
                      : null,
                  onShareLoginLink: !relatedness.isDirectRelativeOrSpouse
                      ? null
                      : () => _onShareLoginLink(selectedPerson),
                  onDeleteManagedUser: canDeletePerson(selectedPerson)
                      ? () => _onDeleteManagedUser(selectedPerson.id)
                      : null,
                  onSaveProfile: widget.onSaveProfile,
                );
              },
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
                  if (widget.viewHistory.perspectiveUserId != null)
                    _PerspectiveTitle(
                      fullName: widget.focalPerson.profile.fullName,
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
          if (widget.viewHistory.perspectiveUserId != null)
            Positioned(
              left: 24,
              bottom: 24,
              child: _LeavePerspectiveButton(
                onPressed: _goHome,
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ProfileNameSection(
                              person: person,
                              relatedness: relatedness,
                              isPrimaryUser:
                                  widget.viewHistory.primaryUserId == person.id,
                            ),
                            ProfileDisplay(
                              initialProfile: person.profile,
                              isPrimaryUser: isPrimaryUser,
                              isEditable: person.ownedBy ==
                                      widget.focalPerson.id &&
                                  widget.viewHistory.perspectiveUserId == null,
                              isOwnedByPrimaryUser: person.ownedBy ==
                                  widget.viewHistory.primaryUserId,
                              hasDifferentOwner: person.ownedBy != person.id,
                              onViewPerspective: canViewPerspective(
                                id: person.id,
                                primaryUserId: widget.viewHistory.primaryUserId,
                                focalPersonId: widget.focalPerson.id,
                                isSibling: relatedness.isSibling,
                                isOwned: person.ownedBy != null,
                              )
                                  ? widget.onViewPerspective
                                  : null,
                              onShareLoginLink:
                                  (widget.viewHistory.perspectiveUserId !=
                                              null ||
                                          !relatedness.isDirectRelativeOrSpouse)
                                      ? null
                                      : () => _onShareLoginLink(person),
                              onDeleteManagedUser: canDeletePerson(person)
                                  ? () {
                                      _onDeleteManagedUser(person.id);
                                      widget.onDismissPanelPopup();
                                    }
                                  : null,
                              onSaveProfile: widget.onSaveProfile,
                            ),
                          ],
                        ),
                      ),
                    PanelPopupStateAddConnection(
                      :final targetNode,
                      :final focalNode,
                      :final relationship
                    ) =>
                      _SidePanelContainer(
                        key: Key('connection_${relationship.name}'),
                        child: AddConnectionDisplay(
                          targetNode: targetNode,
                          focalNode: focalNode,
                          relationship: relationship,
                          onShare: widget.onShare,
                          onTakeOwnership: widget.onTakeOwnership,
                        ),
                      ),
                    PanelPopupStatePendingProfile(
                      :final targetNode,
                      :final focalNode
                    ) =>
                      _SidePanelContainer(
                        key: Key('approval_${targetNode.id}'),
                        child: PendingProfiledDisplay(
                          targetNode: targetNode,
                          focalNode: focalNode,
                          onShare: () async {
                            await shareInvite(
                              targetId: targetNode.id,
                              targetName: targetNode.data.profile.firstName,
                              focalName: focalNode.data.profile.firstName,
                              referrerId: widget.focalPerson.id,
                            );
                            if (mounted) {
                              widget.onDismissPanelPopup();
                            }
                          },
                          onTakeOwnership: widget.onTakeOwnership,
                          onAddConnectionPressed: null,
                          onDeletePressed: !canDeletePerson(targetNode.data)
                              ? null
                              : () {
                                  widget.onDismissPanelPopup();
                                  _onDelete(targetNode.data);
                                },
                        ),
                      ),
                  },
                ),
              ),
            ),
          ),
          if (canAddRelative(relatedness?.isBloodRelative == true,
              widget.viewHistory.perspectiveUserId != null))
            AnimatedSlideIn(
              duration: const Duration(milliseconds: 300),
              beginOffset: const Offset(0, 0.1),
              alignment: Alignment.bottomCenter,
              child: selectedPerson == null || relatedness == null
                  ? null
                  : Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                            boxShadow: [
                              BoxShadow(
                                offset: Offset(0, 4),
                                blurRadius: 16,
                                color: Color.fromRGBO(0x00, 0x00, 0x00, 0.25),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20.0),
                            child: buildAddConnectionButtons(
                              person: selectedPerson,
                              relatedness: relatedness,
                              isPerspectiveMode:
                                  widget.viewHistory.perspectiveUserId != null,
                              paddingWidth: 20,
                              onAddConnectionPressed:
                                  widget.onAddConnectionPressed,
                            ),
                          ),
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
        final context2 = _modalKey2.currentContext;
        if (context2 != null) {
          Navigator.of(context2).pop();
        }
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
            break;
          case PanelPopupStateProfile():
            // Displayed in build() by bottom panel
            break;
          case PanelPopupStateAddConnection(
              :final targetNode,
              :final focalNode,
              :final relationship
            ):
            WidgetsBinding.instance.endOfFrame.then((_) {
              if (mounted) {
                _showAddConnectionModal(targetNode, focalNode, relationship);
              }
            });
          case PanelPopupStatePendingProfile(
              :final targetNode,
              :final focalNode,
              :final relatedness
            ):
            final owned = targetNode.data.ownedBy != null;
            if (owned) {
              return;
            }
            WidgetsBinding.instance.endOfFrame.then((_) {
              if (mounted) {
                _showPendingProfileModal(
                    targetNode: targetNode,
                    focalNode: focalNode,
                    onAddConnectionPressed: !canAddRelative(
                            relatedness.isBloodRelative,
                            widget.viewHistory.perspectiveUserId != null)
                        ? null
                        : () async {
                            await WidgetsBinding.instance.endOfFrame;
                            if (!mounted) {
                              return;
                            }
                            _showMiniAddConnectionModal(
                              context: context,
                              selectedPerson: targetNode.data,
                              relatedness: relatedness,
                            );
                          },
                    onDeletePressed: !canDeletePerson(targetNode.data)
                        ? null
                        : () => _onDelete(targetNode.data));
              }
            });
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

  void _showAddConnectionModal(LinkedNode<Person> targetNode,
      LinkedNode<Person> focalNode, Relationship relationship) async {
    final poppedManually = await showModalBottomSheetWithDragHandle<bool>(
      context: context,
      builder: (context) {
        final onShare = widget.onShare;
        final onTakeOwnership = widget.onTakeOwnership;
        return AddConnectionDisplay(
          key: _modalKey,
          targetNode: targetNode,
          focalNode: focalNode,
          relationship: relationship,
          onShare: onShare == null
              ? null
              : () {
                  Navigator.of(context).pop(true);
                  onShare();
                },
          onTakeOwnership: onTakeOwnership == null
              ? null
              : () {
                  Navigator.of(context).pop(true);
                  onTakeOwnership();
                },
        );
      },
    );
    if (mounted && poppedManually != true) {
      // Panel dismissed, no one knows, so inform this means deselect user
      widget.onDismissPanelPopup();
    }
  }

  void _showPendingProfileModal({
    required LinkedNode<Person> targetNode,
    required LinkedNode<Person> focalNode,
    required VoidCallback? onAddConnectionPressed,
    required VoidCallback? onDeletePressed,
  }) async {
    final poppedManually = await showModalBottomSheetWithDragHandle<bool>(
      context: context,
      builder: (context) {
        final onShare = widget.onShare;
        final onTakeOwnership = widget.onTakeOwnership;
        return PendingProfiledDisplay(
          key: _modalKey,
          targetNode: targetNode,
          focalNode: focalNode,
          onShare: onShare == null
              ? null
              : () {
                  Navigator.of(context).pop(true);
                  onShare();
                },
          onTakeOwnership: onTakeOwnership == null
              ? null
              : () {
                  Navigator.of(context).pop(true);
                  onTakeOwnership();
                },
          onAddConnectionPressed: onAddConnectionPressed == null
              ? null
              : () {
                  Navigator.of(context).pop(true);
                  onAddConnectionPressed();
                },
          onDeletePressed: onDeletePressed == null
              ? null
              : () {
                  Navigator.of(context).pop(true);
                  onDeletePressed();
                },
        );
      },
    );
    if (mounted && poppedManually != true) {
      // Panel dismissed, no one knows, so inform this means deselect user
      widget.onDismissPanelPopup();
    }
  }

  void _showMiniAddConnectionModal({
    required BuildContext context,
    required Person selectedPerson,
    required Relatedness relatedness,
  }) async {
    final poppedManually = await showModalBottomSheet<bool>(
      context: context,
      barrierColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      builder: (context) {
        return Column(
          key: _modalKey2,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  selectedPerson.profile.fullName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: buildAddConnectionButtons(
                person: selectedPerson,
                relatedness: relatedness,
                isPerspectiveMode: widget.viewHistory.perspectiveUserId != null,
                paddingWidth: 16,
                onAddConnectionPressed: (relationship) {
                  Navigator.of(context).pop(true);
                  widget.onAddConnectionPressed(relationship);
                },
              ),
            ),
          ],
        );
      },
    );
    if (mounted && poppedManually != true) {
      // Panel dismissed, no one knows, so inform this means deselect user
      widget.onDismissPanelPopup();
    }
  }

  void _onDelete(Person person) {
    final notifier = ref.read(graphProvider.notifier);
    final deleteFuture = notifier.deletePerson(person.id);
    showBlockingModal(context, deleteFuture);
  }

  void _goHome() {
    context.goNamed(
      'view',
      extra: ViewHistory(primaryUserId: widget.viewHistory.primaryUserId),
    );
  }

  void _onShareLoginLink(Person person) =>
      shareLoginLink(targetId: person.id, targetName: person.profile.firstName);

  void _onDeleteManagedUser(Id id) async {
    final notifier = ref.read(graphProvider.notifier);
    await showBlockingModal(
      context,
      notifier.deletePerson(id),
    );
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

Widget buildAddConnectionButtons({
  required Person person,
  required Relatedness relatedness,
  required bool isPerspectiveMode,
  required double paddingWidth,
  required void Function(Relationship relationship) onAddConnectionPressed,
}) {
  return AddConnectionButtons(
    paddingWidth: paddingWidth,
    canAddParent: person.parents.isEmpty && relatedness.isBloodRelative,
    canAddSpouse: person.spouses.isEmpty,
    canAddChildren:
        relatedness.isAncestor || !relatedness.isGrandparentLevelOrHigher,
    onAddConnectionPressed: onAddConnectionPressed,
  );
}

class _DismissWhenNull extends StatefulWidget {
  final Person? selectedPerson;
  final Relatedness? relatedness;
  final Widget Function(BuildContext context, Key childKey,
      Person selectedPerson, Relatedness relatedness) builder;

  const _DismissWhenNull({
    super.key,
    required this.selectedPerson,
    required this.relatedness,
    required this.builder,
  });

  @override
  State<_DismissWhenNull> createState() => _DismissWhenNullState();
}

class _DismissWhenNullState extends State<_DismissWhenNull>
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
  void didUpdateWidget(covariant _DismissWhenNull oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPerson != widget.selectedPerson ||
        oldWidget.relatedness != widget.relatedness) {
      final shouldShow = widget.selectedPerson != null &&
          widget.relatedness != null &&
          widget.selectedPerson?.ownedBy != null;
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

class _DraggableSheet extends StatefulWidget {
  final Person selectedPerson;
  final Relatedness relatedness;
  final bool isFocalUser;
  final String primaryUserId;
  final bool isPerspectiveMode;
  final bool isOwnedByMe;
  final void Function(Relationship relationship) onAddConnectionPressed;
  final VoidCallback onDismissPanelPopup;
  final VoidCallback? onViewPerspective;
  final VoidCallback? onShareLoginLink;
  final VoidCallback? onDeleteManagedUser;
  final void Function(Profile update) onSaveProfile;

  const _DraggableSheet({
    super.key,
    required this.selectedPerson,
    required this.relatedness,
    required this.isFocalUser,
    required this.primaryUserId,
    required this.isPerspectiveMode,
    required this.isOwnedByMe,
    required this.onAddConnectionPressed,
    required this.onDismissPanelPopup,
    required this.onViewPerspective,
    required this.onShareLoginLink,
    required this.onDeleteManagedUser,
    required this.onSaveProfile,
  });

  @override
  State<_DraggableSheet> createState() => _DraggableSheetState();
}

class _DraggableSheetState extends State<_DraggableSheet> {
  final _draggableScrollableController = DraggableScrollableController();

  @override
  Widget build(BuildContext context) {
    // Clamped in case of narrow, but extremely tall/short windows
    final windowSize = MediaQuery.of(context).size;
    final maxPanelHeight = windowSize.height - 68.0;
    final minPanelRatio =
        (_kMinPanelHeight / windowSize.height).clamp(0.05, 1.0);
    final maxPanelRatio = (maxPanelHeight / windowSize.height).clamp(0.05, 1.0);

    return DraggableScrollableSheet(
      controller: _draggableScrollableController,
      expand: false,
      snap: true,
      initialChildSize: minPanelRatio,
      minChildSize: minPanelRatio,
      maxChildSize: maxPanelRatio,
      builder: (context, controller) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  offset: Offset(0, 4),
                  blurRadius: 16,
                  color: Color.fromRGBO(0x00, 0x00, 0x00, 0.25),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: () {
                _draggableScrollableController.animateTo(
                  maxPanelRatio,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              child: CustomScrollView(
                key: Key(widget.selectedPerson.id),
                controller: controller,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  if (canAddRelative(widget.relatedness.isBloodRelative,
                      widget.isPerspectiveMode))
                    PinnedHeaderSliver(
                      child: ColoredBox(
                        color: Colors.white,
                        child: Column(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Center(
                                    child: Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 12.0),
                                      child: _DragHandle(),
                                    ),
                                  ),
                                  Text(
                                    widget.isFocalUser
                                        ? 'I need to add my...'
                                        : 'Add ${widget.selectedPerson.profile.firstName}\'s...',
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: buildAddConnectionButtons(
                                      person: widget.selectedPerson,
                                      relatedness: widget.relatedness,
                                      isPerspectiveMode:
                                          widget.isPerspectiveMode,
                                      paddingWidth: 12,
                                      onAddConnectionPressed:
                                          widget.onAddConnectionPressed,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(
                              height: 1,
                              color: Color.fromRGBO(0xEB, 0xEB, 0xEB, 1.0),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    PinnedHeaderSliver(
                      child: Container(
                        width: double.infinity,
                        color: Colors.white,
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: _DragHandle(),
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ProfileNameSection(
                        person: widget.selectedPerson,
                        relatedness: widget.relatedness,
                        isPrimaryUser:
                            widget.selectedPerson.id == widget.primaryUserId,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Consumer(
                        builder: (context, ref, child) {
                          return ProfileDisplay(
                            initialProfile: widget.selectedPerson.profile,
                            isPrimaryUser: widget.selectedPerson.id ==
                                widget.primaryUserId,
                            isEditable:
                                widget.isOwnedByMe && !widget.isPerspectiveMode,
                            isOwnedByPrimaryUser:
                                widget.selectedPerson.ownedBy ==
                                    widget.primaryUserId,
                            hasDifferentOwner: widget.selectedPerson.ownedBy !=
                                widget.selectedPerson.id,
                            onViewPerspective: widget.onViewPerspective,
                            onShareLoginLink: (widget.isPerspectiveMode ||
                                    !widget
                                        .relatedness.isDirectRelativeOrSpouse)
                                ? null
                                : widget.onShareLoginLink,
                            onDeleteManagedUser:
                                widget.onDeleteManagedUser == null
                                    ? null
                                    : () {
                                        _dismissDraggableSheet(minPanelRatio);
                                        widget.onDismissPanelPopup();
                                        widget.onDeleteManagedUser?.call();
                                      },
                            onSaveProfile: widget.onSaveProfile,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _dismissDraggableSheet(double ratio) {
    _draggableScrollableController.animateTo(
      ratio,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
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
  final VoidCallback onPressed;

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
        color: Colors.white,
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
        padding: const EdgeInsets.symmetric(horizontal: 16) +
            const EdgeInsets.only(top: 8, bottom: 16),
        child: child,
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

class ProfileNameSection extends StatelessWidget {
  final Person person;
  final Relatedness relatedness;
  final bool isPrimaryUser;

  const ProfileNameSection({
    super.key,
    required this.person,
    required this.relatedness,
    required this.isPrimaryUser,
  });

  @override
  Widget build(BuildContext context) {
    const nameSectionHeight = 60.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: nameSectionHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isPrimaryUser) ...[
                  const Text('My profile'),
                  Text(
                    person.profile.fullName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          person.profile.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const VerifiedBadge(
                        width: 24,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          relatedness.description,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  color: const Color.fromRGBO(
                                      0x7A, 0x7A, 0x7A, 1.0)),
                        ),
                      ),
                      Consumer(
                        builder: (context, ref, child) {
                          return Text(
                            person.ownedBy == person.id
                                ? 'Verified by ${person.profile.firstName}'
                                : 'Managed by ${ref.watch(graphProvider.select((s) => s.people[person.ownedBy]?.profile.firstName))}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    color: const Color.fromRGBO(
                                        0x3F, 0x71, 0xFF, 1.0)),
                          );
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ProfileDisplay extends StatelessWidget {
  final Profile initialProfile;
  final bool isPrimaryUser;
  final bool isEditable;
  final bool isOwnedByPrimaryUser;
  final bool hasDifferentOwner;
  final VoidCallback? onViewPerspective;
  final VoidCallback? onShareLoginLink;
  final VoidCallback? onDeleteManagedUser;
  final void Function(Profile profile) onSaveProfile;

  const ProfileDisplay({
    super.key,
    required this.initialProfile,
    required this.isPrimaryUser,
    required this.isEditable,
    required this.isOwnedByPrimaryUser,
    required this.hasDifferentOwner,
    required this.onViewPerspective,
    required this.onShareLoginLink,
    required this.onDeleteManagedUser,
    required this.onSaveProfile,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        profileUpdateProvider.overrideWith(
            (ref) => ProfileUpdateNotifier(initialProfile: initialProfile)),
      ],
      child: _ProfileDisplay(
        isPrimaryUser: isPrimaryUser,
        isEditable: isEditable,
        isOwnedByPrimaryUser: isOwnedByPrimaryUser,
        hasDifferentOwner: hasDifferentOwner,
        onViewPerspective: onViewPerspective,
        onShareLoginLink: onShareLoginLink,
        onDeleteManagedUser: onDeleteManagedUser,
        onSaveProfile: onSaveProfile,
      ),
    );
  }
}

class _ProfileDisplay extends ConsumerStatefulWidget {
  final bool isPrimaryUser;
  final bool isEditable;
  final bool isOwnedByPrimaryUser;
  final bool hasDifferentOwner;
  final VoidCallback? onViewPerspective;
  final VoidCallback? onShareLoginLink;
  final VoidCallback? onDeleteManagedUser;
  final void Function(Profile profile) onSaveProfile;

  const _ProfileDisplay({
    super.key,
    required this.isPrimaryUser,
    required this.isEditable,
    required this.isOwnedByPrimaryUser,
    required this.hasDifferentOwner,
    required this.onViewPerspective,
    required this.onShareLoginLink,
    required this.onDeleteManagedUser,
    required this.onSaveProfile,
  });

  @override
  ConsumerState<_ProfileDisplay> createState() => _ProfileDisplayState();
}

class _ProfileDisplayState extends ConsumerState<_ProfileDisplay> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _birthdayController;
  late final TextEditingController _deathdayController;
  late final TextEditingController _birthplaceController;
  late final TextEditingController _occupationController;
  late final TextEditingController _hobbiesController;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileUpdateProvider);
    _firstNameController = TextEditingController(text: profile.firstName);
    _lastNameController = TextEditingController(text: profile.lastName);
    _birthdayController = TextEditingController();
    _deathdayController = TextEditingController();
    _birthplaceController = TextEditingController(text: profile.birthplace);
    _occupationController = TextEditingController(text: profile.occupation);
    _hobbiesController = TextEditingController(text: profile.hobbies);

    final birthday = profile.birthday;
    final deathday = profile.deathday;
    _birthdayController.text = birthday == null ? '' : formatDate(birthday);
    _deathdayController.text = deathday == null ? '' : formatDate(deathday);

    ref.listenManual(profileUpdateProvider, (previous, next) {
      if (previous != next) {
        widget.onSaveProfile(next);
      }
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthdayController.dispose();
    _deathdayController.dispose();
    _birthplaceController.dispose();
    _occupationController.dispose();
    _hobbiesController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasDateOfPassing = widget.hasDifferentOwner ||
        ref.watch(profileUpdateProvider.select((s) => s.deathday != null));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.isEditable) ...[
          const SizedBox(height: 24),
          Text(
            'Profile Picture',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Add your profile picture',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: AddProfilePhotoButton(
              photo: ref.watch(profileUpdateProvider.select((p) => p.photo)),
              onPhoto: ref.read(profileUpdateProvider.notifier).photo,
              onDelete: () {
                final notifier = ref.read(profileUpdateProvider.notifier);
                notifier.photo(
                  const Photo.network(
                    key: 'public/no_image.png',
                    url: '$cdn/public/no_image.png',
                  ),
                );
              },
            ),
          ),
        ],
        if (widget.onViewPerspective != null) ...[
          const SizedBox(height: 18),
          FilledButton(
            onPressed: widget.onViewPerspective,
            style: FilledButton.styleFrom(
              fixedSize: const Size.fromHeight(44),
              foregroundColor: Colors.white,
              backgroundColor: primaryColor,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Binoculars(
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                    'View ${ref.watch(profileUpdateProvider.select((s) => s.fullName))}\'s tree'),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Details',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (widget.isEditable) ...[
          const SizedBox(height: 4),
          Text(
            'Add some information about yourself so your family can see',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
        ],
        Column(
          children: [
            FocusTraversalGroup(
              child: InputForm(
                children: [
                  InputLabel(
                    label: 'First name',
                    child: TextFormField(
                      controller: _firstNameController,
                      enabled: widget.isEditable,
                      onChanged:
                          ref.read(profileUpdateProvider.notifier).firstName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  InputLabel(
                    label: 'Last name',
                    child: TextFormField(
                      controller: _lastNameController,
                      enabled: widget.isEditable,
                      onChanged:
                          ref.read(profileUpdateProvider.notifier).lastName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  InputLabel(
                    label: 'Date of birth',
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _birthdayController,
                            enabled: widget.isEditable,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [DateTextFormatter()],
                            onChanged: ref
                                .read(profileUpdateProvider.notifier)
                                .birthday,
                            decoration: InputDecoration(
                              hintText: getFormattedDatePattern().formatted,
                            ),
                          ),
                        ),
                        if (widget.isEditable)
                          ExcludeFocus(
                            child: IconButton(
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  firstDate: firstDate,
                                  lastDate: lastDate,
                                  initialDate: ref.watch(profileUpdateProvider
                                      .select((p) => p.birthday ?? lastDate)),
                                );
                                if (!mounted || date == null) {
                                  return;
                                }
                                _birthdayController.text = formatDate(date);
                                ref
                                    .read(profileUpdateProvider.notifier)
                                    .birthdayObject(date);
                              },
                              icon: const Icon(
                                Icons.calendar_month,
                                color: Color.fromRGBO(138, 138, 138, 1),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (hasDateOfPassing)
                    InputLabel(
                      label: 'Date of passing',
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _deathdayController,
                              enabled: widget.isEditable,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [DateTextFormatter()],
                              onChanged: ref
                                  .read(profileUpdateProvider.notifier)
                                  .deathday,
                              decoration: InputDecoration(
                                hintText: getFormattedDatePattern().formatted,
                              ),
                            ),
                          ),
                          if (widget.isEditable)
                            ExcludeFocus(
                              child: IconButton(
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    firstDate: firstDate,
                                    lastDate: lastDate,
                                    initialDate: ref.watch(profileUpdateProvider
                                        .select((p) => p.deathday ?? lastDate)),
                                  );
                                  if (!mounted || date == null) {
                                    return;
                                  }
                                  _deathdayController.text = formatDate(date);
                                  ref
                                      .read(profileUpdateProvider.notifier)
                                      .deathdayObject(date);
                                },
                                icon: const Icon(
                                  Icons.calendar_month,
                                  color: Color.fromRGBO(138, 138, 138, 1),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  InputLabel(
                    label: 'Place of birth',
                    child: TextFormField(
                      controller: _birthplaceController,
                      enabled: widget.isEditable,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onChanged:
                          ref.read(profileUpdateProvider.notifier).birthplace,
                    ),
                  ),
                  InputLabel(
                    label: 'Occupation',
                    child: TextFormField(
                      controller: _occupationController,
                      enabled: widget.isEditable,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onChanged:
                          ref.read(profileUpdateProvider.notifier).occupation,
                    ),
                  ),
                  InputLabel(
                    label: 'Hobbies',
                    child: TextFormField(
                      controller: _hobbiesController,
                      enabled: widget.isEditable,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onChanged:
                          ref.read(profileUpdateProvider.notifier).hobbies,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.isEditable) ...[
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Gender',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Needed to list you properly in the tree',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final gender in Gender.values) ...[
                    if (gender != Gender.values.first)
                      const SizedBox(width: 16),
                    Expanded(
                      child: Builder(builder: (context) {
                        final selectedGender = ref.watch(
                            profileUpdateProvider.select((p) => p.gender));
                        return FilledButton(
                          onPressed: () => ref
                              .read(profileUpdateProvider.notifier)
                              .gender(gender),
                          style: FilledButton.styleFrom(
                            fixedSize: const Size.fromHeight(44),
                            foregroundColor:
                                selectedGender == gender ? Colors.white : null,
                            backgroundColor:
                                selectedGender == gender ? primaryColor : null,
                          ),
                          child: Text(
                              '${gender.name[0].toUpperCase()}${gender.name.substring(1)}'),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ],
            if (ref.watch(
                profileUpdateProvider.select((p) => p.gallery.isNotEmpty))) ...[
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                child: GalleryView(
                  photos:
                      ref.watch(profileUpdateProvider.select((p) => p.gallery)),
                ),
              ),
            ],
            if (widget.isEditable) ...[
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Gallery',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add photos for your family to see',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: PhotoManagement(
                  gallery:
                      ref.watch(profileUpdateProvider.select((p) => p.gallery)),
                  onChanged: ref.read(profileUpdateProvider.notifier).gallery,
                  onProfilePhotoChanged: (photo) {
                    ref.read(profileUpdateProvider.notifier).photo(photo);
                    widget.onSaveProfile(ref.read(profileUpdateProvider));
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (widget.onShareLoginLink != null) ...[
          Text(
            'Login Link',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Builder(
            builder: (context) {
              final name =
                  ref.watch(profileUpdateProvider.select((s) => s.firstName));
              return Text(
                'Visible to direct relatives for login assistance. Share this with $name, sharing it with others risks the family tree.',
                style: Theme.of(context).textTheme.labelLarge,
              );
            },
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: widget.onShareLoginLink,
            style: FilledButton.styleFrom(
              fixedSize: const Size.fromHeight(44),
              foregroundColor: Colors.white,
              backgroundColor: primaryColor,
            ),
            child: const Text(
              'Share Login Link',
            ),
          ),
        ],
        // Display the button for certain users, even if parent won't handle the click
        if (widget.hasDifferentOwner && widget.isOwnedByPrimaryUser) ...[
          const SizedBox(height: 24),
          TextButton(
            onPressed: widget.onDeleteManagedUser == null
                ? null
                : _onDeleteManagedUser,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(
                'Delete ${ref.watch(profileUpdateProvider.select((p) => p.firstName))} from the tree'),
          ),
          const SizedBox(height: 24),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  void _onDeleteManagedUser() async {
    final profile = ref.watch(profileUpdateProvider);
    final delete = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete ${profile.firstName}?'),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (mounted && delete == true) {
      widget.onDeleteManagedUser?.call();
    }
  }
}

class FormBorder extends StatelessWidget {
  final Widget child;

  const FormBorder({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color.fromRGBO(0xEB, 0xEB, 0xEB, 1.0),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: child,
    );
  }
}

class InputForm extends StatelessWidget {
  final List<Widget> children;

  const InputForm({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return FormBorder(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, child) in children.indexed) ...[
            child,
            if (index != children.length - 1)
              const Divider(
                height: 1,
                indent: 14,
                color: Color.fromRGBO(0xD8, 0xD8, 0xD8, 1.0),
              ),
          ],
        ],
      ),
    );
  }
}

class InputLabel extends StatelessWidget {
  final String label;
  final String? hintText;
  final Widget child;

  const InputLabel({
    super.key,
    required this.label,
    this.hintText,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12.0, top: 8.0),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color.fromRGBO(0x51, 0x51, 0x51, 1.0),
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Theme(
            data: Theme.of(context).copyWith(
                inputDecorationTheme: const InputDecorationTheme(
              isCollapsed: true,
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              fillColor: Colors.transparent,
            )),
            child: child,
          ),
        ),
      ],
    );
  }
}

class AddConnectionDisplay extends ConsumerStatefulWidget {
  final LinkedNode<Person> targetNode;
  final LinkedNode<Person> focalNode;
  final Relationship relationship;
  final VoidCallback? onShare;
  final VoidCallback? onTakeOwnership;

  const AddConnectionDisplay({
    super.key,
    required this.targetNode,
    required this.focalNode,
    required this.relationship,
    required this.onShare,
    required this.onTakeOwnership,
  });

  @override
  ConsumerState<AddConnectionDisplay> createState() =>
      _AddConnectionDisplayState();
}

class _AddConnectionDisplayState extends ConsumerState<AddConnectionDisplay> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShareButton(
          sourceFirstName: widget.focalNode.data.profile.firstName,
          relatednessDescription: relatednessDescription(
            widget.focalNode,
            widget.targetNode,
            pov: PointOfView.first,
          ),
          onPressed: widget.onShare,
        ),
        const SizedBox(height: 16),
        TakeOwnershipButton(
          onPressed: widget.onTakeOwnership,
        ),
      ],
    );
  }
}

class PendingProfiledDisplay extends StatefulWidget {
  final LinkedNode<Person> targetNode;
  final LinkedNode<Person> focalNode;
  final VoidCallback? onShare;
  final VoidCallback? onTakeOwnership;
  final VoidCallback? onAddConnectionPressed;
  final VoidCallback? onDeletePressed;

  const PendingProfiledDisplay({
    super.key,
    required this.targetNode,
    required this.focalNode,
    required this.onShare,
    required this.onTakeOwnership,
    required this.onAddConnectionPressed,
    required this.onDeletePressed,
  });

  @override
  State<PendingProfiledDisplay> createState() => _PendingProfiledDisplayState();
}

class _PendingProfiledDisplayState extends State<PendingProfiledDisplay> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pending\nprofile',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: Color.fromRGBO(0x3C, 0x3C, 0x3C, 1.0),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Waiting for them to join and finish their profile'),
            const SizedBox(height: 16),
            ShareButton(
              sourceFirstName: widget.focalNode.data.profile.firstName,
              relatednessDescription: relatednessDescription(
                widget.focalNode,
                widget.targetNode,
                pov: PointOfView.first,
              ),
              repeatedShare: true,
              onPressed: widget.onShare,
            ),
            const SizedBox(height: 16),
            TakeOwnershipButton(
              onPressed: widget.onTakeOwnership,
            ),
            const SizedBox(height: 16),
          ],
        ),
        if (widget.onAddConnectionPressed != null ||
            widget.onDeletePressed != null)
          Align(
            alignment: Alignment.topRight,
            child: PopupMenuButton(
              itemBuilder: (context) {
                return [
                  if (widget.onAddConnectionPressed != null)
                    PopupMenuItem(
                      onTap: widget.onAddConnectionPressed,
                      child: const Text('Add another relative'),
                    ),
                  if (widget.onDeletePressed != null)
                    PopupMenuItem(
                      onTap: _onDeletePressed,
                      child: const Text(
                        'Delete profile',
                        style: TextStyle(
                          color: Color.fromRGBO(0xFF, 0x00, 0x00, 1.0),
                        ),
                      ),
                    ),
                ];
              },
            ),
          ),
      ],
    );
  }

  void _onDeletePressed() async {
    final delete = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete profile?'),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (mounted && delete == true) {
      widget.onDeletePressed?.call();
    }
  }
}

class ShareButton extends StatelessWidget {
  final String? sourceFirstName;
  final String relatednessDescription;
  final bool repeatedShare;
  final VoidCallback? onPressed;

  const ShareButton({
    super.key,
    required this.sourceFirstName,
    required this.relatednessDescription,
    this.repeatedShare = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: primaryColor,
        fixedSize: const Size.fromHeight(64),
      ),
      child: Stack(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 25),
              child: Icon(CupertinoIcons.share),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 54.0),
              child: Text(
                !repeatedShare
                    ? 'Invite $relatednessDescription\nto complete their profile'
                    : 'Share link again',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TakeOwnershipButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const TakeOwnershipButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => _onPressed(context),
      style: OutlinedButton.styleFrom(
        fixedSize: const Size.fromHeight(64),
      ),
      child: const Text('I will finish their profile'),
    );
  }

  void _onPressed(BuildContext context) async {
    final takeOwnership = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Manage Profile?'),
          content: const Text(
              'Manage a profile only if the person is unable to, such as children, disabled or deceased relatives.'),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Proceed'),
            ),
          ],
        );
      },
    );
    if (context.mounted && takeOwnership == true) {
      onPressed?.call();
    }
  }
}

class _Photo extends StatelessWidget {
  final Photo photo;

  const _Photo({
    super.key,
    required this.photo,
  });

  @override
  Widget build(BuildContext context) {
    return switch (photo) {
      MemoryPhoto(:final Uint8List bytes) => Image.memory(
          bytes,
          fit: BoxFit.cover,
        ),
      NetworkPhoto(:final url) => Image.network(
          url,
          fit: BoxFit.cover,
        ),
      _ => const SizedBox.shrink(),
    };
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

class PanelPopupStateAddConnection implements PanelPopupState {
  final LinkedNode<Person> targetNode;
  final LinkedNode<Person> focalNode;
  final Relationship relationship;

  PanelPopupStateAddConnection({
    required this.targetNode,
    required this.focalNode,
    required this.relationship,
  });

  @override
  int get hashCode =>
      Object.hash(targetNode.data, focalNode.data, relationship);

  @override
  bool operator ==(Object other) {
    return other is PanelPopupStateAddConnection &&
        other.targetNode.data == targetNode.data &&
        other.focalNode.data == focalNode.data &&
        other.relationship == relationship;
  }
}

class PanelPopupStatePendingProfile implements PanelPopupState {
  final LinkedNode<Person> targetNode;
  final LinkedNode<Person> focalNode;
  final Relatedness relatedness;

  PanelPopupStatePendingProfile({
    required this.targetNode,
    required this.focalNode,
    required this.relatedness,
  });

  @override
  int get hashCode => Object.hash(targetNode.data, focalNode.data, relatedness);

  @override
  bool operator ==(Object other) {
    return other is PanelPopupStatePendingProfile &&
        other.targetNode.data == targetNode.data &&
        other.focalNode.data == focalNode.data &&
        other.relatedness == relatedness;
  }
}

class GalleryView extends StatefulWidget {
  final List<Photo> photos;
  const GalleryView({
    super.key,
    required this.photos,
  });

  @override
  State<GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  static const _largeNumber = 1000000000;

  late final PageController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    const center = _largeNumber ~/ 2;
    final int initialIndex;
    if (widget.photos.isEmpty) {
      initialIndex = center;
    } else {
      initialIndex = center ~/ widget.photos.length * widget.photos.length;
    }
    _controller = PageController(
      initialPage: initialIndex,
    );
    _controller.addListener(_restartTimer);
    _restartTimer();
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return const ImageAspect(
        child: ColoredBox(
          color: Colors.grey,
        ),
      );
    }
    return ScrollbarTheme(
      data: const ScrollbarThemeData(
        thumbVisibility: WidgetStatePropertyAll(false),
      ),
      child: ImageAspect(
        child: PageView.builder(
          controller: _controller,
          scrollBehavior: const _AllDevicesScrollBehavior(),
          itemCount: _largeNumber,
          itemBuilder: (context, index) {
            final photo = widget.photos[index % widget.photos.length];
            return _Photo(
              photo: photo,
            );
          },
        ),
      ),
    );
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _onNext());
  }

  void _onNext() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
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

/// Allows all device kinds to scroll the scroll view
class _AllDevicesScrollBehavior extends ScrollBehavior {
  const _AllDevicesScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}
