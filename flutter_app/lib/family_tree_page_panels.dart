import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heritage/api.dart';
import 'package:heritage/date.dart';
import 'package:heritage/family_tree_page.dart';
import 'package:heritage/file_picker.dart';
import 'package:heritage/graph_provider.dart';
import 'package:heritage/graph_view.dart';
import 'package:heritage/help.dart';
import 'package:heritage/image_croper.dart';
import 'package:heritage/layout.dart';
import 'package:heritage/profile_display.dart';
import 'package:heritage/profile_update.dart';
import 'package:heritage/util.dart';

class Panels extends ConsumerStatefulWidget {
  final Person? selectedPerson;
  final Relatedness? relatedness;
  final Person focalPerson;
  final PanelPopupState panelPopupState;
  final VoidCallback onDismissPanelPopup;
  final void Function(Relationship relationship) onAddConnectionPressed;
  final VoidCallback onViewPerspective;

  const Panels({
    super.key,
    required this.selectedPerson,
    required this.relatedness,
    required this.focalPerson,
    required this.panelPopupState,
    required this.onDismissPanelPopup,
    required this.onAddConnectionPressed,
    required this.onViewPerspective,
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
    final isMe = selectedPerson?.id == widget.focalPerson.id;
    final isOwnedByMe =
        isMe || selectedPerson?.ownedBy == widget.focalPerson.id;
    final small = _layout == LayoutType.small;

    // Clamped in case of narrow, but extremely tall/short windows
    final windowSize = MediaQuery.of(context).size;
    final minPanelHeight =
        widget.selectedPerson?.ownedBy == null ? 180.0 : 250.0;
    final minPanelRatio = (minPanelHeight / windowSize.height).clamp(0.05, 0.7);
    return Stack(
      children: [
        if (small) ...[
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding:
                  EdgeInsets.only(top: 16 + MediaQuery.of(context).padding.top),
              child: const LogoText(),
            ),
          ),
          Positioned(
            left: 0,
            bottom: minPanelHeight,
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 16.0, bottom: 16),
                child: _MenuButtons(),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: DraggableScrollableSheet(
                expand: false,
                snap: true,
                initialChildSize: minPanelRatio,
                minChildSize: minPanelRatio,
                maxChildSize: 1.0,
                builder: (context, controller) {
                  return Container(
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
                    child: Builder(
                      builder: (context) {
                        final person = widget.selectedPerson?.ownedBy == null
                            ? widget.focalPerson
                            : widget.selectedPerson!;
                        final relatedness = widget.relatedness;
                        return SingleChildScrollView(
                          key: Key(person.id),
                          controller: controller,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: ProfileDisplay(
                              key: Key(person.id),
                              id: person.id,
                              profile: person.profile,
                              isMe: isMe,
                              isEditable: isOwnedByMe,
                              hasDifferentOwner: person.ownedBy != person.id,
                              header: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (isMe)
                                    Center(
                                      child: Text(person.profile.fullName),
                                    ),
                                  buildAddConnectionButtons(
                                    person: person,
                                    relatedness: relatedness ??
                                        const Relatedness(
                                            isBloodRelative: true,
                                            isAncestor: false,
                                            relativeLevel: 0),
                                    onAddConnectionPressed:
                                        widget.onAddConnectionPressed,
                                  ),
                                ],
                              ),
                              onViewPerspective: widget.onViewPerspective,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          )
        ] else ...[
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 24,
            width: 390,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 32.0),
              child: LogoText(),
            ),
          ),
          const Positioned(
            right: 24,
            bottom: 24,
            child: _MenuButtons(),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 120 + 32,
            left: 24,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            width: 390,
            child: Align(
              alignment: Alignment.topCenter,
              child: AnimatedSidePanel(
                child: switch (widget.panelPopupState) {
                  PanelPopupStateNone() => null,
                  PanelPopupStateProfile(:final person) => _SidePanelContainer(
                      key: Key('profile_${person.id}'),
                      child: ProfileDisplay(
                        id: person.id,
                        profile: person.profile,
                        isMe: isMe,
                        isEditable: isOwnedByMe,
                        hasDifferentOwner: person.ownedBy != person.id,
                        header: null,
                        onViewPerspective: widget.onViewPerspective,
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
                        onSave: (firstName, lastName, gender) =>
                            _saveNewConnection(firstName, lastName, gender,
                                person, relationship),
                      ),
                    ),
                  PanelPopupStateWaitingForApproval(:final person) =>
                    _SidePanelContainer(
                      key: Key('approval_${person.id}'),
                      child: Column(
                        children: [
                          Text(
                            'Waiting for ${person.profile.firstName}\'s approval',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          WaitingForApprovalDisplay(
                            person: person,
                            onAddConnectionPressed: null,
                            onSaveAndShare: (firstName, lastName, gender) =>
                                _onSaveAndShare(
                                    person.id, firstName, lastName, gender),
                          ),
                        ],
                      ),
                    ),
                },
              ),
            ),
          ),
          if (selectedPerson != null && relatedness != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Container(
                  width: 447,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(36)),
                    boxShadow: [
                      BoxShadow(
                        offset: Offset(0, 4),
                        blurRadius: 16,
                        color: Color.fromRGBO(0x00, 0x00, 0x00, 0.25),
                      ),
                    ],
                  ),
                  child: buildAddConnectionButtons(
                    person: selectedPerson,
                    relatedness: relatedness,
                    onAddConnectionPressed: widget.onAddConnectionPressed,
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

  void _onChangePopupState() {
    switch (_layout) {
      case LayoutType.small:
        switch (widget.panelPopupState) {
          case PanelPopupStateNone():
            // TODO: Possibly declaratively dismiss popup
            break;
          case PanelPopupStateProfile():
            // Handled in build() by bottom panel
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
      // Panels handled in build() by side panel
    }
  }

  void _showOwnershipModal({
    required Person person,
    required VoidCallback onAddConnectionPressed,
  }) async {
    final shouldDismiss = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          key: _modalKey,
          title: Text('Waiting for ${person.profile.firstName}\'s approval'),
          content: WaitingForApprovalDisplay(
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
          ),
        );
      },
    );
    if (mounted && shouldDismiss == true) {
      widget.onDismissPanelPopup();
    }
  }

  void _showAddConnectionModal(Person person, Relationship relationship) async {
    final shouldDismiss = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          key: _modalKey,
          content: SingleChildScrollView(
            child: AddConnectionDisplay(
              relationship: relationship,
              onSave: (firstName, lastName, gender) async {
                await _saveNewConnection(
                    firstName, lastName, gender, person, relationship);
                if (context.mounted) {
                  Navigator.of(context).pop(true);
                }
              },
            ),
          ),
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
      await shareInvite(firstName, newId);
      // if (mounted) {
      // WidgetsBinding.instance.endOfFrame.then((_) {
      //   if (mounted) {
      //     _familyTreeViewKey.currentState?.centerOnPersonWithId(person.id);
      //   }
      // });
      // }
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
        ProfileUpdate(
          profile: person.profile.copyWith(
            firstName: firstName,
            lastName: lastName,
            gender: gender,
          ),
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
    showShareSuccess(context: context, type: type);
  }
}

Widget buildAddConnectionButtons({
  required Person person,
  required Relatedness relatedness,
  required void Function(Relationship relationship) onAddConnectionPressed,
}) {
  return AddConnectionButtons(
    enabled: relatedness.isBloodRelative,
    canAddParent: person.parents.isEmpty,
    canAddChildren:
        relatedness.isAncestor || !relatedness.isGrandparentLevelOrHigher,
    onAddConnectionPressed: onAddConnectionPressed,
  );
}

class _MenuButtons extends StatelessWidget {
  const _MenuButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            fixedSize: const Size.square(56),
          ),
          child: const Icon(Icons.home_filled),
        ),
        const SizedBox(width: 16),
        FilledButton(
          onPressed: () => showHelpDialog(context: context),
          style: FilledButton.styleFrom(
            fixedSize: const Size.square(56),
          ),
          child: const Icon(Icons.question_mark),
        ),
      ],
    );
  }
}

