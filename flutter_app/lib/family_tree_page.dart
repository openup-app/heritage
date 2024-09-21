import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heritage/api.dart';
import 'package:heritage/date.dart';
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
  const FamilyTreePage({super.key});

  @override
  ConsumerState<FamilyTreePage> createState() => _FamilyTreePageState();
}

class _FamilyTreePageState extends ConsumerState<FamilyTreePage> {
  @override
  Widget build(BuildContext context) {
    final graph = ref.watch(graphProvider);
    return FamilyTreeView(
      focalNode: graph.focalNode,
      nodes: graph.nodes.values.toList(),
      onProfilePressed: _showProfile,
      onAddConnectionPressed: _showAddConnectionModal,
      onFetchConnections: (ids) {},
    );
  }

  void _showProfile(LinkedNode<Node> linkedNode) async {
    // TODO: Need accounts
    final focalNode = ref.read(graphProvider).focalNode;
    final node = linkedNode.data;
    final isMe = focalNode.id == node.id;
    final isOwnedByMe = node.ownedBy == node.id;
    final ownershipClaimed = node.ownedBy != null;
    final profile = await showDialog<Profile>(
      context: context,
      builder: (context) {
        if (!(isMe || isOwnedByMe)) {
          return _ProfileView(
            editable: true,
            ownershipClaimed: ownershipClaimed,
            initialProfile: node.profile,
          );
        } else {
          return AlertDialog(
            content: SizedBox(
              width: 400,
              child: ProfileEditor(
                id: node.id,
                profile: node.profile,
              ),
            ),
          );
        }
      },
    );

    if (!mounted) {
      return;
    }

    if (profile != null) {
      // ref.read(graphProvider.notifier).updateProfile(node.id, profile);
    }
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
}

class FamilyTreeView extends ConsumerStatefulWidget {
  final Node focalNode;
  final List<Node> nodes;
  final void Function(LinkedNode<Node> node) onProfilePressed;
  final void Function(Node node, Relationship relationship)
      onAddConnectionPressed;
  final void Function(List<Id> ids) onFetchConnections;

  const FamilyTreeView({
    super.key,
    required this.focalNode,
    required this.nodes,
    required this.onProfilePressed,
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
        child: GraphView(
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
                      onTap: () => widget.onProfilePressed(linkedNode),
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
  final void Function(String name, Gender gender) onSave;

  const BasicProfileModal({
    super.key,
    this.isRootNodeCreation = false,
    required this.relationship,
    required this.onSave,
  });

  @override
  ConsumerState<BasicProfileModal> createState() => _AddConnectionModalState();
}

class _AddConnectionModalState extends ConsumerState<BasicProfileModal> {
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

class _ProfileView extends StatefulWidget {
  final bool editable;
  final bool ownershipClaimed;
  final Profile initialProfile;

  const _ProfileView({
    super.key,
    required this.editable,
    required this.ownershipClaimed,
    required this.initialProfile,
  });

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _dateOfBirthController;
  late final TextEditingController _birthplaceController;
  bool _valid = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfile.name);
    _dateOfBirthController = TextEditingController(
        text: widget.initialProfile.birthday?.toString() ?? '');
    _birthplaceController =
        TextEditingController(text: widget.initialProfile.birthplace);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateOfBirthController.dispose();
    _birthplaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                GestureDetector(
                  onTap: _showPhotoPicker,
                  child: Container(
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
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: 400,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Name'),
                        TextFormField(
                          controller: _nameController,
                          onChanged: (_) => _validateForm(),
                        ),
                        const SizedBox(height: 4),
                        const Text('Date of Birth'),
                        TextFormField(
                          controller: _dateOfBirthController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [DateTextFormatter()],
                          decoration: InputDecoration(
                            hintText: getFormattedDatePattern().formatted,
                          ),
                          onChanged: (_) => _validateForm(),
                        ),
                        const SizedBox(height: 4),
                        const Text('Birth place'),
                        TextFormField(
                          controller: _birthplaceController,
                          onChanged: (_) => _validateForm(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _valid ? _done : null,
              style: FilledButton.styleFrom(
                fixedSize: const Size.fromHeight(73),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhotoPicker() {}

  void _validateForm() {
    setState(() => _valid = _formKey.currentState?.validate() ?? false);
  }

  void _done() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final name = _nameController.text;
    final newProfile = Profile(
      name: name.isEmpty ? 'Unknown' : name,
      gender: widget.initialProfile.gender,
      imageUrl: widget.initialProfile.imageUrl,
      birthday: widget.initialProfile.birthday,
      deathday: widget.initialProfile.deathday,
      birthplace: widget.initialProfile.birthplace,
    );
    return Navigator.of(context).pop(newProfile);
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
