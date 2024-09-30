import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heritage/api.dart';
import 'package:heritage/family_tree_page_panels.dart';
import 'package:heritage/graph.dart';
import 'package:heritage/graph_provider.dart';
import 'package:heritage/graph_view.dart';
import 'package:heritage/help.dart';
import 'package:heritage/heritage_app.dart';
import 'package:heritage/profile_display.dart';
import 'package:heritage/profile_update.dart';
import 'package:heritage/share.dart';
import 'package:heritage/util.dart';
import 'package:heritage/zoomable_pannable_viewport.dart';

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
      body: !_ready
          ? const Center(
              child: CircularProgressIndicator.adaptive(),
            )
          : widget.child,
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
  bool _isRelative = false;

  @override
  Widget build(BuildContext context) {
    final selectedPerson = _selectedPerson;
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
          onAddConnectionPressed: _showAddConnectionModal,
          onFetchConnections: (ids) {},
        ),
        Positioned(
          left: 16,
          top: 16,
          child: Opacity(
            opacity: 0.2,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: BackButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          top: 16,
          child: Opacity(
            opacity: 0.2,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                onPressed: () => showHelpDialog(context: context),
                icon: const Icon(Icons.question_mark),
              ),
            ),
          ),
        ),
        if (selectedPerson != null)
          Panels(
            key: Key(selectedPerson.id),
            person: selectedPerson,
            isRelative: _isRelative,
            onAddConnectionPressed: (relationship) =>
                _showAddConnectionModal(selectedPerson, relationship),
            onUpdate: (name, gender) =>
                _onUpdate(_selectedPerson!.id, name, gender),
            onViewPerspective: () {
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
            onClose: () => setState(() => _selectedPerson = null),
          ),
      ],
    );
  }

  void _showAddConnectionModal(Person person, Relationship relationship) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add a ${relationship.name}'),
          content: SingleChildScrollView(
            child: BasicProfileDisplay(
              relationship: relationship,
              isNewPerson: true,
              padding: const EdgeInsets.all(16),
              onSave: (name, gender) {
                _saveNewConnection(name, gender, person, relationship);
              },
            ),
          ),
        );
      },
    );
  }

  void _saveNewConnection(String name, Gender gender, Person person,
      Relationship relationship) async {
    final graphNotifier = ref.read(graphProvider.notifier);
    final addConnectionFuture = graphNotifier.addConnection(
      source: person.id,
      name: name,
      gender: gender,
      relationship: relationship,
    );
    final id = await showBlockingModal(context, addConnectionFuture);
    if (!mounted) {
      return;
    }
    if (id != null) {
      await _shareLink(name, id);
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  void _onUpdate(Id id, String name, Gender gender) async {
    final graph = ref.read(graphProvider);
    final person = graph.people[id];
    if (person == null) {
      return;
    }
    if (person.profile.name != name || person.profile.gender != gender) {
      final graphNotifier = ref.read(graphProvider.notifier);
      final addConnectionFuture = graphNotifier.updateProfile(
        id,
        ProfileUpdate(
            profile: person.profile.copyWith(name: name, gender: gender)),
      );
      await showBlockingModal(context, addConnectionFuture);
      if (!mounted) {
        return;
      }
    }

    await _shareLink(name, id);

    if (!mounted) {
      return;
    }
  }

  Future<void> _shareLink(String name, String id) async {
    final data = ShareData(
      title: '$name\'s family tree invite!',
      text: 'https://breakfastsearch.xyz/$id',
      url: 'https://breakfastsearch.xyz/$id',
    );
    if (await canShare(data)) {
      await shareContent(data);
    } else {
      await Clipboard.setData(ClipboardData(text: data.url!));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard!'),
        ),
      );
    }
  }

  void _onProfileSelected(Person? person, bool isRelative) {
    setState(() => _isRelative = isRelative);
    if (person == null) {
      setState(() => _selectedPerson = null);
      return;
    }

    _familyTreeViewKey.currentState?.centerOnPersonWithId(person.id);
    setState(() => _selectedPerson = person);
  }
}

class FamilyTreeView extends ConsumerStatefulWidget {
  final Person focalPerson;
  final List<Person> people;
  final Person? selectedPerson;
  final void Function(Person? person, bool isRelative) onProfileSelected;
  final void Function(Person person, Relationship relationship)
      onAddConnectionPressed;
  final void Function(List<Id> ids) onFetchConnections;

