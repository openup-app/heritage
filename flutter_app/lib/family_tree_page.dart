import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heritage/api.dart';
import 'package:heritage/family_tree_page_panels.dart';
import 'package:heritage/graph.dart';
import 'package:heritage/graph_provider.dart';
import 'package:heritage/graph_view.dart';
import 'package:heritage/heritage_app.dart';
import 'package:heritage/profile_display.dart';
import 'package:heritage/util.dart';
import 'package:heritage/zoomable_pannable_viewport.dart';
import 'package:share_plus/share_plus.dart';

class FamilyTreeLoadingPage extends ConsumerStatefulWidget {
  final Id focalNodeId;
  final Widget child;

  const FamilyTreeLoadingPage({
    super.key,
    required this.focalNodeId,
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
      hasNodesProvider,
      (previous, next) {
        if (next) {
          setState(() => _ready = true);
        }
      },
    );
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) {
        ref.read(focalNodeIdProvider.notifier).state = widget.focalNodeId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        foregroundColor: Colors.black.withOpacity(0.3),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Family Tree - ${widget.focalNodeId}'),
      ),
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
  Node? _node;

  @override
  Widget build(BuildContext context) {
    final node = _node;
    final graph = ref.watch(graphProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        FamilyTreeView(
          focalNode: graph.focalNode,
          nodes: graph.nodes.values.toList(),
          onProfileSelected: _onProfileSelected,
          onAddConnectionPressed: _showAddConnectionModal,
          onFetchConnections: (ids) {},
        ),
        if (node != null)
          Panels(
            node: node,
            onViewPerspective: () {
              final pathParameters = {
                'focalNodeId': graph.focalNode.id,
                'perspectiveNodeId': node.id,
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
            onClose: () => setState(() => _node = null),
          ),
      ],
    );
  }

  void _showAddConnectionModal(Node node, Relationship relationship) {
    final graphNotifier = ref.read(graphProvider.notifier);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add a ${relationship.name}'),
          content: SingleChildScrollView(
            child: BasicProfileModal(
              relationship: relationship,
              onSave: (name, gender) {
                Navigator.of(context).pop();
                graphNotifier.addConnection(
                  source: node.id,
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

  void _onProfileSelected(LinkedNode<Node>? linkedNode) {
    if (linkedNode == null) {
      setState(() => _node = null);
      return;
    }

    final node = linkedNode.data;
    final ownershipClaimed = node.ownedBy != null;
    if (!ownershipClaimed) {
      setState(() => _node = null);
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: BasicProfileModal(
              relationship: Relationship.sibling,
              initialName: node.profile.name,
              initialGender: node.profile.gender,
              onSave: (_, __) {},
            ),
          );
        },
      );
    } else {
      setState(() => _node = linkedNode.data);
    }
  }
}

class FamilyTreeView extends ConsumerStatefulWidget {
  final Node focalNode;
  final List<Node> nodes;
  final void Function(LinkedNode<Node>? node) onProfileSelected;
  final void Function(Node node, Relationship relationship)
      onAddConnectionPressed;
  final void Function(List<Id> ids) onFetchConnections;

  const FamilyTreeView({
    super.key,
    required this.focalNode,
    required this.nodes,
    required this.onProfileSelected,
    required this.onAddConnectionPressed,
    required this.onFetchConnections,
  });

  @override
  ConsumerState<FamilyTreeView> createState() => _FamilyTreeViewState();
}

class _FamilyTreeViewState extends ConsumerState<FamilyTreeView> {
  final _nodeKeys = <Id, GlobalKey>{};
  final _nodeKeysFlipped = <GlobalKey, Id>{};
  final _transformNotifier = ValueNotifier<Matrix4>(Matrix4.identity());

  @override
  void initState() {
    super.initState();
    _updateKeys();
    if (widget.focalNode.ownedBy == null) {
      WidgetsBinding.instance.endOfFrame.then((_) {
        if (mounted) {
          _showOwnershipModal();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant FamilyTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!const DeepCollectionEquality.unordered()
        .equals(oldWidget.nodes, widget.nodes)) {
      _updateKeys();
    }
  }

  void _updateKeys() {
    for (final node in widget.nodes) {
      _nodeKeys.putIfAbsent(node.id, () {
        final key = GlobalKey();
        _nodeKeysFlipped[key] = node.id;
        return key;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ZoomablePannableViewport(
        childKeys: _nodeKeys.values.toList(),
        onWithinViewport: (keys) {
          final ids =
              keys.map((e) => _nodeKeysFlipped[e]).whereNotNull().toList();
          if (ids.isNotEmpty) {
            widget.onFetchConnections(ids);
          }
        },
        onTransformed: (transform) => _transformNotifier.value = transform,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/tree_background.jpg',
                fit: BoxFit.cover,
              ),
            ),
            GraphView(
              focalNodeId: widget.focalNode.id,
              nodes: widget.nodes,
              // levelGap: 40,
              // spouseGap: 4,
              // siblingGap: 16,
              // nodeBuilder: (context, node) {
              //   return Consumer(
              //     builder: (context, ref, child) {
              //       return GestureDetector(
              //         onTap: () => _sendTest(context, ref),
              //         child: NodeDisplay(node: node),
              //       );
              //     },
              //   );
              // },
              levelGap: 302,
              spouseGap: 52,
              siblingGap: 297,
              nodeBuilder: (context, linkedNode) {
                return MouseHover(
                  key: _nodeKeys[linkedNode.id],
                  transformNotifier: _transformNotifier,
                  builder: (context, hovering) {
                    // TODO: Need accounts
                    final node = linkedNode.data;
                    final isMe = widget.focalNode.id == node.id;
                    final canModify =
                        isMe || (linkedNode.isRelative && node.ownedBy == null);
                    return ProfileControls(
                      show: hovering && canModify,
                      canAddParent: node.parents.isEmpty,
                      onAddConnectionPressed: (relationship) =>
                          widget.onAddConnectionPressed(node, relationship),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => widget.onProfileSelected(linkedNode),
                          child: NodeProfile(
                            node: node,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showOwnershipModal() async {
    final addedBy =
        widget.nodes.firstWhereOrNull((e) => e.id == widget.focalNode.addedBy);
    final tookOwnership = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return OwnershipDialog(
          focalNode: widget.focalNode,
          addedBy: addedBy,
        );
      },
    );
    if (!mounted) {
      return;
    }
    if (tookOwnership == true) {
      ref.read(graphProvider.notifier).takeOwnership(widget.focalNode.id);
    } else {
      context.goNamed('menu');
    }
  }
}

class BasicProfileModal extends ConsumerStatefulWidget {
  final bool isRootNodeCreation;
  final Relationship relationship;
  final String? initialName;
  final Gender? initialGender;
  final void Function(String name, Gender gender) onSave;

  const BasicProfileModal({
    super.key,
    this.isRootNodeCreation = false,
    required this.relationship,
    this.initialName,
    this.initialGender,
    required this.onSave,
  });

  @override
  ConsumerState<BasicProfileModal> createState() => _AddConnectionModalState();
}

class _AddConnectionModalState extends ConsumerState<BasicProfileModal> {
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        widget.isRootNodeCreation
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
                        !widget.isRootNodeCreation)
                    ? Text(
                        genderedRelationship(widget.relationship, Gender.male))
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
                        !widget.isRootNodeCreation)
                    ? Text(genderedRelationship(
                        widget.relationship, Gender.female))
                    : const Text('Female'),
              ),
            ),
          ],
        ),
        if (!widget.isRootNodeCreation) ...[
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
        if (!widget.isRootNodeCreation) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {},
            child: const Text('Tap here for a child or deceased family member'),
          ),
        ],
      ],
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
    final rect = _shareButtonRect();
    final graph = ref.read(graphProvider);
    final nodeId = graph.focalNode.id;
    final url = 'https://breakfastsearch.xyz/$nodeId';
    Share.share(
      url,
      subject: 'Join the family tree!',
      sharePositionOrigin: rect,
    );
  }

  Rect _shareButtonRect() {
    final renderBox =
        _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final position = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final size = renderBox?.size ?? const Size(100, 100);
    return position & size;
  }
}

class OwnershipDialog extends StatelessWidget {
  final Node focalNode;
  final Node? addedBy;

  const OwnershipDialog({
    super.key,
    required this.focalNode,
    required this.addedBy,
  });

  @override
  Widget build(BuildContext context) {
    final addedBy = this.addedBy;
    return AlertDialog(
      title: addedBy == null
          ? Text('${focalNode.profile.name} has been added to the family tree')
          : Text(
              '${focalNode.profile.name} has been added to the family tree by ${addedBy.profile.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text('Are you ${focalNode.profile.name}?'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: _bigButtonStyle,
            child: Text('Yes, I am ${focalNode.profile.name}'),
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