class AnimatedSidePanel extends StatefulWidget {
  final Widget? child;

  const AnimatedSidePanel({
    super.key,
    required this.child,
  });

  @override
  State<AnimatedSidePanel> createState() => _AnimatedSidePanelState();
}

class _AnimatedSidePanelState extends State<AnimatedSidePanel> {
  Widget? _child;

  @override
  void initState() {
    super.initState();
    _child = widget.child;
  }

  @override
  void didUpdateWidget(covariant AnimatedSidePanel oldWidget) {
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
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(36)),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 4),
            blurRadius: 16,
            color: Color.fromRGBO(0x00, 0x00, 0x00, 0.25),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    );
  }
}

class ProfileDisplay extends StatelessWidget {
  final String id;
  final Profile profile;
  final bool isMe;
  final bool isEditable;
  final bool hasDifferentOwner;
  final ScrollController? scrollController;
  final Widget? header;
  final VoidCallback onViewPerspective;

  const ProfileDisplay({
    super.key,
    required this.id,
    required this.profile,
    required this.isMe,
    required this.isEditable,
    required this.hasDifferentOwner,
    this.scrollController,
    this.header,
    required this.onViewPerspective,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        profileUpdateProvider.overrideWith(
            (ref) => ProfileUpdateNotifier(initialProfile: profile)),
      ],
      child: _ProfileDisplay(
        id: id,
        isMe: isMe,
        isEditable: isEditable,
        hasDifferentOwner: hasDifferentOwner,
        header: header,
        onViewPerspective: onViewPerspective,
      ),
    );
  }
}