  const FamilyTreeView({
    super.key,
    required this.focalPerson,
    required this.people,
    required this.selectedPerson,
    required this.onProfileSelected,
    required this.onAddConnectionPressed,
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
      level: 302,
      spouse: 52,
      sibling: 297,
    );
    return Center(
      child: Overlay.wrap(
        child: Opacity(
          opacity: _ready ? 1.0 : 0.0,
          child: _TiledBackground(
            transformNotifier: _transformNotifier,
            child: ZoomablePannableViewport(
              key: _viewportKey,
              onTransformed: (transform) =>
                  _transformNotifier.value = transform,
              child: GraphView<Person>(
                key: _graphKey,
                focalNodeId: widget.focalPerson.id,
                nodeKeys: _nodeKeys,
                spacing: spacing,
                builder: (context, nodes, child) {
                  return ValueListenableBuilder(
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
                  );
                },
                nodeBuilder: (context, data, key, isRelative) {
                  return HoverableNodeProfile(
                    key: key,
                    person: data,
                    onTap: () => widget.onProfileSelected(data, isRelative),
                  );
                },
              ),
            ),
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
  final VoidCallback onTap;

  const HoverableNodeProfile({
    super.key,
    required this.person,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseHover(
      builder: (context, hovering) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: NodeProfile(
              person: person,
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
    final bytes = await rootBundle.load('assets/images/tree_background.jpg');
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
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

class BasicProfileDisplay extends ConsumerStatefulWidget {
  final bool isRootCreation;
  final bool isNewPerson;
  final Relationship relationship;
  final String? initialName;
  final Gender? initialGender;
  final EdgeInsets padding;
  final void Function(String name, Gender gender) onSave;

  const BasicProfileDisplay({
    super.key,
    this.isRootCreation = false,
    required this.isNewPerson,
    required this.relationship,
    this.initialName,
    this.initialGender,
    required this.padding,
    required this.onSave,
  });

  @override
  ConsumerState<BasicProfileDisplay> createState() =>
      _BasicProfileDisplayState();
}

class _BasicProfileDisplayState extends ConsumerState<BasicProfileDisplay> {
  late final TextEditingController _nameController;
  late Gender _gender;
  final _shareButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _gender = widget.initialGender ?? Gender.male;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

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
          SizedBox(height: widget.padding.top),
          Center(
            child: Text(
              'Add a ${widget.relationship.name}',
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Image.asset(
              'assets/images/connection_spouse.webp',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
          const SelectableText('First & Last Name'),
          const SizedBox(height: 4),
          TextFormField(
            controller: _nameController,
          ),
          const SizedBox(height: 16),
          widget.isRootCreation
              ? const SelectableText('Your Gender')
              : widget.relationship != Relationship.spouse
                  ? const SelectableText('Relationship')
                  : const Text('Gender'),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => setState(() => _gender = Gender.male),
                  style: FilledButton.styleFrom(
                    fixedSize: const Size.fromHeight(44),
                    backgroundColor:
                        _gender == Gender.male ? primaryColor : unselectedColor,
                  ),
                  child: (widget.relationship != Relationship.spouse &&
                          !widget.isRootCreation)
                      ? Text(genderedRelationship(
                          widget.relationship, Gender.male))
                      : const Text('Male'),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: FilledButton(
                  onPressed: () => setState(() => _gender = Gender.female),
                  style: FilledButton.styleFrom(
                    fixedSize: const Size.fromHeight(44),
                    backgroundColor:
                        _gender == Gender.male ? unselectedColor : primaryColor,
                  ),
                  child: (widget.relationship != Relationship.spouse &&
                          !widget.isRootCreation)
                      ? Text(genderedRelationship(
                          widget.relationship, Gender.female))
                      : const Text('Female'),
                ),
              ),
            ],
          ),
          if (!widget.isRootCreation) ...[
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: _nameController,
              builder: (context, child) {
                return FilledButton(
                  key: _shareButtonKey,
                  onPressed: _nameController.text.isEmpty ? null : _done,
                  style: _bigButtonStyle,
                  child: child,
                );
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.share),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _nameController,
                            builder: (context, child) {
                              return Text(
                                'Only share this link with ${_nameController.text}',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                          const Text('They can complete their profile'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Center(
              child: AnimatedBuilder(
                animation: _nameController,
                builder: (context, child) {
                  return TextButton(
                    onPressed: _nameController.text.isEmpty ? null : _done,
                    child: const Text('Done'),
                  );
                },
              ),
            ),
          ],
          if (!widget.isRootCreation) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () {},
                child: const Text(
                    'Tap here for a child or deceased family member'),
              ),
            ),
          ],
          SizedBox(height: widget.padding.bottom),
        ],
      ),
    );
  }

  void _done() {
    final name = _nameController.text;
    if (name.isEmpty) {
      return;
    }
    widget.onSave(name, _gender);
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
              '${focalPerson.profile.name} has been added to the family tree')
          : Text(
              '${focalPerson.profile.name} has been added to the family tree by ${addedBy.profile.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text('Are you ${focalPerson.profile.name}?'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: _bigButtonStyle,
            child: Text('Yes, I am ${focalPerson.profile.name}'),
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
    // Only the left node in nodes with spouses
    final leftNodeInCouples = nodeRects.values.where((e) {
      final node = e.$1;
      final spouse = node.spouse;
      if (spouse == null) {
        return false;
      }
      return node.isRelative && spouse.isRelative
          ? node < spouse
          : !node.isRelative;
    });
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
          ..moveTo(s.dx, s.dy)
          ..lineTo(s.dx, s.dy + spacing.level / 2)
          ..lineTo(e.dx, s.dy + spacing.level / 2)
          ..lineTo(e.dx, e.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke
          ..color = Colors.black,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) {
    return !const DeepCollectionEquality.unordered()
            .equals(nodeRects, oldDelegate.nodeRects) ||
        spacing != oldDelegate.spacing;
  }
}
