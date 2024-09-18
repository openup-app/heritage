import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heritage/api.dart';
import 'package:heritage/graph.dart';
import 'package:heritage/heritage_app.dart';
import 'package:heritage/tree.dart';
import 'package:heritage/tree_display2.dart';
import 'package:share_plus/share_plus.dart';

class ViewPage extends ConsumerStatefulWidget {
  final Id focalNodeId;

  const ViewPage({
    super.key,
    required this.focalNodeId,
  });

  @override
  ConsumerState<ViewPage> createState() => ViewPageState();
}

class ViewPageState extends ConsumerState<ViewPage> {
  Node? _focalNode;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      focalNodeProvider,
      fireImmediately: true,
      (previous, next) {
        final focalNode = next.valueOrNull;
        if (focalNode != null) {
          setState(() => _focalNode = focalNode);
        }
        WidgetsBinding.instance.endOfFrame.then((_) {
          if (mounted) {
            final id = focalNode?.id;
            if (id != null) {
              ref.read(graphProvider.notifier).fetchConnections(id);
            }
          }
        });
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
      body: Builder(
        builder: (context) {
          final focalNode = _focalNode;
          if (focalNode == null) {
            return const Center(
              child: CircularProgressIndicator.adaptive(),
            );
          }
          final result = ref.watch(graphProvider);
          return KeyedSubtree(
            key: Key(result.nodes.length.toString()),
            child: TreeTestPage(
              focalNode: result.focalNode,
            ),
          );
        },
      ),
    );
  }
}

class TreeTestPage extends ConsumerStatefulWidget {
  final Node focalNode;
  const TreeTestPage({
    super.key,
    required this.focalNode,
  });

  @override
  ConsumerState<TreeTestPage> createState() => _TreeTestPageState();
}

