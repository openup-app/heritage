import 'dart:math';
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:heritage/api.dart';
import 'package:heritage/family_tree_page_panels.dart';
import 'package:heritage/graph.dart';
import 'package:heritage/graph_provider.dart';
import 'package:heritage/graph_view.dart';
import 'package:heritage/heritage_app.dart';
import 'package:heritage/loading_page.dart';
import 'package:heritage/profile_display.dart';
import 'package:heritage/util.dart';
import 'package:heritage/zoomable_pannable_viewport.dart';
import 'package:path_drawing/path_drawing.dart' as path_drawing;

class FamilyTreeLoadingPage extends ConsumerStatefulWidget {
  final Id focalPersonId;
  final Widget child;

  const FamilyTreeLoadingPage({
    super.key,
    required this.focalPersonId,
    required this.child,
  });

  @override
  ConsumerState<FamilyTreeLoadingPage> createState() => ViewPageState();
}

class ViewPageState extends ConsumerState<FamilyTreeLoadingPage> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      hasPeopleProvider,
      (previous, next) {
        if (next) {
          setState(() => _ready = true);
        }
      },
    );
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) {
        ref.read(focalPersonIdProvider.notifier).state = widget.focalPersonId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AnimatedCrossFade(
        duration: const Duration(milliseconds: 500),
        layoutBuilder: (topChild, topChildKey, bottomChild, bottomChildKey) {
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              KeyedSubtree(
                key: bottomChildKey,
                child: bottomChild,
              ),
              KeyedSubtree(
                key: topChildKey,
                child: topChild,
              ),
            ],
          );
        },
        crossFadeState:
            !_ready ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        firstChild: const LoadingPage(),
        secondChild: !_ready ? const SizedBox.shrink() : widget.child,
      ),
    );
  }
}

class FamilyTreePage extends ConsumerStatefulWidget {
  final bool isPerspectiveMode;

  const FamilyTreePage({
    super.key,
    this.isPerspectiveMode = false,
  });

  @override
  ConsumerState<FamilyTreePage> createState() => _FamilyTreePageState();
}

class _FamilyTreePageState extends ConsumerState<FamilyTreePage> {
  final _familyTreeViewKey = GlobalKey<FamilyTreeViewState>();
  Person? _selectedPerson;
  Relatedness? _relatedness;
  PanelPopupState _panelPopupState = const PanelPopupStateNone();

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
          selectedPerson: _selectedPerson,
          onProfileSelected: _onProfileSelected,
          onFetchConnections: (ids) {},
        ),
        Panels(
          selectedPerson: _selectedPerson,
          relatedness: _relatedness,
          focalPerson: graph.focalPerson,
          panelPopupState: _panelPopupState,
          onDismissPanelPopup: () =>
              setState(() => _panelPopupState = const PanelPopupStateNone()),
          onAddConnectionPressed: (relationship) {
            final person = _selectedPerson;
            if (person != null) {
              setState(() {
                _panelPopupState = PanelPopupStateAddConnection(
                  person: person,
                  relationship: relationship,
                );
              });
            }
          },
          onViewPerspective: () {
            final selectedPerson = _selectedPerson;
            if (selectedPerson == null) {
              return;
            }
            final pathParameters = {
              'focalPersonId': graph.focalPerson.id,
              'perspectivePersonId': selectedPerson.id,
            };
            if (!widget.isPerspectiveMode) {
              context.pushNamed(
                'perspective',
                pathParameters: pathParameters,
              );
            } else {
              context.pushReplacementNamed(
                'perspective',
                pathParameters: pathParameters,
              );
            }
          },
        ),
      ],
    );
  }

  void _onProfileSelected(Person? person, Relatedness? relatedness) {
    setState(() => _relatedness = relatedness);
    if (person == null || relatedness == null) {
      setState(() {
        _selectedPerson = null;
        _relatedness = null;
        _panelPopupState = const PanelPopupStateNone();
      });
      return;
    } else {
      _familyTreeViewKey.currentState?.centerOnPersonWithId(person.id);
      setState(() {
        _selectedPerson = person;
        _relatedness = relatedness;
        if (person.ownedBy == null) {
          _panelPopupState = PanelPopupStateWaitingForApproval(
              person: person, relatedness: relatedness);
        } else {
          _panelPopupState = PanelPopupStateProfile(person: person);
        }
      });
    }
  }
}

class FamilyTreeView extends ConsumerStatefulWidget {
  final Person focalPerson;
  final List<Person> people;
  final Person? selectedPerson;
  final void Function(Person? person, Relatedness? relatedness)
      onProfileSelected;
  final void Function(List<Id> ids) onFetchConnections;

