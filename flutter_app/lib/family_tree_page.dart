import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heritage/api.dart';
import 'package:heritage/family_tree_page_panels.dart';
import 'package:heritage/graph_provider.dart';
import 'package:heritage/graph_view.dart';
import 'package:heritage/heritage_app.dart';
import 'package:heritage/profile_display.dart';
import 'package:heritage/util.dart';
import 'package:heritage/zoomable_pannable_viewport.dart';
import 'package:share_plus/share_plus.dart';

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
      body: Stack(
        children: [
          !_ready
              ? const Center(
                  child: CircularProgressIndicator.adaptive(),
                )
              : widget.child,
          Opacity(
            opacity: 0.2,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: BackButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
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
        if (selectedPerson != null)
          Panels(
            key: Key(selectedPerson.id),
            person: selectedPerson,
            isRelative: _isRelative,
            onAddConnectionPressed: _showAddConnectionModal,
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
    final graphNotifier = ref.read(graphProvider.notifier);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add a ${relationship.name}'),
          content: SingleChildScrollView(
            child: BasicProfileDisplay(
              relationship: relationship,
              padding: const EdgeInsets.all(16),
              onSave: (name, gender) {
                Navigator.of(context).pop();
                graphNotifier.addConnection(
                  source: person.id,
                  name: name,
                  gender: gender,
                  relationship: relationship,
                );
              },
            ),
          ),
        );
      },
    );
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
  final _graphViewKey = GlobalKey<GraphViewState>();
  final _transformNotifier = ValueNotifier<Matrix4>(Matrix4.identity());
  bool _ready = false;

  @override
  void initState() {
    super.initState();
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
  void dispose() {
    _transformNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Overlay.wrap(
        child: Opacity(
          opacity: _ready ? 1.0 : 0.0,
          child: ZoomablePannableViewport(
            key: _viewportKey,
            onTransformed: (transform) => _transformNotifier.value = transform,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/tree_background.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
                GraphView<Person>(
                  key: _graphViewKey,
                  focalNodeId: widget.focalPerson.id,
                  nodes: widget.people,
                  spacing: const Spacing(
                    level: 302,
                    spouse: 52,
                    sibling: 297,
                  ),
                  nodeBuilder: (context, data, key, isRelative) {
                    return HoverableNodeProfile(
                      key: key,
                      person: data,
                      onTap: () => widget.onProfileSelected(data, isRelative),
                    );
                  },
                ),
              ],
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
    final key = _graphViewKey.currentState?.getKeyForNode(id);
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
  @override
  Widget build(BuildContext context) {
    const size = 541.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: ValueListenableBuilder(
            valueListenable: widget.transformNotifier,
            builder: (context, value, child) {
              final t = value.getTranslation();
              return Transform.translate(
                offset: Offset(t.x % size, t.y % size),
                child: Transform.scale(
                  scale: value.getMaxScaleOnAxis(),
                  child: child,
                ),
              );
            },
            child: Transform.translate(
              offset: const Offset(-size / 2, -size / 2),
              child: LayoutBuilder(
                builder: (context, c) {
                  final rowCount = max(2, c.maxHeight ~/ size + 2);
                  final columnCount = max(2, c.maxWidth ~/ size + 2);
                  return OverflowBox(
                    maxWidth: double.infinity,
                    maxHeight: double.infinity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var row = 0; row < rowCount; row++)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var column = 0;
                                  column < columnCount;
                                  column++)
                                Image.asset(
                                  'assets/images/tree_background.jpg',
                                  width: size,
                                  height: size,
                                ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class BasicProfileDisplay extends ConsumerStatefulWidget {
  final bool isRootCreation;
  final Relationship relationship;
  final String? initialName;
  final Gender? initialGender;
  final EdgeInsets padding;
  final void Function(String name, Gender gender) onSave;

  const BasicProfileDisplay({
    super.key,
    this.isRootCreation = false,
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
          const Center(
            child: Icon(
              Icons.person,
              size: 200,
              color: primaryColor,
            ),
          ),
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
            FilledButton(
              key: _shareButtonKey,
              onPressed: _shareLink,
              style: _bigButtonStyle,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.share),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            'Only share this link with your ${widget.relationship.name}'),
                        const Text('They can complete their profile'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          if (!widget.isRootCreation) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {},
              child:
                  const Text('Tap here for a child or deceased family member'),
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

  void _shareLink() {
    final rect = locateWidget(_shareButtonKey);
    final graph = ref.read(graphProvider);
    final personId = graph.focalPerson.id;
    final url = 'https://breakfastsearch.xyz/$personId';
    Share.share(
      url,
      subject: 'Join the family tree!',
      sharePositionOrigin: rect,
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
