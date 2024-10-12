import 'dart:math';
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heritage/api.dart';
import 'package:heritage/debouncer.dart';
import 'package:heritage/family_tree_page_panels.dart';
import 'package:heritage/graph.dart';
import 'package:heritage/graph_provider.dart';
import 'package:heritage/graph_view.dart';
import 'package:heritage/heritage_app.dart';
import 'package:heritage/loading_page.dart';
import 'package:heritage/onboarding_flow.dart';
import 'package:heritage/profile_display.dart';
import 'package:heritage/util.dart';
import 'package:heritage/zoomable_pannable_viewport.dart';
import 'package:lottie/lottie.dart';
import 'package:path_drawing/path_drawing.dart' as path_drawing;

class FamilyTreeLoadingPage extends ConsumerStatefulWidget {
  final bool isPerspectiveMode;
  final bool isInvite;
  final VoidCallback onReady;
  final VoidCallback onError;
  final Widget child;

  const FamilyTreeLoadingPage({
    super.key,
    required this.isPerspectiveMode,
    required this.isInvite,
    required this.onReady,
    required this.onError,
    required this.child,
  });

  @override
  ConsumerState<FamilyTreeLoadingPage> createState() =>
      FamilyTreeLoadingPageState();
}

class FamilyTreeLoadingPageState extends ConsumerState<FamilyTreeLoadingPage> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      hasPeopleProvider,
      (previous, next) {
        if (next) {
          WidgetsBinding.instance.endOfFrame.then((_) {
            if (mounted) {
              final focalPerson = ref.read(graphProvider).focalPerson;
              final isManagedUser = focalPerson.ownedBy != null &&
                  focalPerson.ownedBy != focalPerson.id;
              final isLoggingInAsManagedUser =
                  isManagedUser && !widget.isPerspectiveMode;
              final isInvitedToOwnedUser =
                  widget.isInvite && focalPerson.ownedBy != null;
              if (isLoggingInAsManagedUser || isInvitedToOwnedUser) {
                widget.onError();
              } else {
                widget.onReady();
                setState(() => _ready = true);
              }
            }
          });
        }
      },
    );

    ref.listenManual(
      hasPeopleErrorProvider,
      (previous, next) {
        if (next) {
          WidgetsBinding.instance.endOfFrame.then((_) {
            if (mounted) {
              widget.onError();
            }
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: !_ready ? const LoadingPage() : widget.child,
      ),
    );
  }
}

class FamilyTreePage extends ConsumerStatefulWidget {
  final Id? referrerId;
  final ViewHistory viewHistory;

  const FamilyTreePage({
    super.key,
    this.referrerId,
    required this.viewHistory,
  });

  @override
  ConsumerState<FamilyTreePage> createState() => _FamilyTreePageState();
}

class _FamilyTreePageState extends ConsumerState<FamilyTreePage> {
  final _familyTreeViewKey = GlobalKey<FamilyTreeViewState>();
  Person? _selectedPerson;
  Relatedness? _relatedness;
  PanelPopupState _panelPopupState = const PanelPopupStateNone();
  final _viewRectNotifier = ValueNotifier(Rect.zero);

  final _savingNotifier = ValueNotifier<Id?>(null);
  final _debouncer = Debouncer(
    delay: const Duration(seconds: 2),
  );

  @override
  void initState() {
    super.initState();
    _maybeOnboard();
  }

  @override
  void dispose() {
    _debouncer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final graph = ref.watch(graphProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        FamilyTreeView(
          key: _familyTreeViewKey,
          focalPerson: graph.focalPerson,
          people: graph.people.values.toList(),
          viewHistory: widget.viewHistory,
          selectedPerson: _selectedPerson,
          viewRectNotifier: _viewRectNotifier,
          onProfileSelected: _onProfileSelected,
          onDismissSelected: _onDismissSelected,
        ),
        Panels(
          selectedPerson: _selectedPerson,
          relatedness: _relatedness,
          focalPerson: graph.focalPerson,
          viewHistory: widget.viewHistory,
          panelPopupState: _panelPopupState,
          onDismissPanelPopup: _onDismissSelected,
          onAddConnectionPressed: (relationship) async {
            final selectedPerson = _selectedPerson;
            if (selectedPerson == null) {
              return;
            }
            final graphNotifier = ref.read(graphProvider.notifier);
            final addConnectionFuture = graphNotifier.addConnection(
              source: selectedPerson.id,
              relationship: relationship,
            );
            final newId = await showBlockingModal(context, addConnectionFuture);
            if (!mounted) {
              return;
            }

            if (newId != null) {
              // Wait for node to be added to graph
              WidgetsBinding.instance.endOfFrame.then((_) {
                if (!mounted) {
                  return;
                }
                final focalNode = _familyTreeViewKey.currentState
                    ?.linkedNodeForId(graph.focalPerson.id);
                final targetNode =
                    _familyTreeViewKey.currentState?.linkedNodeForId(newId);
                if (focalNode == null || targetNode == null) {
                  return;
                }

                _selectPerson(newId);
                final linkedNode = targetNode;
                setState(() {
                  _selectedPerson = targetNode.data;
                  _relatedness = Relatedness(
                    isBloodRelative: linkedNode.isBloodRelative,
                    isDirectRelativeOrSpouse:
                        linkedNode.isDirectRelativeOrSpouse,
                    isAncestor: linkedNode.isAncestor,
                    isSibling: linkedNode.isSibling,
                    relativeLevel: linkedNode.relativeLevel,
                    description: relatednessDescription(
                      focalNode,
                      linkedNode,
                      pov: PointOfView.first,
                    ),
                  );
                  _panelPopupState = PanelPopupStateAddConnection(
                    targetNode: targetNode,
                    focalNode: focalNode,
                    relationship: relationship,
                  );
                });
              });
            }
          },
          onSelectPerson: _selectPerson,
          onShare: () async {
            final selectedPerson = _selectedPerson;
            if (selectedPerson == null) {
              return;
            }
            final focalNode = _familyTreeViewKey.currentState
                ?.linkedNodeForId(graph.focalPerson.id);
            final targetNode = _familyTreeViewKey.currentState
                ?.linkedNodeForId(selectedPerson.id);
            if (focalNode == null || targetNode == null) {
              return;
            }
            await shareInvite(
              targetId: selectedPerson.id,
              targetName: targetNode.data.profile.firstName,
              focalName: focalNode.data.profile.firstName,
              referrerId: graph.focalPerson.id,
            );
            if (mounted) {
              _onDismissSelected();
            }
          },
          onTakeOwnership: () async {
            final selectedPerson = _selectedPerson;
            final relatedness = _relatedness;
            if (selectedPerson != null && relatedness != null) {
              _showManagePersonFlow(selectedPerson.id);
            }
          },
          onViewPerspective: () {
            final selectedPerson = _selectedPerson;
            if (selectedPerson == null) {
              return;
            }
            _onDismissSelected();
            context.goNamed(
              'view',
              extra: ViewHistory(
                primaryUserId: widget.viewHistory.primaryUserId,
                perspectiveUserId: selectedPerson.id,
              ),
            );
          },
          onViewRectUpdated: (rect) => _viewRectNotifier.value = rect,
          onRecenter: () => _familyTreeViewKey.currentState
              ?.centerOnPersonWithId(graph.focalPerson.id),
          onSaveProfile: _onDebounceAutosave,
        ),
        Positioned(
          top: 32,
          right: 16,
          width: 48,
          height: 128,
          child: ValueListenableBuilder(
            valueListenable: _savingNotifier,
            builder: (context, saving, child) {
              return AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: saving != null ? 1.0 : 0.0,
                child: child,
              );
            },
            child: Lottie.asset(
              'assets/images/logo.json',
            ),
          ),
        ),
      ],
    );
  }

  void _selectPerson(Id id) {
    final graph = ref.read(graphProvider);
    final focalNode =
        _familyTreeViewKey.currentState?.linkedNodeForId(graph.focalPerson.id);
    final selectedNode = _familyTreeViewKey.currentState?.linkedNodeForId(id);
    if (focalNode == null || selectedNode == null) {
      return;
    }

    final person = selectedNode.data;
    final relatedness = Relatedness(
      isBloodRelative: selectedNode.isBloodRelative,
      isDirectRelativeOrSpouse: selectedNode.isDirectRelativeOrSpouse,
      isAncestor: selectedNode.isAncestor,
      isSibling: selectedNode.isSibling,
      relativeLevel: selectedNode.relativeLevel,
      description: relatednessDescription(
        focalNode,
        selectedNode,
        pov: PointOfView.first,
      ),
    );
    _onProfileSelected(person, relatedness);
  }

  void _onProfileSelected(Person person, Relatedness relatedness) async {
    // Don't open profiles that are in the middle of saving
    if (_savingNotifier.value == person.id) {
      return;
    }

    _familyTreeViewKey.currentState?.centerOnPersonWithId(person.id);

    final graph = ref.read(graphProvider);
    final focalNode =
        _familyTreeViewKey.currentState?.linkedNodeForId(graph.focalPerson.id);
    final targetNode =
        _familyTreeViewKey.currentState?.linkedNodeForId(person.id);

    if (focalNode != null &&
        targetNode != null &&
        targetNode.data.ownedBy == null) {
      final notifier = ref.read(graphProvider.notifier);
      notifier.addInvite(focalNode, targetNode);
    }

    if (person.ownedBy == null) {
      if (focalNode == null || targetNode == null) {
        return;
      }
      setState(() {
        _selectedPerson = person;
        _relatedness = relatedness;
        _panelPopupState = PanelPopupStatePendingProfile(
            targetNode: targetNode,
            focalNode: focalNode,
            relatedness: relatedness);
      });
    } else {
      setState(() {
        _selectedPerson = person;
        _relatedness = relatedness;
        _panelPopupState =
            PanelPopupStateProfile(person: person, relatedness: relatedness);
      });
    }
  }

  void _onDismissSelected() {
    // Force any pending auto save
    _debouncer.flush();

    final selectedPerson = _selectedPerson;
    if (selectedPerson != null) {
      if (selectedPerson.ownedBy == null) {
        // TODO: Maybe delete here
      }
    }

    setState(() {
      _panelPopupState = const PanelPopupStateNone();
      _selectedPerson = null;
      _relatedness = null;
    });
  }

  void _onDebounceAutosave(Profile update) {
    final selectedPersonId = _selectedPerson?.id;
    if (selectedPersonId != null) {
      _debouncer.afterDelay(() {
        _applyProfileUpdate(selectedPersonId, update);
      });
    }
  }

  void _applyProfileUpdate(Id id, Profile update) async {
    // Desktop
    final notifier = ref.read(graphProvider.notifier);
    _savingNotifier.value = id;
    await notifier.updateProfile(id, update);
    if (mounted) {
      _savingNotifier.value = null;
    }
  }

  void _maybeOnboard() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }

    final graph = ref.read(graphProvider);
    final focalPersonId = graph.focalPerson.id;
    final referrerId = widget.referrerId;
    if (referrerId == null) {
      return;
    }
    final notifier = ref.read(graphProvider.notifier);
    final nodes = graph.people.values.toList();
    final linkedNodes = buildLinkedTree(nodes, referrerId);
    final focalPerson = linkedNodes[focalPersonId];
    final referrer = linkedNodes[referrerId];
    if (focalPerson == null || referrer == null) {
      return;
    }

    final isPerspectiveMode = widget.viewHistory.perspectiveUserId != null;
    final needsOnboarding = focalPerson.data.ownedBy == null;
    if (isPerspectiveMode || !needsOnboarding) {
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return OnboardingFlow(
          person: focalPerson,
          referral: referrer,
          onSave: (profile) async {
            await notifier.takeOwnership(focalPersonId);
            await notifier.updateProfile(focalPerson.id, profile);
          },
          onDone: Navigator.of(context).pop,
        );
      },
    );
    if (mounted) {
      _selectPerson(focalPersonId);
    }
  }

  void _showManagePersonFlow(Id targetId) async {
    final graph = ref.read(graphProvider);
    final focalPersonId = graph.focalPerson.id;
    final notifier = ref.read(graphProvider.notifier);
    final nodes = graph.people.values.toList();
    final linkedNodes = buildLinkedTree(nodes, focalPersonId);
    final focalPerson = linkedNodes[focalPersonId];
    final targetPerson = linkedNodes[targetId];
    if (focalPerson == null || targetPerson == null) {
      return;
    }

    final description = relatednessDescription(
      focalPerson,
      targetPerson,
      pov: PointOfView.first,
      capitalizeWords: true,
    );
    _onDismissSelected();
    await showDialog(
      context: context,
      builder: (context) {
        return ManagePersonFlow(
          targetPerson: targetPerson,
          description: description,
          onSave: (profile) async {
            await notifier.takeOwnership(targetId);
            await notifier.updateProfile(targetId, profile);
          },
          onDone: Navigator.of(context).pop,
        );
      },
    );

    if (!mounted) {
      return;
    }

    // Wait for node to be added to graph
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) {
      return;
    }
    _selectPerson(targetId);
  }
}

