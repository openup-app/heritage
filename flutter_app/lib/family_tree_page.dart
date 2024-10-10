import 'dart:math';
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
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
import 'package:heritage/profile_display.dart';
import 'package:heritage/util.dart';
import 'package:heritage/zoomable_pannable_viewport.dart';
import 'package:lottie/lottie.dart';
import 'package:path_drawing/path_drawing.dart' as path_drawing;

class FamilyTreeLoadingPage extends ConsumerStatefulWidget {
  final bool isPerspectiveMode;
  final VoidCallback onReady;
  final VoidCallback onError;
  final Widget child;

  const FamilyTreeLoadingPage({
    super.key,
    required this.isPerspectiveMode,
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
              final isOwnedBySomeoneElse = focalPerson.ownedBy != null &&
                  focalPerson.ownedBy != focalPerson.id;
              // Users owned by another can't login (but can view perspective)
              if (isOwnedBySomeoneElse && !widget.isPerspectiveMode) {
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
  final ViewHistory viewHistory;

  const FamilyTreePage({
    super.key,
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
              setState(() {
                _panelPopupState = PanelPopupStateAddConnection(
                  newConnectionId: newId,
                  relationship: relationship,
                );
              });
            }
          },
          onSelectPerson: (id) {
            final focalNode = _familyTreeViewKey.currentState
                ?.linkedNodeForId(graph.focalPerson.id);
            final linkedNode =
                _familyTreeViewKey.currentState?.linkedNodeForId(id);
            if (focalNode != null && linkedNode != null) {
              final person = linkedNode.data;
              final relatedness = Relatedness(
                isBloodRelative: linkedNode.isBloodRelative,
                isDirectRelativeOrSpouse: linkedNode.isDirectRelativeOrSpouse,
                isAncestor: linkedNode.isAncestor,
                isSibling: linkedNode.isSibling,
                relativeLevel: linkedNode.relativeLevel,
                description: relatednessDescription(focalNode, linkedNode),
              );
              _onProfileSelected(person, relatedness);
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
          top: 16,
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

  void _onProfileSelected(Person person, Relatedness relatedness) {
    // Don'000t open profiles that are in the middle of saving
    if (_savingNotifier.value == person.id) {
      return;
    }

    _familyTreeViewKey.currentState?.centerOnPersonWithId(person.id);
    setState(() {
      _selectedPerson = person;
      _relatedness = relatedness;
      if (person.ownedBy == null) {
        _panelPopupState = PanelPopupStateWaitingForApproval(
            person: person, relatedness: relatedness);
      } else {
        _panelPopupState =
            PanelPopupStateProfile(person: person, relatedness: relatedness);
      }
    });
  }

  void _onDismissSelected() {
    // Force any pending auto save
    _debouncer.flush();

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
      showProfileUpdateSuccess(context: context);
    }
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
          if (widget.focalPerson.ownedBy == null) {
            _showOwnershipModal();
          }
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
      sibling: 50,
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
                    nodeBuilder: (context, data, node, key, relatedness) {
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
                        isSibling: relatedness.isSibling,
                        isOwned: data.ownedBy != null,
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
                                    : () => widget.onProfileSelected(
                                        data, relatedness),
                                child: NodeProfile(
                                  person: data,
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

  void _showOwnershipModal() async {
    final tookOwnership = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return OwnershipDialog(
          focalPerson: widget.focalPerson,
        );
      },
    );
    if (!mounted) {
      return;
    }
    if (tookOwnership == true) {
      ref.read(graphProvider.notifier).takeOwnership(widget.focalPerson.id);
    } else {
      context.goNamed(
        'landing',
        queryParameters: {
          'status': 'decline',
        },
      );
    }
  }
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

class AddConnectionDisplay extends ConsumerStatefulWidget {
  final Relationship relationship;
  final void Function(
          String firstName, String lastName, Gender gender, bool takeOwnership)
      onSaveAndShareOrTakeOwnership;

  const AddConnectionDisplay({
    super.key,
    required this.relationship,
    required this.onSaveAndShareOrTakeOwnership,
  });

  @override
  ConsumerState<AddConnectionDisplay> createState() =>
      _AddConnectionDisplayState();
}

class _AddConnectionDisplayState extends ConsumerState<AddConnectionDisplay> {
  String _firstName = '';
  String _lastName = '';
  Gender _gender = Gender.male;

  @override
  Widget build(BuildContext context) {
    final canSubmit = _firstName.isNotEmpty && _lastName.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add\na ${widget.relationship.name}',
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: Color.fromRGBO(0x3C, 0x3C, 0x3C, 1.0),
          ),
        ),
        const SizedBox(height: 16),
        MinimalProfileEditor(
          onUpdate: (firstName, lastName) {
            setState(() {
              _firstName = firstName;
              _lastName = lastName;
            });
          },
        ),
        const SizedBox(height: 24),
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
          onPressed: !canSubmit ? null : () => _done(takeOwnership: false),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: !canSubmit
                ? null
                : () async {
                    final takeOwnership = await showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Manage Profile?'),
                          content: const Text(
                              '\nCompleting someone else\'s profile should only be done if they can\'t do it themself.\n\nExample: child, disabled, or deceased'),
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
                    if (mounted && takeOwnership == true) {
                      _done(takeOwnership: true);
                    }
                  },
            style: TextButton.styleFrom(
              foregroundColor: const Color.fromRGBO(0xFF, 0x47, 0x47, 1.0),
            ),
            child: const Text('Child, disabled or deceased?'),
          ),
        ),
      ],
    );
  }

