import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heritage/api.dart';
import 'package:heritage/date.dart';
import 'package:heritage/family_tree_page.dart';
import 'package:heritage/graph_provider.dart';
import 'package:heritage/graph_view.dart';
import 'package:heritage/help.dart';
import 'package:heritage/heritage_app.dart';
import 'package:heritage/layout.dart';
import 'package:heritage/photo_management.dart';
import 'package:heritage/profile_display.dart';
import 'package:heritage/profile_update.dart';
import 'package:heritage/util.dart';

const _kMinPanelHeight = 240.0;

class Panels extends ConsumerStatefulWidget {
  final Person? selectedPerson;
  final Relatedness? relatedness;
  final Person focalPerson;
  final ViewHistory viewHistory;
  final PanelPopupState panelPopupState;
  final VoidCallback onDismissPanelPopup;
  final void Function(Relationship relationship) onAddConnectionPressed;
  final void Function(Id id) onSelectPerson;
  final VoidCallback onViewPerspective;
  final void Function(Rect rect) onViewRectUpdated;

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
    required this.onViewPerspective,
    required this.onViewRectUpdated,
  });

  @override
  ConsumerState<Panels> createState() => _PanelsState();
}

class _PanelsState extends ConsumerState<Panels> {
  bool _hadInitialLayout = false;
  late LayoutType _layout;
  final _modalKey = GlobalKey();

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
        selectedPerson?.id == widget.viewHistory.primaryUserId;
    final isOwnedByPrimaryUser = isPrimaryUser ||
        selectedPerson?.ownedBy == widget.viewHistory.primaryUserId;
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      '${widget.focalPerson.profile.firstName}\'s perspective',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: _MenuButtons(
              onHomePressed: _goHome,
            ),
          ),
          Positioned.fill(
            child: _DismissWhenNull(
              selectedPerson: selectedPerson,
              relatedness: relatedness,
              builder: (context, selectedPerson, relatedness) {
                return _DraggableSheet(
                  selectedPerson: selectedPerson,
                  relatedness: relatedness,
                  isPrimaryUser: isPrimaryUser,
                  isOwnedByMe: isOwnedByPrimaryUser,
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
                );
              },
            ),
          )
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        '${widget.focalPerson.profile.firstName}\'s perspective',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: 24,
            child: _MenuButtons(
              onHomePressed: _goHome,
            ),
          ),
          Positioned(
            top: 100,
            left: 24,
            width: 390,
            bottom: 144,
            child: Align(
              alignment: Alignment.centerLeft,
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
                            isPrimaryUser: isPrimaryUser,
                          ),
                          ProfileDisplay(
                            initialProfile: person.profile,
                            isPrimaryUser: isPrimaryUser,
                            isEditable: isOwnedByPrimaryUser,
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
                            onSave: (update) async {
                              final notifier = ref.read(graphProvider.notifier);
                              await showBlockingModal(
                                context,
                                notifier.updateProfile(person.id, update),
                              );
                              if (context.mounted) {
                                showProfileUpdateSuccess(context: context);
                                widget.onDismissPanelPopup();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  PanelPopupStateAddConnection(
                    :final person,
                    :final relationship
                  ) =>
                    _SidePanelContainer(
                      key: Key('connection_${relationship.name}'),
                      child: AddConnectionDisplay(
                        relationship: relationship,
                        onSave:
                            (firstName, lastName, gender, takeOwnership) async {
                          await _saveNewConnection(firstName, lastName, gender,
                              person, relationship);
                          if (mounted) {
                            widget.onDismissPanelPopup();
                          }
                        },
                      ),
                    ),
                  PanelPopupStateWaitingForApproval(:final person) =>
                    _SidePanelContainer(
                      key: Key('approval_${person.id}'),
                      child: WaitingForApprovalDisplay(
                        person: person,
                        onAddConnectionPressed: null,
                        onSaveAndShare: (firstName, lastName, gender) async {
                          await _onSaveAndShare(
                              person.id, firstName, lastName, gender);
                          if (mounted) {
                            widget.onDismissPanelPopup();
                          }
                        },
                        onTakeOwnership: _takeOwnership,
                      ),
                    ),
                },
              ),
            ),
          ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: buildAddConnectionButtons(
                            person: selectedPerson,
                            relatedness: relatedness,
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
            // TODO: Possibly declaratively dismiss popup
            break;
          case PanelPopupStateProfile():
            // Displayed in build() by bottom panel
            break;
          case PanelPopupStateAddConnection(:final person, :final relationship):
            WidgetsBinding.instance.endOfFrame.then((_) {
              if (mounted) {
                _showAddConnectionModal(person, relationship);
              }
            });
          case PanelPopupStateWaitingForApproval(
              :final person,
              :final relatedness
            ):
            final owned = person.ownedBy != null;
            if (owned) {
              return;
            }
            WidgetsBinding.instance.endOfFrame.then((_) {
              if (mounted) {
                _showOwnershipModal(
                  person: person,
                  onAddConnectionPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: buildAddConnectionButtons(
                            person: person,
                            relatedness: relatedness,
                            paddingWidth: 16,
                            onAddConnectionPressed: (relationship) {
                              Navigator.of(context).pop();
                              widget.onAddConnectionPressed(relationship);
                            },
                          ),
                        );
                      },
                    );
                  },
                );
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

  void _showOwnershipModal({
    required Person person,
    required VoidCallback onAddConnectionPressed,
  }) async {
    final shouldDismiss = await showScrollableModalBottomSheet<bool>(
      context: context,
      builder: (context) {
        return WaitingForApprovalDisplay(
          key: _modalKey,
          person: person,
          onAddConnectionPressed: () {
            Navigator.of(context).pop(true);
            onAddConnectionPressed();
          },
          onSaveAndShare: (firstName, lastName, gender) async {
            await _onSaveAndShare(person.id, firstName, lastName, gender);
            if (context.mounted) {
              Navigator.of(context).pop(true);
            }
          },
          onTakeOwnership: () {
            Navigator.of(context).pop();
            _takeOwnership();
          },
        );
      },
    );
    if (mounted && shouldDismiss == true) {
      widget.onDismissPanelPopup();
    }
  }

  void _showAddConnectionModal(Person person, Relationship relationship) async {
    final shouldDismiss = await showScrollableModalBottomSheet<bool>(
      context: context,
      builder: (context) {
        return AddConnectionDisplay(
          relationship: relationship,
          onSave: (firstName, lastName, gender, takeOwnership) async {
            await _saveNewConnection(
                firstName, lastName, gender, person, relationship);
            if (context.mounted) {
              Navigator.of(context).pop(true);
            }
          },
        );
      },
    );
    if (mounted && shouldDismiss == true) {
      widget.onDismissPanelPopup();
    }
  }

  Future<void> _saveNewConnection(String firstName, String lastName,
      Gender gender, Person person, Relationship relationship) async {
    final graphNotifier = ref.read(graphProvider.notifier);
    final addConnectionFuture = graphNotifier.addConnection(
      source: person.id,
      firstName: firstName,
      lastName: lastName,
      gender: gender,
      relationship: relationship,
    );
    final newId = await showBlockingModal(context, addConnectionFuture);
    if (!mounted) {
      return;
    }
    if (newId != null) {
      final type = await shareInvite(firstName, newId);
      if (!mounted) {
        return;
      }
      showProfileUpdateSuccess(context: context);
    }
  }

  Future<void> _onSaveAndShare(
      Id id, String firstName, String lastName, Gender gender) async {
    final graph = ref.read(graphProvider);
    final person = graph.people[id];
    if (person == null) {
      return;
    }
    if (person.profile.firstName != firstName ||
        person.profile.lastName != lastName ||
        person.profile.gender != gender) {
      final graphNotifier = ref.read(graphProvider.notifier);
      final updateFuture = graphNotifier.updateProfile(
        id,
        person.profile.copyWith(
          firstName: firstName,
          lastName: lastName,
          gender: gender,
        ),
      );
      await showBlockingModal(context, updateFuture);
      if (!mounted) {
        return;
      }
    }

    final type = await shareInvite(firstName, id);
    if (!mounted) {
      return;
    }
    showProfileUpdateSuccess(context: context);
  }

  void _takeOwnership() async {
    final selectedPerson = widget.selectedPerson;
    final relatedness = widget.relatedness;
    if (selectedPerson != null && relatedness != null) {
      final ownershipFuture =
          ref.read(graphProvider.notifier).takeOwnership(selectedPerson.id);
      await showBlockingModal(context, ownershipFuture);
      // Wait for graph to update
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) {
        widget.onSelectPerson(selectedPerson.id);
      }
    }
  }

  void _goHome() {
    if (widget.viewHistory.perspectiveUserId != null) {
      context.goNamed(
        'view',
        extra: ViewHistory(primaryUserId: widget.viewHistory.primaryUserId),
      );
    } else {
      context.goNamed('menu');
    }
  }
}

