import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heritage/api.dart';
import 'package:heritage/graph.dart';
import 'package:heritage/graph_provider.dart';
import 'package:heritage/graph_view.dart';
import 'package:heritage/heritage_app.dart';
import 'package:heritage/profile_display.dart';
import 'package:heritage/zoomable_pannable_viewport.dart';
import 'package:share_plus/share_plus.dart';

class FamilyTreeLoadingPage extends ConsumerStatefulWidget {
  final Id focalNodeId;
  final Widget Function(BuildContext context, Node focalNode, List<Node> nodes)
      builder;

  const FamilyTreeLoadingPage({
    super.key,
    required this.focalNodeId,
    required this.builder,
  });

  @override
  ConsumerState<FamilyTreeLoadingPage> createState() => ViewPageState();
}

class ViewPageState extends ConsumerState<FamilyTreeLoadingPage> {
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
          return widget.builder(
            context,
            result.focalNode,
            result.nodes.values.toList(),
          );
        },
      ),
    );
  }
}

class FamilyTreeView extends ConsumerStatefulWidget {
  final Node focalNode;
  final List<Node> nodes;

  const FamilyTreeView({
    super.key,
    required this.focalNode,
    required this.nodes,
  });

  @override
  ConsumerState<FamilyTreeView> createState() => _FamilyTreeViewState();
}

class _FamilyTreeViewState extends ConsumerState<FamilyTreeView> {
  final _transformNotifier = ValueNotifier<Matrix4>(Matrix4.identity());

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ZoomablePannableViewport(
        onTransformed: (transform) => _transformNotifier.value = transform,
        child: GraphView(
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
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _showProfile(context, node),
                onDoubleTap: () {
                  ref.read(graphProvider.notifier).fetchConnections(node.id);
                },
                child: MouseHover(
                  transformNotifier: _transformNotifier,
                  builder: (context, hovering) {
                    return ProfileControls(
                      show: hovering,
                      canAddParent: node.parents.isEmpty,
                      onAddConnectionPressed: (relationship) =>
                          _showAddConnectionModal,
                      child: NodeProfile(node: node),
                    );
                  },
                ),
              ),
            );
          },
        ),
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