  void _done({required bool takeOwnership}) {
    if (_firstName.isEmpty || _lastName.isEmpty) {
      return;
    }
    widget.onSaveAndShareOrTakeOwnership(
        _firstName, _lastName, _gender, takeOwnership);
  }
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

class OwnershipDialog extends StatelessWidget {
  final Person focalPerson;

  const OwnershipDialog({
    super.key,
    required this.focalPerson,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Are you ${focalPerson.profile.fullName}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color.fromRGBO(0xEB, 0xEB, 0xEB, 1.0),
              fixedSize: const Size.fromHeight(48),
            ),
            child: const Text('Yes'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: Navigator.of(context).pop,
            style: FilledButton.styleFrom(
              backgroundColor: const Color.fromRGBO(0xEB, 0xEB, 0xEB, 1.0),
              fixedSize: const Size.fromHeight(48),
            ),
            child: const Text('No'),
          ),
        ],
      ),
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
    for (final (node, rect) in nodeRects.values) {
      final person = node.data;
      final bottom = _paintText(
        canvas: canvas,
        text: person.profile.fullName,
        style: const TextStyle(
          color: Color.fromRGBO(0x37, 0x37, 0x37, 1),
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
        topCenter: rect.bottomCenter + const Offset(0, 16),
        maxWidth: rect.width,
      );
      if (focalPerson == null) {
        continue;
      }
      final relatedness = relatednessDescription(
        focalPerson!,
        node,
        useFocalName: !isPrimaryPerson,
      );
      _paintText(
        canvas: canvas,
        text: relatedness,
        style: const TextStyle(
          color: Color.fromRGBO(0x37, 0x37, 0x37, 1),
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
        topCenter: Offset(rect.bottomCenter.dx, bottom),
        maxWidth: rect.width,
      );
    }

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

    final topOffset = min(70, spacing.level);
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
          ..lineTo(s.dx, s.dy + spacing.level / 2)
          ..lineTo(e.dx, s.dy + spacing.level / 2)
          ..lineTo(e.dx, e.dy);
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
    required Offset topCenter,
    required double maxWidth,
  }) {
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );
    textPainter.layout(maxWidth: maxWidth);
    final lineMetrics = textPainter.computeLineMetrics().first;
    textPainter.paint(canvas, topCenter - Offset(lineMetrics.width / 2, 0));
    return topCenter.dy + lineMetrics.height;
  }
}

class ShareLinkButton extends StatelessWidget {
  final String firstName;
  final VoidCallback? onPressed;

  const ShareLinkButton({
    super.key,
    required this.firstName,
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
                'Share with $firstName ONLY',
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