class FamilyTreeView extends ConsumerStatefulWidget {
  final Person focalPerson;
  final List<Person> people;
  final Person? selectedPerson;
  final ViewHistory viewHistory;
  final ValueNotifier<Rect> viewRectNotifier;
  final void Function(Person person, Relatedness relatedness) onProfileSelected;
  final VoidCallback onDismissSelected;

  const FamilyTreeView({
    super.key,
    required this.focalPerson,
    required this.people,
    required this.selectedPerson,
    required this.viewHistory,
    required this.viewRectNotifier,
    required this.onProfileSelected,
    required this.onDismissSelected,
  });

  @override
  ConsumerState<FamilyTreeView> createState() => FamilyTreeViewState();
}

class FamilyTreeViewState extends ConsumerState<FamilyTreeView> {
  final _viewportKey = GlobalKey<ZoomablePannableViewportState>();
  final _transformNotifier = ValueNotifier<Matrix4>(Matrix4.identity());
  bool _ready = false;
  final _idToKey = <Id, GlobalKey>{};
  final _nodeKeys = <(Person, GlobalKey)>[];
  late GlobalKey<GraphViewState<Person>> _graphKey;

  @override
  void initState() {
    super.initState();
    _reinitKeys();
    // Until two frames pass it seems we can't locate the nodes on screen
    WidgetsBinding.instance.endOfFrame.then((_) {
      WidgetsBinding.instance.endOfFrame.then((_) {
        if (mounted) {
          centerOnPersonWithId(widget.focalPerson.id, animate: false);
          setState(() => _ready = true);
        }
      });
    });

    widget.viewRectNotifier.addListener(_onViewRectUpdated);
  }