class LogoText extends StatelessWidget {
  const LogoText({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Image.asset(
        'assets/images/logo_text.webp',
        width: 300,
      ),
    );
  }
}

class _ProfileDisplay extends ConsumerStatefulWidget {
  final String id;
  final bool isMe;
  final bool isEditable;
  final bool hasDifferentOwner;
  final Widget? header;
  final VoidCallback onViewPerspective;

  const _ProfileDisplay({
    super.key,
    required this.id,
    required this.isMe,
    required this.isEditable,
    required this.hasDifferentOwner,
    required this.header,
    required this.onViewPerspective,
  });

  @override
  ConsumerState<_ProfileDisplay> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<_ProfileDisplay> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _birthdayController;
  late final TextEditingController _deathdayController;
  late final TextEditingController _birthplaceController;
  bool _submitting = false;

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
    _birthplaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.header;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            ref.watch(profileUpdateProvider.select((p) => p.fullName)),
            style: const TextStyle(
              fontSize: 24,
            ),
          ),
        ),
        if (header != null) ...[
          const SizedBox(height: 24),
          header,
          const SizedBox(height: 16),
          const Divider(height: 1),
        ],
        const SizedBox(height: 24),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _pickPhotoWithSource(context),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              child: ProfileImage(
                imageUrl:
                    ref.watch(profileUpdateProvider.select((p) => p.imageUrl)),
                image: ref.watch(profileUpdateProvider.select((p) => p.image)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (!widget.isMe) ...[
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
        TextFormField(
          controller: _firstNameController,
          enabled: widget.isEditable,
          onChanged: ref.read(profileUpdateProvider.notifier).firstName,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            label: Text('First Name'),
          ),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _lastNameController,
          enabled: widget.isEditable,
          onChanged: ref.read(profileUpdateProvider.notifier).lastName,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            label: Text('Last Name'),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: TextFormField(
                controller: _birthdayController,
                enabled: widget.isEditable,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [DateTextFormatter()],
                onChanged: ref.read(profileUpdateProvider.notifier).birthday,
                decoration: InputDecoration(
                  label: const Text('Date of birth'),
                  hintText: getFormattedDatePattern().formatted,
                ),
              ),
            ),
            if (widget.isEditable)
              IconButton(
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
                  ref.read(profileUpdateProvider.notifier).birthdayObject(date);
                },
                icon: const Icon(Icons.calendar_month),
              ),
          ],
        ),
        if (widget.hasDifferentOwner ||
            ref.watch(
                profileUpdateProvider.select((s) => s.deathday != null))) ...[
          const SizedBox(height: 24),
          TextFormField(
            controller: _deathdayController,
            enabled: widget.isEditable,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [DateTextFormatter()],
            onChanged: ref.read(profileUpdateProvider.notifier).deathday,
            decoration: InputDecoration(
              label: const Text('Date of passing'),
              hintText: getFormattedDatePattern().formatted,
            ),
          ),
        ],
        const SizedBox(height: 24),
        TextFormField(
          controller: _birthplaceController,
          enabled: widget.isEditable,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: ref.read(profileUpdateProvider.notifier).birthplace,
          decoration: const InputDecoration(
            label: Text('Place of birth'),
          ),
          onFieldSubmitted: (_) {},
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  fixedSize: const Size.fromHeight(48),
                  backgroundColor: ref.watch(profileUpdateProvider
                          .select((p) => p.gender == Gender.male))
                      ? null
                      : Colors.grey,
                ),
                onPressed: !widget.isEditable
                    ? null
                    : () => ref
                        .read(profileUpdateProvider.notifier)
                        .gender(Gender.male),
                child: const Text('Male'),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  fixedSize: const Size.fromHeight(48),
                  backgroundColor: ref.watch(profileUpdateProvider
                          .select((p) => p.gender == Gender.female))
                      ? null
                      : Colors.grey,
                ),
                onPressed: !widget.isEditable
                    ? null
                    : () => ref
                        .read(profileUpdateProvider.notifier)
                        .gender(Gender.female),
                child: const Text('Female'),
              ),
            ),
          ],
        ),
        if (widget.isEditable) ...[
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              fixedSize: const Size.fromHeight(48),
            ),
            child: const Text('Delete profile information from the tree'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              fixedSize: const Size.fromHeight(73),
            ),
            child: _submitting
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : const Text('Save'),
          ),
        ],
      ],
    );
  }

  Future<void> _pickPhotoWithSource(BuildContext context) async {
    await showBlockingModal(context, _pickPhoto(source: PhotoSource.gallery));
  }

  Future<void> _pickPhoto({required PhotoSource source}) async {
    final file = await pickPhoto(source: source);
    final image = await file?.readAsBytes();
    if (!mounted || image == null) {
      return;
    }
    final (frame, size) = await getFirstFrameAndSize(image);
    if (!mounted || frame == null) {
      return;
    }
    final cropped = await showCropDialog(context, frame, size);
    if (cropped != null) {
      ref.read(profileUpdateProvider.notifier).image(cropped);
    }
  }

  void _submit() async {
    final profileUpdate = ref.read(profileUpdateProvider);
    final notifier = ref.read(graphProvider.notifier);
    setState(() => _submitting = true);
    await notifier.updateProfile(widget.id, profileUpdate);
    if (mounted) {
      setState(() => _submitting = false);
    }
  }
}