Future<T?> showScrollableModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
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
  required double paddingWidth,
  required void Function(Relationship relationship) onAddConnectionPressed,
}) {
  return AddConnectionButtons(
    enabled: relatedness.isBloodRelative,
    paddingWidth: paddingWidth,
    canAddParent: person.parents.isEmpty,
    canAddChildren:
        relatedness.isAncestor || !relatedness.isGrandparentLevelOrHigher,
    onAddConnectionPressed: onAddConnectionPressed,
  );
}

class _DismissWhenNull extends StatefulWidget {
  final Person? selectedPerson;
  final Relatedness? relatedness;
  final Widget Function(
          BuildContext context, Person selectedPerson, Relatedness relatedness)
      builder;

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

  @override
  void initState() {
    super.initState();
    _selectedPerson = widget.selectedPerson;
    _relatedness = widget.relatedness;
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
        _controller.forward();
      }
    }
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
            return widget.builder(context, selectedPerson, relatedness);
          },
        ),
      ),
    );
  }
}

class _DraggableSheet extends StatefulWidget {
  final Person selectedPerson;
  final Relatedness relatedness;
  final bool isPrimaryUser;
  final bool isOwnedByMe;
  final void Function(Relationship relationship) onAddConnectionPressed;
  final VoidCallback onDismissPanelPopup;
  final VoidCallback? onViewPerspective;