  @override
  void didUpdateWidget(covariant FamilyTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    const unordered = DeepCollectionEquality.unordered();
    if (!unordered.equals(oldWidget.people, widget.people)) {
      _reinitKeys();
    }
  }

  void _reinitKeys() {
    _graphKey = GlobalKey();
    _nodeKeys
      ..clear()
      ..addAll(widget.people.map(((e) => (e, GlobalKey()))));
    _idToKey
      ..clear()
      ..addEntries(
        _nodeKeys.map((e) => MapEntry(e.$1.id, e.$2)),
      );
  }

  @override
  void dispose() {
    _transformNotifier.dispose();
    widget.viewRectNotifier.removeListener(_onViewRectUpdated);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const spacing = Spacing(
      level: 240,
      spouse: 30,
      sibling: 70,
    );
    return Center(
      child: Overlay.wrap(
        child: Opacity(
          opacity: _ready ? 1.0 : 0.0,
          child: Stack(
            children: [
              _TiledBackground(
                transformNotifier: _transformNotifier,
                tint: widget.viewHistory.perspectiveUserId != null
                    ? const Color.fromRGBO(0xFF, 0x00, 0x00, 0.05)
                    : null,
                child: ZoomablePannableViewport(
                  key: _viewportKey,
                  onTransformed: (transform) =>
                      _transformNotifier.value = transform,
                  onStartInteraction: () {
                    if (widget.selectedPerson != null) {
                      widget.onDismissSelected();
                    }
                  },
                  child: GraphView<Person>(
                    key: _graphKey,
                    focalNodeId: widget.focalPerson.id,
                    nodeKeys: _nodeKeys,
                    spacing: spacing,
                    builder: (context, nodes, child) {
                      return Stack(
                        children: [
                          ValueListenableBuilder(
                            valueListenable: _transformNotifier,
                            builder: (context, value, _) {
                              return Edges(
                                idToKey: _idToKey,
                                idToNode: nodes,
                                focalPersonId: widget.focalPerson.id,
                                isPrimaryPerson:
                                    widget.viewHistory.perspectiveUserId ==
                                        null,
                                spacing: spacing,
                                transform: value,
                                child: child,
                              );
                            },
                          ),
                        ],
                      );
                    },
                    nodeBuilder: (context, data, node, key) {
                      final isGhost =
                          widget.viewHistory.perspectiveUserId != null &&
                              data.ownedBy == null;
                      final isSelectedPerson = widget.selectedPerson == null ||
                          widget.selectedPerson?.id == data.id;
                      final enabled = isSelectedPerson && !isGhost;
                      final canViewPerspectiveBool = canViewPerspective(
                        id: data.id,
                        primaryUserId: widget.viewHistory.primaryUserId,
                        focalPersonId: widget.focalPerson.id,
                        isSibling: node.isSibling,
                        isOwned: data.ownedBy != null,
                      );
                      final focalNode = _graphKey.currentState
                          ?.linkedNodeForId(widget.focalPerson.id);
                      final relatedness = Relatedness(
                        isBloodRelative: node.isBloodRelative,
                        isDirectRelativeOrSpouse: node.isDirectRelativeOrSpouse,
                        isAncestor: node.isAncestor,
                        isSibling: node.isSibling,
                        relativeLevel: node.relativeLevel,
                        description: focalNode == null
                            ? ''
                            : relatednessDescription(
                                focalNode,
                                node,
                                pov:
                                    widget.viewHistory.perspectiveUserId == null
                                        ? PointOfView.first
                                        : PointOfView.third,
                                capitalizeWords: true,
                              ),
                      );
                      return HoverableNodeProfile(
                        key: key,
                        person: data,
                        enabled: enabled,
                        forceHover: widget.selectedPerson?.id == data.id,
                        builder: (context, overlaying) {
                          return Opacity(
                            opacity: isGhost ? 0.4 : 1.0,
                            child: MouseRegion(
                              cursor: enabled
                                  ? SystemMouseCursors.click
                                  : MouseCursor.defer,
                              child: GestureDetector(
                                onTap: !enabled
                                    ? null
                                    : () {
                                        widget.onProfileSelected(
                                            data, relatedness);
                                      },
                                child: NodeProfile(
                                  person: data,
                                  relatednessDescription:
                                      relatedness.description,
                                  showViewPerspective: canViewPerspectiveBool,
                                  onViewPerspectivePressed: () {
                                    widget.onDismissSelected();
                                    context.pushNamed(
                                      'view',
                                      extra: ViewHistory(
                                        primaryUserId:
                                            widget.viewHistory.primaryUserId,
                                        perspectiveUserId: data.id,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: widget.selectedPerson == null ? 0.0 : 1.0,
                  child: const IgnorePointer(
                    child: ColoredBox(
                      color: Color.fromRGBO(0x00, 0x00, 0x00, 0.8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onViewRectUpdated() {
    final selectedPersonId = widget.selectedPerson?.id;
    if (selectedPersonId != null) {
      centerOnPersonWithId(selectedPersonId, animate: false);
    }
  }

  void centerOnPersonWithId(
    Id id, {
    bool animate = true,
  }) {
    final key = _idToKey[id];
    if (key != null) {
      _viewportKey.currentState?.centerOnWidgetWithKey(
        key,
        animate: animate,
        viewRect: widget.viewRectNotifier.value,
      );
    }
  }

  LinkedNode<Person>? linkedNodeForId(Id id) =>
      _graphKey.currentState?.linkedNodeForId(id);
}

class HoverableNodeProfile extends StatelessWidget {
  final Person person;
  final bool enabled;
  final bool forceHover;
  final Widget Function(BuildContext context, bool overlaying) builder;

  const HoverableNodeProfile({
    super.key,
    required this.person,
    this.enabled = true,
    this.forceHover = false,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return MouseOverlay(
      enabled: enabled,
      forceOverlay: forceHover,
      builder: builder,
    );
  }
}

class _TiledBackground extends StatefulWidget {
  final ValueNotifier<Matrix4> transformNotifier;
  final Color? tint;
  final Widget child;

  const _TiledBackground({
    super.key,
    required this.transformNotifier,
    required this.tint,
    required this.child,
  });

  @override
  State<_TiledBackground> createState() => _TiledBackgroundState();
}

class _TiledBackgroundState extends State<_TiledBackground> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _initImage();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: widget.transformNotifier,
      builder: (context, child) {
        return CustomPaint(
          painter: _TilePainter(
            tile: image,
            tint: widget.tint,
            transform: widget.transformNotifier.value,
          ),
          isComplex: true,
          child: widget.child,
        );
      },
    );
  }

  void _initImage() async {
    final bytes = await rootBundle.load('assets/images/tree_background.png');
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List(),
        targetHeight: 300);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    if (mounted) {
      setState(() => _image = image.clone());
    }
    image.dispose();
  }
}

class _TilePainter extends CustomPainter {
  final ui.Image tile;
  final Color? tint;
  final Matrix4 transform;

  _TilePainter({
    required this.tile,
    required this.tint,
    required this.transform,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final translate = transform.getTranslation();
    final scale = transform.getMaxScaleOnAxis();
    final scaledTileWidth = (tile.width * scale).floor();
    final scaledTileHeight = (tile.height * scale).floor();
    final canvasTransform = Matrix4.identity()
      ..translate((translate.x % scaledTileWidth).floorToDouble(),
          (translate.y % scaledTileHeight).floorToDouble())
      ..scale(scale);
    canvas.transform(canvasTransform.storage);
    final scaledCanvasSize = size / scale;
    final countWidth = scaledCanvasSize.width ~/ tile.width + 1;
    final countHeight = scaledCanvasSize.height ~/ tile.height + 1;
    for (var y = -1; y < countHeight; y++) {
      for (var x = -1; x < countWidth; x++) {
        final offset =
            Offset(x * tile.width.toDouble(), y * tile.height.toDouble());
        canvas.drawImage(
          tile,
          offset,
          Paint()
            ..filterQuality = ui.FilterQuality.high
            ..colorFilter = tint == null
                ? null
                : ColorFilter.mode(tint!, BlendMode.srcOver),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TilePainter oldDelegate) =>
      !tile.isCloneOf(oldDelegate.tile) ||
      transform != oldDelegate.transform ||
      oldDelegate.tint != tint;
}

class CreateRootDisplay extends ConsumerStatefulWidget {
  final EdgeInsets padding;
  final void Function(String firstName, String lastName) onDone;

  const CreateRootDisplay({
    super.key,
    required this.padding,
    required this.onDone,
  });

  @override
  ConsumerState<CreateRootDisplay> createState() => _CreateRootDisplayState();
}

class _CreateRootDisplayState extends ConsumerState<CreateRootDisplay> {
  String _firstName = '';
  String _lastName = '';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: widget.padding.left,
        right: widget.padding.right,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          MinimalProfileEditor(
            onUpdate: (firstName, lastName) {
              setState(() {
                _firstName = firstName;
                _lastName = lastName;
              });
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed:
                  (_firstName.isEmpty || _lastName.isEmpty) ? null : _done,
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  void _done() {
    if (_firstName.isEmpty || _lastName.isEmpty) {
      return;
    }
    widget.onDone(_firstName, _lastName);
  }
}

class MinimalProfileEditor extends StatefulWidget {
  final String? initialFirstName;
  final String? initialLastName;
  final void Function(String firstName, String lastName) onUpdate;

  const MinimalProfileEditor({
    super.key,
    this.initialFirstName,
    this.initialLastName,
    required this.onUpdate,
  });

  @override
  State<MinimalProfileEditor> createState() => _MinimalProfileEditorState();
}

class _MinimalProfileEditorState extends State<MinimalProfileEditor> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;

  @override
  void initState() {
    super.initState();
    _firstNameController =
        TextEditingController(text: widget.initialFirstName ?? '');
    _lastNameController =
        TextEditingController(text: widget.initialLastName ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InputForm(
      children: [
        InputLabel(
          label: 'First name',
          child: TextFormField(
            controller: _firstNameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onChanged: (text) =>
                widget.onUpdate(text.trim(), _lastNameController.text.trim()),
          ),
        ),
        InputLabel(
          label: 'Last name',
          child: TextFormField(
            controller: _lastNameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onChanged: (text) =>
                widget.onUpdate(_firstNameController.text.trim(), text.trim()),
          ),
        ),
      ],
    );
  }
}

class Edges extends StatefulWidget {
  final Map<Id, GlobalKey> idToKey;
  final Map<Id, LinkedNode<Person>> idToNode;
  final Id focalPersonId;
  final bool isPrimaryPerson;
  final Spacing spacing;
  final Matrix4 transform;
  final Widget child;

  const Edges({
    super.key,
    required this.idToKey,
    required this.idToNode,
    required this.focalPersonId,
    required this.isPrimaryPerson,
    required this.spacing,
    required this.transform,
    required this.child,
  });

  @override
  State<Edges> createState() => _EdgesState();
}

class _EdgesState extends State<Edges> {
  final _nodeRects = <Id, (LinkedNode<Person>, Rect)>{};
  final _parentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (!mounted) {
        return;
      }
      _locateNodes();
    });
  }

  @override
  void didUpdateWidget(covariant Edges oldWidget) {
    super.didUpdateWidget(oldWidget);
    const unordered = DeepCollectionEquality.unordered();
    if (oldWidget.spacing != widget.spacing ||
        oldWidget.transform != widget.transform ||
        !unordered.equals(oldWidget.idToKey, widget.idToKey) ||
        !unordered.equals(oldWidget.idToNode, widget.idToNode)) {
      _locateNodes();
    }
  }

  void _locateNodes() {
    final parentRect = locateWidget(_parentKey) ?? Rect.zero;
    final scale = widget.transform.getMaxScaleOnAxis();
    setState(() {
      for (final entry in widget.idToKey.entries) {
        final (id, key) = (entry.key, entry.value);
        final originalRect = locateWidget(key) ?? Rect.zero;
        final nodeRect = Rect.fromLTWH(
          (originalRect.left - parentRect.left) / scale,
          (originalRect.top - parentRect.top) / scale,
          originalRect.width,
          originalRect.height,
        );

        final node = widget.idToNode[id];
        if (node == null) {
          throw 'Missing node';
        }
        _nodeRects[id] = (node, nodeRect);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: _parentKey,
      painter: _EdgePainter(
        focalPerson: widget.idToNode[widget.focalPersonId],
        isPrimaryPerson: widget.isPrimaryPerson,
        nodeRects: Map.of(_nodeRects),
        spacing: widget.spacing,
      ),
      child: widget.child,
    );
  }
}

class _EdgePainter extends CustomPainter {
  final LinkedNode<Person>? focalPerson;
  final bool isPrimaryPerson;
  final Map<Id, (LinkedNode<Person>, Rect)> nodeRects;
  final Spacing spacing;

  _EdgePainter({
    required this.focalPerson,
    required this.isPrimaryPerson,
    required this.nodeRects,
    required this.spacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Only the left node in nodes with spouses
    final leftNodeInCouples = nodeRects.values.where((e) {
      final node = e.$1;
      final spouse = node.spouse;
      if (spouse == null) {
        return false;
      }
      return node.isBloodRelative && spouse.isBloodRelative
          ? node < spouse
          : !node.isBloodRelative;
    });

    final topOffset = min(20, spacing.level);
    for (final (fromNode, fromRect) in leftNodeInCouples) {
      final path = Path();
      for (final toNode in fromNode.children) {
        final (_, toRect) = nodeRects[toNode.id]!;
        final s = Offset(
          fromRect.bottomRight.dx + spacing.spouse / 2,
          fromRect.bottomRight.dy,
        );
        final e = toRect.topCenter;
        path
          ..moveTo(s.dx, s.dy + topOffset)
          ..lineTo(s.dx, s.dy + spacing.level / 2 - 20)
          ..lineTo(e.dx, s.dy + spacing.level / 2 - 20)
          ..lineTo(e.dx, e.dy - 20);
      }

      final dashedPath = path_drawing.dashPath(
        path,
        dashArray: path_drawing.CircularIntervalList<double>([8.0, 10.0]),
      );

      canvas.drawPath(
        dashedPath,
        Paint()
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke
          ..color = const Color.fromRGBO(0xB2, 0xB2, 0xB2, 1.0),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) {
    return !const DeepCollectionEquality.unordered()
            .equals(nodeRects, oldDelegate.nodeRects) ||
        spacing != oldDelegate.spacing;
  }

  double _paintText({
    required Canvas canvas,
    required String text,
    required TextStyle style,
    required Offset offset,
    required double maxWidth,
  }) {
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    );
    textPainter.layout(maxWidth: maxWidth);
    final lineMetrics = textPainter.computeLineMetrics();
    final height = lineMetrics.fold(0.0, (p, e) => p + e.height);
    textPainter.paint(canvas, offset - Offset(0, height));
    return offset.dy + height;
  }
}