  const FamilyTreeView({
    super.key,
    required this.focalPerson,
    required this.people,
    required this.selectedPerson,
    required this.onProfileSelected,
    required this.onFetchConnections,
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
  late Key _graphKey;

  @override
  void initState() {
    super.initState();
    _reinitKeys();
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) {
        if (widget.focalPerson.ownedBy == null) {
          _showOwnershipModal();
        }
        centerOnPersonWithId(widget.focalPerson.id, animate: false);
        setState(() => _ready = true);
      }
    });
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
    _graphKey = UniqueKey();
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
                child: ZoomablePannableViewport(
                  key: _viewportKey,
                  onTransformed: (transform) =>
                      _transformNotifier.value = transform,
                  onStartInteraction: () {
                    if (widget.selectedPerson != null) {
                      widget.onProfileSelected(null, null);
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
                              return _Edges(
                                idToKey: _idToKey,
                                idToNode: nodes,
                                spacing: spacing,
                                transform: value,
                                child: child,
                              );
                            },
                          ),
                        ],
                      );
                    },
                    nodeBuilder: (context, data, key, relatedness) {
                      final enabled = widget.selectedPerson == null ||
                          widget.selectedPerson?.id == data.id;
                      return HoverableNodeProfile(
                        key: key,
                        person: data,
                        hasAdditionalRelatives: !relatedness.isSibling &&
                            data.id != widget.focalPerson.id &&
                            data.ownedBy != null,
                        enabled: enabled,
                        forceHover: widget.selectedPerson?.id == data.id,
                        onTap: !enabled
                            ? null
                            : () => widget.onProfileSelected(data, relatedness),
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

  void centerOnPersonWithId(
    Id id, {
    bool animate = true,
  }) {
    final key = _idToKey[id];
    if (key != null) {
      _viewportKey.currentState?.centerOnWidgetWithKey(
        key,
        animate: animate,
      );
    }
  }

  void _showOwnershipModal() async {
    final addedBy = widget.people
        .firstWhereOrNull((e) => e.id == widget.focalPerson.addedBy);
    final tookOwnership = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return OwnershipDialog(
          focalPerson: widget.focalPerson,
          addedBy: addedBy,
        );
      },
    );
    if (!mounted) {
      return;
    }
    if (tookOwnership == true) {
      ref.read(graphProvider.notifier).takeOwnership(widget.focalPerson.id);
    } else {
      context.goNamed('menu');
    }
  }
}

class HoverableNodeProfile extends StatelessWidget {
  final Person person;
  final bool hasAdditionalRelatives;
  final bool enabled;
  final bool forceHover;
  final VoidCallback? onTap;

  const HoverableNodeProfile({
    super.key,
    required this.person,
    required this.hasAdditionalRelatives,
    this.enabled = true,
    this.forceHover = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseHover(
      enabled: enabled,
      forceHover: forceHover,
      builder: (context, hovering) {
        return MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          child: GestureDetector(
            onTap: onTap,
            child: NodeProfile(
              person: person,
              hasAdditionalRelatives: hasAdditionalRelatives,
            ),
          ),
        );
      },
    );
  }
}

class _TiledBackground extends StatefulWidget {
  final ValueNotifier<Matrix4> transformNotifier;
  final Widget child;

  const _TiledBackground({
    super.key,
    required this.transformNotifier,
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
  final Matrix4 transform;

  _TilePainter({
    required this.tile,
    required this.transform,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final translate = transform.getTranslation();
    final scale = transform.getMaxScaleOnAxis();
    final scaledTileWidth = tile.width * scale;
    final scaledTileHeight = tile.height * scale;
    final canvasTransform = Matrix4.identity()
      ..translate(translate.x % scaledTileWidth, translate.y % scaledTileHeight)
      ..scale(scale);
    canvas.transform(canvasTransform.storage);
    final scaledCanvasSize = size / scale;
    final countWidth = scaledCanvasSize.width ~/ tile.width + 1;
    final countHeight = scaledCanvasSize.height ~/ tile.height + 1;
    for (var y = -1; y < countHeight; y++) {
      for (var x = -1; x < countWidth; x++) {
        canvas.drawImage(
          tile,
          Offset(x * tile.width.toDouble(), y * tile.height.toDouble()),
          Paint()..filterQuality = ui.FilterQuality.high,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TilePainter oldDelegate) =>
      !tile.isCloneOf(oldDelegate.tile) || transform != oldDelegate.transform;
}

class AddConnectionDisplay extends ConsumerStatefulWidget {
  final Relationship relationship;
  final void Function(
          String firstName, String lastName, Gender gender, bool takeOwnership)
      onSave;

  const AddConnectionDisplay({
    super.key,
    required this.relationship,
    required this.onSave,
  });

  @override
  ConsumerState<AddConnectionDisplay> createState() =>
      _BasicProfileDisplayState();
}

class _BasicProfileDisplayState extends ConsumerState<AddConnectionDisplay> {
  String _firstName = '';
  String _lastName = '';
  Gender _gender = Gender.male;
  final _shareButtonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Add a ${widget.relationship.name}',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Color.fromRGBO(0x3C, 0x3C, 0x3C, 1.0),
          ),
        ),
        Center(
          child: SvgPicture.asset(
            'assets/images/connection_${widget.relationship.name}.svg',
            height: 250,
          ),
        ),
        const SizedBox(height: 16),
        MinimalProfileEditor(
          onUpdate: (firstName, lastName, gender) {
            setState(() {
              _firstName = firstName;
              _lastName = lastName;
              _gender = gender;
            });
          },
        ),
        const SizedBox(height: 32),
        ShareLinkButton(
          key: _shareButtonKey,
          firstName: _firstName,
          onPressed: (_firstName.isEmpty || _lastName.isEmpty)
              ? null
              : () => _done(takeOwnership: false),
        ),
      ],
    );
  }

  void _done({required bool takeOwnership}) {
    if (_firstName.isEmpty || _lastName.isEmpty) {
      return;
    }
    widget.onSave(_firstName, _lastName, _gender, takeOwnership);
  }
}

class CreateRootDisplay extends ConsumerStatefulWidget {
  final EdgeInsets padding;
  final void Function(String firstName, String lastName, Gender gender) onDone;

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
  Gender _gender = Gender.male;

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
    widget.onDone(_firstName, _lastName, _gender);
  }
}