  const _DraggableSheet({
    super.key,
    required this.selectedPerson,
    required this.relatedness,
    required this.isPrimaryUser,
    required this.isOwnedByMe,
    required this.onAddConnectionPressed,
    required this.onDismissPanelPopup,
    required this.onViewPerspective,
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
    final maxPanelHeight = windowSize.height - 10.0;
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
                  PinnedHeaderSliver(
                    child: ColoredBox(
                      color: Colors.white,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                  'Invite a...',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: buildAddConnectionButtons(
                                    person: widget.selectedPerson,
                                    relatedness: widget.relatedness,
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
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ProfileNameSection(
                        person: widget.selectedPerson,
                        relatedness: widget.relatedness,
                        isPrimaryUser: widget.isPrimaryUser,
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
                            isPrimaryUser: widget.isPrimaryUser,
                            isEditable: widget.isOwnedByMe,
                            hasDifferentOwner: widget.selectedPerson.ownedBy !=
                                widget.selectedPerson.id,
                            onViewPerspective: widget.onViewPerspective,
                            onSave: (update) async {
                              final notifier = ref.read(graphProvider.notifier);
                              await showBlockingModal(
                                context,
                                notifier.updateProfile(
                                    widget.selectedPerson.id, update),
                              );
                              if (context.mounted) {
                                showProfileUpdateSuccess(context: context);
                                _draggableScrollableController.animateTo(
                                  minPanelRatio,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                                widget.onDismissPanelPopup();
                              }
                            },
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

class _MenuButtons extends StatelessWidget {
  final VoidCallback onHomePressed;

  const _MenuButtons({
    super.key,
    required this.onHomePressed,
  });

  @override
  Widget build(BuildContext context) {
    const decoration = BoxDecoration(
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: decoration,
          child: FilledButton(
            onPressed: onHomePressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size.square(48),
              foregroundColor: Colors.black,
              backgroundColor: Colors.white,
            ),
            child: const Icon(
              Icons.home_filled,
            ),
          ),
        ),
        const SizedBox(width: 16),
        DecoratedBox(
          decoration: decoration,
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
                  Text(
                    person.profile.fullName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Text('My profile'),
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
                          'Tarlok\'s Sister\'s Husband',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  color: const Color.fromRGBO(
                                      0x7A, 0x7A, 0x7A, 1.0)),
                        ),
                      ),
                      Text(
                        'Verified by Parteek',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                                color: const Color.fromRGBO(
                                    0x3F, 0x71, 0xFF, 1.0)),
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
  final bool hasDifferentOwner;
  final VoidCallback? onViewPerspective;
  final void Function(Profile profile) onSave;

  const ProfileDisplay({
    super.key,
    required this.initialProfile,
    required this.isPrimaryUser,
    required this.isEditable,
    required this.hasDifferentOwner,
    required this.onViewPerspective,
    required this.onSave,
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
        hasDifferentOwner: hasDifferentOwner,
        onViewPerspective: onViewPerspective,
        onSave: onSave,
      ),
    );
  }
}

class _ProfileDisplay extends ConsumerStatefulWidget {
  final bool isPrimaryUser;
  final bool isEditable;
  final bool hasDifferentOwner;
  final VoidCallback? onViewPerspective;
  final void Function(Profile profile) onSave;

  const _ProfileDisplay({
    super.key,
    required this.isPrimaryUser,
    required this.isEditable,
    required this.hasDifferentOwner,
    required this.onViewPerspective,
    required this.onSave,
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
    final deathday = profile.deathday;
    _firstNameController = TextEditingController(text: profile.firstName);
    _lastNameController = TextEditingController(text: profile.lastName);
    _birthdayController = TextEditingController();
    _deathdayController = TextEditingController(
        text: deathday == null ? '' : formatDate(deathday));
    _birthplaceController = TextEditingController(text: profile.birthplace);
    _occupationController = TextEditingController(text: profile.occupation);
    _hobbiesController = TextEditingController(text: profile.hobbies);

    ref.listenManual(
      profileUpdateProvider,
      fireImmediately: true,
      (previous, next) {
        final birthday = next.birthday;
        final deathday = next.deathday;
        _birthdayController.text = birthday == null ? '' : formatDate(birthday);
        _deathdayController.text = deathday == null ? '' : formatDate(deathday);
      },
    );
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
        Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              child: GalleryView(
                photos:
                    ref.watch(profileUpdateProvider.select((p) => p.gallery)),
              ),
            ),
            if (widget.isEditable) ...[
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: PhotoManagement(
                  gallery:
                      ref.watch(profileUpdateProvider.select((p) => p.gallery)),
                  onChanged: ref.read(profileUpdateProvider.notifier).gallery,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        if (widget.onViewPerspective != null) ...[
          FilledButton(
            onPressed: widget.onViewPerspective,
            style: FilledButton.styleFrom(
              fixedSize: const Size.fromHeight(48),
            ),
            child: Text(
                'View ${ref.watch(profileUpdateProvider.select((s) => s.firstName))}\'s tree'),
          ),
          const SizedBox(height: 24),
        ],
        Text(
          'Details',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        FocusTraversalGroup(
          child: InputForm(
            children: [
              InputLabel(
                label: 'First name',
                child: TextFormField(
                  controller: _firstNameController,
                  enabled: widget.isEditable,
                  onChanged: ref.read(profileUpdateProvider.notifier).firstName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                ),
              ),
              InputLabel(
                label: 'Last name',
                child: TextFormField(
                  controller: _lastNameController,
                  enabled: widget.isEditable,
                  onChanged: ref.read(profileUpdateProvider.notifier).lastName,
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
                        onChanged:
                            ref.read(profileUpdateProvider.notifier).birthday,
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
                              firstDate: DateTime(1500),
                              lastDate: DateTime.now(),
                              initialDate: ref.watch(profileUpdateProvider
                                  .select((p) => p.birthday ?? DateTime.now())),
                            );
                            if (!mounted || date == null) {
                              return;
                            }
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
                          onChanged:
                              ref.read(profileUpdateProvider.notifier).deathday,
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
                                firstDate: DateTime(1500),
                                lastDate: DateTime.now(),
                                initialDate: ref.watch(
                                    profileUpdateProvider.select(
                                        (p) => p.deathday ?? DateTime.now())),
                              );
                              if (!mounted || date == null) {
                                return;
                              }
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
                  onFieldSubmitted: (_) {},
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
                  onFieldSubmitted: (_) {},
                ),
              ),
              InputLabel(
                label: 'Hobbies',
                child: TextFormField(
                  controller: _hobbiesController,
                  enabled: widget.isEditable,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onChanged: ref.read(profileUpdateProvider.notifier).hobbies,
                  onFieldSubmitted: (_) {},
                ),
              ),
            ],
          ),
        ),
        if (widget.isEditable) ...[
          const SizedBox(height: 24),
          Text(
            'Gender',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Needed to list you properly in the tree',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final gender in Gender.values) ...[
                if (gender != Gender.values.first) const SizedBox(width: 16),
                Expanded(
                  child: Builder(builder: (context) {
                    final selectedGender = ref
                        .watch(profileUpdateProvider.select((p) => p.gender));
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
        const SizedBox(height: 16),
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
              // 'If $name can\'t loses access, direct relatives can share this link with them.\nShare this link with no one else.',
              'Visible to direct relatives for login assistance. Share this with $name, sharing it with others risks the family tree.',
              style: Theme.of(context).textTheme.labelLarge,
            );
          },
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () {},
          style: FilledButton.styleFrom(
            fixedSize: const Size.fromHeight(44),
            foregroundColor: Colors.white,
            backgroundColor: primaryColor,
          ),
          child: const Text(
            'Share Login Link',
          ),
        ),
        if (widget.isEditable) ...[
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete profile information from the tree'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => widget.onSave(ref.read(profileUpdateProvider)),
            style: FilledButton.styleFrom(
              fixedSize: const Size.fromHeight(73),
            ),
            child: const Text('Save'),
          ),
        ],
      ],
    );
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

class WaitingForApprovalDisplay extends StatefulWidget {
  final Person person;
  final VoidCallback? onAddConnectionPressed;
  final void Function(String firstName, String lastName, Gender gender)
      onSaveAndShare;
  final VoidCallback onTakeOwnership;

  const WaitingForApprovalDisplay({
    super.key,
    required this.person,
    required this.onAddConnectionPressed,
    required this.onSaveAndShare,
    required this.onTakeOwnership,
  });

  @override
  State<WaitingForApprovalDisplay> createState() =>
      _WaitingForApprovalDisplayState();
}

class _WaitingForApprovalDisplayState extends State<WaitingForApprovalDisplay> {
  late String _firstName = widget.person.profile.firstName;
  late String _lastName = widget.person.profile.lastName;
  late Gender _gender = widget.person.profile.gender;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invite\n$_firstName',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: Color.fromRGBO(0x3C, 0x3C, 0x3C, 1.0),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Share with $_firstName only, so they can verify their profile and join the tree',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: const Color.fromRGBO(0x51, 0x51, 0x51, 1.0)),
        ),
        const SizedBox(height: 8),
        ShareLinkButton(
          firstName: _firstName,
          onPressed: () =>
              widget.onSaveAndShare(_firstName, _lastName, _gender),
        ),
        const SizedBox(height: 24),
        const Divider(height: 1),
        const SizedBox(height: 24),
        MinimalProfileEditor(
          initialFirstName: widget.person.profile.firstName,
          initialLastName: widget.person.profile.lastName,
          initialGender: widget.person.profile.gender,
          onUpdate: (firstName, lastName, gender) {
            setState(() {
              _firstName = firstName;
              _lastName = lastName;
              _gender = gender;
            });
          },
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: (_firstName.isEmpty || _lastName.isEmpty)
                ? null
                : () async {
                    final takeOwnership = await showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Take ownership?'),
                          content: const Text(
                              '\nCompleting someone else\'s profile should only be done if they can\'t do it themself.\n\nExample: child or deceased'),
                          actions: [
                            TextButton(
                              onPressed: Navigator.of(context).pop,
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.black),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Proceed'),
                            ),
                          ],
                        );
                      },
                    );
                    if (takeOwnership == true) {
                      widget.onTakeOwnership();
                    }
                  },
            style: TextButton.styleFrom(
              foregroundColor: const Color.fromRGBO(0xB9, 0xB9, 0xB9, 1.0),
            ),
            child: const Text('I will complete this profile'),
          ),
        ),
        const SizedBox(height: 16),
        if (widget.onAddConnectionPressed == null)
          Center(
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: const Color.fromRGBO(0xFF, 0x00, 0x00, 1.0),
              ),
              child: const Text('Delete relative'),
            ),
          )
        else
          Row(
            children: [
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: const Color.fromRGBO(0xFF, 0x00, 0x00, 1.0),
                ),
                child: const Text('Delete relative'),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onAddConnectionPressed,
                child: const Text('Attach a relative'),
              ),
            ],
          ),
      ],
    );
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
  final Person person;
  final Relationship relationship;

  PanelPopupStateAddConnection({
    required this.person,
    required this.relationship,
  });

  @override
  int get hashCode => Object.hash(person, relationship);

  @override
  bool operator ==(Object other) {
    return other is PanelPopupStateAddConnection &&
        other.person == person &&
        other.relationship == relationship;
  }
}

class PanelPopupStateWaitingForApproval implements PanelPopupState {
  final Person person;
  final Relatedness relatedness;

  PanelPopupStateWaitingForApproval({
    required this.person,
    required this.relatedness,
  });

  @override
  int get hashCode => Object.hash(person, relatedness);

  @override
  bool operator ==(Object other) {
    return other is PanelPopupStateWaitingForApproval &&
        other.person == person &&
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

/// Allows all device kinds to scroll the scroll view
class _AllDevicesScrollBehavior extends ScrollBehavior {
  const _AllDevicesScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}