class _TreeTestPageState extends ConsumerState<TreeTestPage> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: FamilyTreeDisplay2(
        focal: widget.focalNode,
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
        nodeBuilder: (context, node) {
          return Consumer(
            builder: (context, ref, child) {
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _showProfile(context, node),
                  onDoubleTap: () {
                    ref.read(graphProvider.notifier).fetchConnections(node.id);
                  },
                  child: NodeDisplayFull(node: node),
                ),
              );
            },
          );
        },
        onAddConnectionPressed: _showAddConnectionModal,
      ),
    );
  }

  void _showProfile(BuildContext context, Node node) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('My Profile'),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(16),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 200,
                      height: 230,
                      decoration: const BoxDecoration(
                        color: Color.fromRGBO(0xEC, 0xEC, 0xEC, 1.0),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add_photo_alternate,
                          size: 107,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 400,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Name'),
                          TextFormField(),
                          const SizedBox(height: 4),
                          const Text('Date of Birth'),
                          TextFormField(),
                          const SizedBox(height: 4),
                          const Text('Birth place'),
                          TextFormField(),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: Navigator.of(context).pop,
                  style: FilledButton.styleFrom(
                    fixedSize: const Size.fromHeight(73),
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddConnectionModal(Node node, Relationship relationship) {
    final graphNotifier = ref.read(graphProvider.notifier);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add a ${relationship.name}'),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(16),
            ),
          ),
          content: SingleChildScrollView(
            child: AddConnectionModal(
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
}

class AddConnectionModal extends ConsumerStatefulWidget {
  final bool showRelationship;
  final Relationship relationship;
  final void Function(String name, Gender gender) onSave;

  const AddConnectionModal({
    super.key,
    this.showRelationship = true,
    required this.relationship,
    required this.onSave,
  });

  @override
  ConsumerState<AddConnectionModal> createState() => _AddConnectionModalState();
}

class _AddConnectionModalState extends ConsumerState<AddConnectionModal> {
  final _nameController = TextEditingController();
  Gender _gender = Gender.male;
  final _shareButtonKey = GlobalKey();

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
        const SelectableText('Name'),
        const SizedBox(height: 4),
        TextFormField(
          controller: _nameController,
        ),
        const SizedBox(height: 16),
        widget.showRelationship
            ? const SelectableText('Relationship')
            : const SelectableText('Your Gender'),
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
                child: const Text('Male'),
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
                child: const Text('Female'),
              ),
            ),
          ],
        ),
        if (widget.showRelationship) ...[
          const SizedBox(height: 24),
          FilledButton(
            key: _shareButtonKey,
            onPressed: _shareLink,
            style: FilledButton.styleFrom(
              backgroundColor: primaryColor,
              fixedSize: const Size.fromHeight(64),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.share),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Only share this link with your sibling'),
                      Text('They can complete their profile'),
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
        if (widget.showRelationship) ...[
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

class HoverNodeDisplay extends StatefulWidget {
  final Widget child;

  const HoverNodeDisplay({
    super.key,
    required this.child,
  });

  @override
  State<HoverNodeDisplay> createState() => _HoverNodeDisplayState();
}

class _HoverNodeDisplayState extends State<HoverNodeDisplay> {
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

class NodeDisplayFull extends StatelessWidget {
  final Node node;

  const NodeDisplayFull({
    super.key,
    required this.node,
  });

  @override
  Widget build(BuildContext context) {
    final random = Random(node.id.hashCode);
    return Container(
      width: 313,
      height: 347,
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ProfileImage(
          //   'https://d2xzkuyodufiic.cloudfront.net/avatars/${random.nextInt(70)}.jpg',
          // ),
          ProfileImage(
            'https://picsum.photos/${200 + random.nextInt(30)}',
          ),
          Positioned(
            left: 21,
            bottom: 21,
            right: 21,
            child: DefaultTextStyle(
              style: const TextStyle(
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    node.id,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    node.profile.name,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
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

Node generateRandomTree(int totalNodes) {
  final random = Random();
  final nodes = List.generate(totalNodes, (i) => _createNode('$i'));

  for (var i = 1; i < totalNodes; i++) {
    final parentIndex = random.nextInt(i);
    final parent = nodes[parentIndex];
    final child = nodes[i];
    parent.children.add(child);
  }

  return nodes[random.nextInt(totalNodes)];
}

Node makeTallTree() {
  final nodes = List.generate(28, (i) => _createNode('$i'));

  void connect({
    required int spouseA,
    required int spouseB,
    required List<int> children,
  }) {
    nodes[spouseA].spouses.add(nodes[spouseB]);
    nodes[spouseB].spouses.add(nodes[spouseA]);
    nodes[spouseA].children.addAll(children.map((e) => nodes[e]));
    nodes[spouseB].children.addAll(children.map((e) => nodes[e]));
    for (final childIndex in children) {
      nodes[childIndex].parents.addAll([nodes[spouseA], nodes[spouseB]]);
    }
  }

  connect(spouseA: 0, spouseB: 1, children: [2, 4]);
  connect(spouseA: 3, spouseB: 4, children: [7, 8, 10]);
  connect(spouseA: 9, spouseB: 10, children: [16]);
  connect(spouseA: 15, spouseB: 16, children: [19]);
  connect(spouseA: 19, spouseB: 20, children: [24, 25, 27]);
  connect(spouseA: 23, spouseB: 24, children: []);
  connect(spouseA: 26, spouseB: 27, children: []);

  connect(spouseA: 5, spouseB: 6, children: [/*12*,*/ 13]);
  // connect(spouseA: 11, spouseB: 12, children: []);
  connect(spouseA: 13, spouseB: 14, children: [18]);
  connect(spouseA: 17, spouseB: 18, children: [20, 22]);
  connect(spouseA: 21, spouseB: 22, children: []);

  final focalNode = nodes[25];
  markAncestorCouplesWithSeparateRoots(focalNode);
  markAncestors(focalNode, true);

  return focalNode;
}

Node makeWideTree() {
  final nodes = List.generate(40, (i) => _createNode('$i'));

  void connect({
    required int spouseA,
    required int spouseB,
    required List<int> children,
  }) {
    nodes[spouseA].spouses.add(nodes[spouseB]);
    nodes[spouseB].spouses.add(nodes[spouseA]);
    nodes[spouseA].children.addAll(children.map((e) => nodes[e]));
    nodes[spouseB].children.addAll(children.map((e) => nodes[e]));
    for (final childIndex in children) {
      nodes[childIndex].parents.addAll([nodes[spouseA], nodes[spouseB]]);
    }
  }

  connect(
      spouseA: 0,
      spouseB: 1,
      children: [5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 24]);
  connect(spouseA: 2, spouseB: 3, children: [25, 27]);

  connect(spouseA: 4, spouseB: 5, children: []);
  connect(spouseA: 6, spouseB: 7, children: []);
  connect(spouseA: 8, spouseB: 9, children: [28, 29, 30, 31, 32, 33, 34, 35]);
  connect(spouseA: 10, spouseB: 11, children: []);
  connect(spouseA: 12, spouseB: 13, children: []);
  connect(spouseA: 14, spouseB: 15, children: []);
  connect(spouseA: 16, spouseB: 17, children: []);
  connect(spouseA: 18, spouseB: 19, children: []);
  connect(spouseA: 20, spouseB: 21, children: []);
  connect(spouseA: 22, spouseB: 23, children: []);
  connect(spouseA: 24, spouseB: 25, children: [37, 39]);

  connect(spouseA: 26, spouseB: 27, children: []);

  connect(spouseA: 36, spouseB: 37, children: []);
  connect(spouseA: 38, spouseB: 39, children: []);

  final focalNode = nodes[37];
  markAncestorCouplesWithSeparateRoots(focalNode);
  markAncestors(focalNode, true);

  return focalNode;
}

Node makeManyAncestoryTree() {
  final nodes = List.generate(33, (i) => _createNode('$i'));

  void connect({
    required int spouseA,
    required int spouseB,
    required List<int> children,
  }) {
    nodes[spouseA].spouses.add(nodes[spouseB]);
    nodes[spouseB].spouses.add(nodes[spouseA]);
    nodes[spouseA].children.addAll(children.map((e) => nodes[e]));
    nodes[spouseB].children.addAll(children.map((e) => nodes[e]));
    for (final childIndex in children) {
      nodes[childIndex].parents.addAll([nodes[spouseA], nodes[spouseB]]);
    }
  }

  connect(spouseA: 0, spouseB: 1, children: [5]);
  connect(spouseA: 2, spouseB: 3, children: [9, 11]);

  connect(spouseA: 4, spouseB: 5, children: [14, 15]);
  connect(spouseA: 6, spouseB: 7, children: [16, 17]);
  connect(spouseA: 8, spouseB: 9, children: [18, 19]);
  connect(spouseA: 10, spouseB: 11, children: []);
  connect(spouseA: 12, spouseB: 13, children: [20, 22]);

  connect(spouseA: 15, spouseB: 16, children: [23, 24, 25]);
  connect(spouseA: 19, spouseB: 20, children: [26, 28, 30]);
  connect(spouseA: 21, spouseB: 22, children: []);
  connect(spouseA: 25, spouseB: 26, children: [32]);
  connect(spouseA: 27, spouseB: 28, children: []);

  connect(spouseA: 29, spouseB: 30, children: []);

  connect(spouseA: 31, spouseB: 32, children: []);

  final focalNode = nodes[32];
  markAncestorCouplesWithSeparateRoots(focalNode);
  markAncestors(focalNode, true);

  return focalNode;
}

Node _createNode(String id) {
  return Node(
    id: id,
    parents: [],
    children: [],
    spouses: [],
    parentIds: [],
    spouseIds: [],
    childIds: [],
    addedBy: '',
    ownedBy: '',
    createdAt: DateTime.now(),
    profile: Profile(
      name: 'name',
      gender: Gender.male,
      birthday: DateTime.now(),
    ),
  );
}
