import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heritage/api.dart';
import 'package:heritage/date.dart';
import 'package:heritage/file_picker.dart';
import 'package:heritage/graph_provider.dart';
import 'package:heritage/image_croper.dart';
import 'package:heritage/layout.dart';
import 'package:heritage/profile_display.dart';
import 'package:heritage/profile_update.dart';
import 'package:heritage/util.dart';

class Panels extends ConsumerStatefulWidget {
  final Node node;
  final VoidCallback onViewPerspective;

  const Panels({
    super.key,
    required this.node,
    required this.onViewPerspective,
  });

  @override
  ConsumerState<Panels> createState() => _PanelsState();
}

class _PanelsState extends ConsumerState<Panels> {
  final _childKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final focalNode = ref.read(graphProvider).focalNode;
    final isMe = focalNode.id == widget.node.id;
    final isOwnedByMe = widget.node.ownedBy == widget.node.id;
    final layout = Layout.of(context);
    final small = layout == LayoutType.small;
    final child = ProfileDisplay(
      id: widget.node.id,
      profile: widget.node.profile,
      isMe: isMe,
      isEditable: isMe || isOwnedByMe,
      hasDifferentOwner: widget.node.ownedBy != widget.node.id,
      padding: small ? const EdgeInsets.all(16) : const EdgeInsets.all(24),
      onViewPerspective: widget.onViewPerspective,
    );
    return Stack(
      children: [
        if (small)
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: DraggableScrollableSheet(
                expand: false,
                snap: true,
                initialChildSize: 0.2,
                minChildSize: 0.2,
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
                    child: SingleChildScrollView(
                      controller: controller,
                      child: KeyedSubtree(
                        key: _childKey,
                        child: child,
                      ),
                    ),
                  );
                },
              ),
            ),
          )
        else
          Positioned(
            left: 16,
            top: 16 + MediaQuery.of(context).padding.top,
            width: 390,
            child: DecoratedBox(
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
              child: KeyedSubtree(
                key: _childKey,
                child: child,
              ),
            ),
          ),
      ],
    );
    // if (!mounted) {
    //   return;
    // }

    // if (profile != null) {
    //   // ref.read(graphProvider.notifier).updateProfile(node.id, profile);
    // }
  }
}

class ProfileDisplay extends StatelessWidget {
  final String id;
  final Profile profile;
  final bool isMe;
  final bool isEditable;
  final bool hasDifferentOwner;
  final ScrollController? scrollController;
  final EdgeInsets padding;
  final VoidCallback onViewPerspective;

  const ProfileDisplay({
    super.key,
    required this.id,
    required this.profile,
    required this.isMe,
    required this.isEditable,
    required this.hasDifferentOwner,
    this.scrollController,
    required this.padding,
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
        scrollController: scrollController,
        padding: padding,
        onViewPerspective: onViewPerspective,
      ),
    );
  }
}

class _ProfileDisplay extends ConsumerStatefulWidget {
  final String id;
  final bool isMe;
  final bool isEditable;
  final bool hasDifferentOwner;
  final ScrollController? scrollController;
  final EdgeInsets padding;
  final VoidCallback onViewPerspective;

  const _ProfileDisplay({
    super.key,
    required this.id,
    required this.isMe,
    required this.isEditable,
    required this.hasDifferentOwner,
    this.scrollController,
    required this.padding,
    required this.onViewPerspective,
  });

  @override
  ConsumerState<_ProfileDisplay> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<_ProfileDisplay> {
  late final TextEditingController _nameController;
  late final TextEditingController _birthdayController;
  late final TextEditingController _deathdayController;
  late final TextEditingController _birthplaceController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileUpdateProvider);
    final deathday = profile.deathday;
    _nameController = TextEditingController(text: profile.name);
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
    _nameController.dispose();
    _birthdayController.dispose();
    _birthplaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: EdgeInsets.only(
        left: widget.padding.left,
        right: widget.padding.right,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: widget.padding.top),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              ref.watch(profileUpdateProvider.select((p) => p.name)),
              style: const TextStyle(
                fontSize: 24,
              ),
            ),
          ),
          const SizedBox(height: 24),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => showBlockingModal(context, _pickPhoto()),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                child: ProfileImage(
                  imageUrl: ref
                      .watch(profileUpdateProvider.select((p) => p.imageUrl)),
                  image:
                      ref.watch(profileUpdateProvider.select((p) => p.image)),
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
                  'View ${ref.watch(profileUpdateProvider.select((s) => s.name))}\'s tree'),
            ),
            const SizedBox(height: 24),
          ],
          TextFormField(
            controller: _nameController,
            onChanged: ref.read(profileUpdateProvider.notifier).name,
            enabled: widget.isEditable,
            decoration: const InputDecoration(
              label: Text('Name'),
            ),
          ),
          const SizedBox(height: 24),
          // TextFormField(
          //   controller: _birthdayController,
          //   keyboardType: TextInputType.number,
          //   inputFormatters: [DateTextFormatter()],
          //   onChanged: ref.read(profileUpdateProvider.notifier).birthday,
          //   decoration: InputDecoration(
          //     label: const Text('Date of birth'),
          //     hintText: getFormattedDatePattern().formatted,
          //   ),
          // ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: InputDatePickerFormField(
                  initialDate: ref.watch(profileUpdateProvider).birthday,
                  firstDate: DateTime(1500, 0, 0),
                  lastDate: DateTime.now(),
                  onDateSubmitted: (date) {},
                  fieldLabelText: 'Date of birth',
                ),
              ),
              IconButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    firstDate: DateTime(1500),
                    lastDate: DateTime.now(),
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
          if (widget.hasDifferentOwner) ...[
            const SizedBox(height: 24),
            TextFormField(
              controller: _deathdayController,
              keyboardType: TextInputType.number,
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
            onChanged: ref.read(profileUpdateProvider.notifier).birthplace,
            decoration: const InputDecoration(
              label: Text('Birthplace'),
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
                  onPressed: () => ref
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
                  onPressed: () => ref
                      .read(profileUpdateProvider.notifier)
                      .gender(Gender.female),
                  child: const Text('Female'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          FilledButton(
            onPressed: launchEmail,
            style: FilledButton.styleFrom(
              fixedSize: const Size.fromHeight(48),
            ),
            child: const Text('Contact us'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              fixedSize: const Size.fromHeight(48),
            ),
            child: const Text('Delete my information from the tree'),
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
          SizedBox(height: widget.padding.bottom),
          SizedBox(
            height: MediaQuery.of(context).padding.bottom,
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final file = await pickPhoto(context);
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