class WaitingForApprovalDisplay extends StatefulWidget {
  final Person person;
  final VoidCallback? onAddConnectionPressed;
  final void Function(String firstName, String lastName, Gender gender)
      onSaveAndShare;

  const WaitingForApprovalDisplay({
    super.key,
    required this.person,
    required this.onAddConnectionPressed,
    required this.onSaveAndShare,
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
      children: [
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
        ShareLinkButton(
          firstName: _firstName,
          onPressed: () =>
              widget.onSaveAndShare(_firstName, _lastName, _gender),
        ),
        const SizedBox(height: 16),
        if (widget.onAddConnectionPressed != null)
          TextButton(
            onPressed: widget.onAddConnectionPressed,
            child: const Text('Attach a family member'),
          ),
      ],
    );
  }
}

class ProfileImage extends StatelessWidget {
  final String? imageUrl;
  final Uint8List? image;

  const ProfileImage({
    super.key,
    required this.imageUrl,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    final imageUrl = this.imageUrl;
    if (image != null) {
      return ImageAspect(
        child: Image.memory(
          image,
          fit: BoxFit.cover,
        ),
      );
    } else if (imageUrl != null) {
      return ImageAspect(
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
        ),
      );
    }
    return const ImageAspect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: Icon(
          Icons.person,
        ),
      ),
    );
  }
}

sealed class PanelPopupState {}

class PanelPopupStateNone implements PanelPopupState {
  const PanelPopupStateNone();
}

class PanelPopupStateProfile implements PanelPopupState {
  final Person person;

  PanelPopupStateProfile({
    required this.person,
  });

  @override
  int get hashCode => person.hashCode;

  @override
  bool operator ==(Object other) {
    return other is PanelPopupStateProfile && other.person == person;
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