class MinimalProfileEditor extends StatefulWidget {
  final String? initialFirstName;
  final String? initialLastName;
  final Gender? initialGender;
  final void Function(String firstName, String lastName, Gender gender)
      onUpdate;

  const MinimalProfileEditor({
    super.key,
    this.initialFirstName,
    this.initialLastName,
    this.initialGender,
    required this.onUpdate,
  });

  @override
  State<MinimalProfileEditor> createState() => _MinimalProfileEditorState();
}

class _MinimalProfileEditorState extends State<MinimalProfileEditor> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late Gender _gender;

  @override
  void initState() {
    super.initState();
    _firstNameController =
        TextEditingController(text: widget.initialFirstName ?? '');
    _lastNameController =
        TextEditingController(text: widget.initialLastName ?? '');
    _gender = widget.initialGender ?? Gender.male;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _firstNameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (text) =>
              widget.onUpdate(text, _lastNameController.text, _gender),
          decoration: const InputDecoration(
            label: Text('First name'),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _lastNameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (text) =>
              widget.onUpdate(_firstNameController.text, text, _gender),
          decoration: const InputDecoration(
            label: Text('Last name'),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (final gender in Gender.values) ...[
              if (gender != Gender.values.first) const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    setState(() => _gender = gender);
                    widget.onUpdate(_firstNameController.text,
                        _lastNameController.text, _gender);
                  },
                  style: FilledButton.styleFrom(
                    fixedSize: const Size.fromHeight(44),
                    foregroundColor: _gender == gender ? Colors.white : null,
                    backgroundColor: _gender == gender ? primaryColor : null,
                  ),
                  child: Text(
                      '${gender.name[0].toUpperCase()}${gender.name.substring(1)}'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class OwnershipDialog extends StatelessWidget {
  final Person focalPerson;
  final Person? addedBy;

  const OwnershipDialog({
    super.key,
    required this.focalPerson,
    required this.addedBy,
  });

  @override
  Widget build(BuildContext context) {
    final addedBy = this.addedBy;
    return AlertDialog(
      title: addedBy == null
          ? Text(
              '${focalPerson.profile.fullName} has been added to the family tree')
          : Text(
              '${focalPerson.profile.fullName} has been added to the family tree by ${addedBy.profile.fullName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text('Are you ${focalPerson.profile.fullName}?'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: _bigButtonStyle,
            child: Text('Yes, I am ${focalPerson.profile.fullName}'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('No, I am someone else'),
          ),
        ],
      ),
    );
  }
}

ButtonStyle _bigButtonStyle = FilledButton.styleFrom(
  foregroundColor: Colors.white,
  backgroundColor: primaryColor,
  fixedSize: const Size.fromHeight(64),
);

class _Edges extends StatefulWidget {
  final Map<Id, GlobalKey> idToKey;
  final Map<Id, LinkedNode<Person>> idToNode;
  final Spacing spacing;
  final Matrix4 transform;
  final Widget child;

  const _Edges({
    super.key,
    required this.idToKey,
    required this.idToNode,
    required this.spacing,
    required this.transform,
    required this.child,
  });

  @override
  State<_Edges> createState() => _EdgesState();
}

class _EdgesState extends State<_Edges> {
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
  void didUpdateWidget(covariant _Edges oldWidget) {
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
        nodeRects: Map.of(_nodeRects),
        spacing: widget.spacing,
      ),
      child: widget.child,
    );
  }
}

class _EdgePainter extends CustomPainter {
  final Map<Id, (LinkedNode<Person>, Rect)> nodeRects;
  final Spacing spacing;

  _EdgePainter({
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
      final birthyear = person.profile.birthday?.year.toString();
      if (birthyear != null) {
        _paintText(
          canvas: canvas,
          text: birthyear,
          style: const TextStyle(
            color: Color.fromRGBO(0x37, 0x37, 0x37, 1),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
          topCenter: Offset(rect.bottomCenter.dx, bottom),
          maxWidth: rect.width,
        );
      }
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
                '$firstName will now verify this profile\n ONLY share this profile with $firstName',
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
