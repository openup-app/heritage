import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:heritage/api.dart';
import 'package:heritage/date.dart';
import 'package:heritage/heritage_app.dart';
import 'package:heritage/photo_management.dart';
import 'package:heritage/profile_update.dart';
import 'package:heritage/util.dart';
import 'package:path_drawing/path_drawing.dart' as path_drawing;

class ProfileDisplay extends StatelessWidget {
  final Profile initialProfile;
  final bool isEditable;
  final bool maybeShowDateOfPassing;
  final VoidCallback? onViewPerspective;
  final VoidCallback? onShareLoginLink;
  final VoidCallback? onDeletePerson;
  final void Function(Profile profile) onSaveProfile;

  const ProfileDisplay({
    super.key,
    required this.initialProfile,
    required this.isEditable,
    required this.maybeShowDateOfPassing,
    required this.onViewPerspective,
    required this.onShareLoginLink,
    required this.onDeletePerson,
    required this.onSaveProfile,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        profileUpdateProvider.overrideWith(
            (ref) => ProfileUpdateNotifier(initialProfile: initialProfile)),
      ],
      child: _ProfileDisplay(
        isEditable: isEditable,
        maybeShowDateOfPassing: maybeShowDateOfPassing,
        onViewPerspective: onViewPerspective,
        onShareLoginLink: onShareLoginLink,
        onDeletePerson: onDeletePerson,
        onSaveProfile: onSaveProfile,
      ),
    );
  }
}

class _ProfileDisplay extends ConsumerStatefulWidget {
  final bool isEditable;
  final bool maybeShowDateOfPassing;
  final VoidCallback? onViewPerspective;
  final VoidCallback? onShareLoginLink;
  final VoidCallback? onDeletePerson;
  final void Function(Profile profile) onSaveProfile;

  const _ProfileDisplay({
    super.key,
    required this.isEditable,
    required this.maybeShowDateOfPassing,
    required this.onViewPerspective,
    required this.onShareLoginLink,
    required this.onDeletePerson,
    required this.onSaveProfile,
  });

  @override
  ConsumerState<_ProfileDisplay> createState() => _ProfileDisplayState();
}

class _ProfileDisplayState extends ConsumerState<_ProfileDisplay> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _birthdayController;
  late final TextEditingController _deathdayController;
  late final TextEditingController _birthplaceController;
  late final TextEditingController _occupationController;
  late final TextEditingController _hobbiesController;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileUpdateProvider);
    _firstNameController = TextEditingController(text: profile.firstName);
    _lastNameController = TextEditingController(text: profile.lastName);
    _birthdayController = TextEditingController();
    _deathdayController = TextEditingController();
    _birthplaceController = TextEditingController(text: profile.birthplace);
    _occupationController = TextEditingController(text: profile.occupation);
    _hobbiesController = TextEditingController(text: profile.hobbies);

    final birthday = profile.birthday;
    final deathday = profile.deathday;
    _birthdayController.text = birthday == null ? '' : formatDate(birthday);
    _deathdayController.text = deathday == null ? '' : formatDate(deathday);

    ref.listenManual(profileUpdateProvider, (previous, next) {
      if (previous != next) {
        widget.onSaveProfile(next);
      }
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthdayController.dispose();
    _deathdayController.dispose();
    _birthplaceController.dispose();
    _occupationController.dispose();
    _hobbiesController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasDateOfPassing = widget.maybeShowDateOfPassing &&
        ref.watch(profileUpdateProvider.select((s) => s.deathday != null));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.isEditable) ...[
          const SizedBox(height: 24),
          Text(
            'Profile Picture',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Add your profile picture',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: AddProfilePhotoButton(
              photo: ref.watch(profileUpdateProvider.select((p) => p.photo)),
              onPhoto: ref.read(profileUpdateProvider.notifier).photo,
              onDelete: () {
                final notifier = ref.read(profileUpdateProvider.notifier);
                notifier.photo(
                  const Photo.network(
                    key: 'public/no_image.png',
                    url: '$cdn/public/no_image.png',
                  ),
                );
              },
            ),
          ),
        ],
        if (widget.onViewPerspective != null) ...[
          const SizedBox(height: 18),
          FilledButton(
            onPressed: widget.onViewPerspective,
            style: FilledButton.styleFrom(
              fixedSize: const Size.fromHeight(44),
              foregroundColor: Colors.white,
              backgroundColor: primaryColor,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Binoculars(
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                    'View ${ref.watch(profileUpdateProvider.select((s) => s.fullName))}\'s tree'),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Details',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (widget.isEditable) ...[
          const SizedBox(height: 4),
          Text(
            'Add some information about yourself so your family can see',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
        ],
        Column(
          children: [
            FocusTraversalGroup(
              child: InputForm(
                children: [
                  InputLabel(
                    label: 'First name',
                    child: TextFormField(
                      controller: _firstNameController,
                      enabled: widget.isEditable,
                      onChanged:
                          ref.read(profileUpdateProvider.notifier).firstName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  InputLabel(
                    label: 'Last name',
                    child: TextFormField(
                      controller: _lastNameController,
                      enabled: widget.isEditable,
                      onChanged:
                          ref.read(profileUpdateProvider.notifier).lastName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  InputLabel(
                    label: 'Date of birth',
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _birthdayController,
                            enabled: widget.isEditable,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [DateTextFormatter()],
                            onChanged: ref
                                .read(profileUpdateProvider.notifier)
                                .birthday,
                            decoration: InputDecoration(
                              hintText: getFormattedDatePattern().formatted,
                            ),
                          ),
                        ),
                        if (widget.isEditable)
                          ExcludeFocus(
                            child: IconButton(
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  firstDate: firstDate,
                                  lastDate: lastDate,
                                  initialDate: ref.watch(profileUpdateProvider
                                      .select((p) => p.birthday ?? lastDate)),
                                );
                                if (!mounted || date == null) {
                                  return;
                                }
                                _birthdayController.text = formatDate(date);
                                ref
                                    .read(profileUpdateProvider.notifier)
                                    .birthdayObject(date);
                              },
                              icon: const Icon(
                                Icons.calendar_month,
                                color: Color.fromRGBO(138, 138, 138, 1),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (hasDateOfPassing)
                    InputLabel(
                      label: 'Date of passing',
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _deathdayController,
                              enabled: widget.isEditable,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [DateTextFormatter()],
                              onChanged: ref
                                  .read(profileUpdateProvider.notifier)
                                  .deathday,
                              decoration: InputDecoration(
                                hintText: getFormattedDatePattern().formatted,
                              ),
                            ),
                          ),
                          if (widget.isEditable)
                            ExcludeFocus(
                              child: IconButton(
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    firstDate: firstDate,
                                    lastDate: lastDate,
                                    initialDate: ref.watch(profileUpdateProvider
                                        .select((p) => p.deathday ?? lastDate)),
                                  );
                                  if (!mounted || date == null) {
                                    return;
                                  }
                                  _deathdayController.text = formatDate(date);
                                  ref
                                      .read(profileUpdateProvider.notifier)
                                      .deathdayObject(date);
                                },
                                icon: const Icon(
                                  Icons.calendar_month,
                                  color: Color.fromRGBO(138, 138, 138, 1),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  InputLabel(
                    label: 'Place of birth',
                    child: TextFormField(
                      controller: _birthplaceController,
                      enabled: widget.isEditable,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onChanged:
                          ref.read(profileUpdateProvider.notifier).birthplace,
                    ),
                  ),
                  InputLabel(
                    label: 'Occupation',
                    child: TextFormField(
                      controller: _occupationController,
                      enabled: widget.isEditable,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onChanged:
                          ref.read(profileUpdateProvider.notifier).occupation,
                    ),
                  ),
                  InputLabel(
                    label: 'Hobbies',
                    child: TextFormField(
                      controller: _hobbiesController,
                      enabled: widget.isEditable,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onChanged:
                          ref.read(profileUpdateProvider.notifier).hobbies,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.isEditable) ...[
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Gender',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Needed to list you properly in the tree',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final gender in Gender.values) ...[
                    if (gender != Gender.values.first)
                      const SizedBox(width: 16),
                    Expanded(
                      child: Builder(builder: (context) {
                        final selectedGender = ref.watch(
                            profileUpdateProvider.select((p) => p.gender));
                        return FilledButton(
                          onPressed: () => ref
                              .read(profileUpdateProvider.notifier)
                              .gender(gender),
                          style: FilledButton.styleFrom(
                            fixedSize: const Size.fromHeight(44),
                            foregroundColor:
                                selectedGender == gender ? Colors.white : null,
                            backgroundColor:
                                selectedGender == gender ? primaryColor : null,
                          ),
                          child: Text(
                              '${gender.name[0].toUpperCase()}${gender.name.substring(1)}'),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ],
            if (ref.watch(
                profileUpdateProvider.select((p) => p.gallery.isNotEmpty))) ...[
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                child: GalleryView(
                  photos:
                      ref.watch(profileUpdateProvider.select((p) => p.gallery)),
                ),
              ),
            ],
            if (widget.isEditable) ...[
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Gallery',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add photos for your family to see',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: PhotoManagement(
                  gallery:
                      ref.watch(profileUpdateProvider.select((p) => p.gallery)),
                  onChanged: ref.read(profileUpdateProvider.notifier).gallery,
                  onProfilePhotoChanged: (photo) {
                    ref.read(profileUpdateProvider.notifier).photo(photo);
                    widget.onSaveProfile(ref.read(profileUpdateProvider));
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (widget.onShareLoginLink != null) ...[
          Text(
            'Login Link',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Builder(
            builder: (context) {
              final name =
                  ref.watch(profileUpdateProvider.select((s) => s.firstName));
              return Text(
                'Visible to direct relatives for login assistance. Share this with $name, sharing it with others risks the family tree.',
                style: Theme.of(context).textTheme.labelLarge,
              );
            },
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: widget.onShareLoginLink,
            style: FilledButton.styleFrom(
              fixedSize: const Size.fromHeight(44),
              foregroundColor: Colors.white,
              backgroundColor: primaryColor,
            ),
            child: const Text(
              'Share Login Link',
            ),
          ),
        ],
        if (widget.onDeletePerson != null) ...[
          const SizedBox(height: 24),
          TextButton(
            onPressed: _onConfirmDeleteManagedUser,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(
                'Delete ${ref.watch(profileUpdateProvider.select((p) => p.firstName))} from the tree'),
          ),
          const SizedBox(height: 24),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  void _onConfirmDeleteManagedUser() async {
    final profile = ref.watch(profileUpdateProvider);
    final delete = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete ${profile.firstName}?'),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (mounted && delete == true) {
      widget.onDeletePerson?.call();
    }
  }
}

class FormBorder extends StatelessWidget {
  final Widget child;

  const FormBorder({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: child,
    );
  }
}

class InputForm extends StatelessWidget {
  final List<Widget> children;

  const InputForm({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return FormBorder(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, child) in children.indexed) ...[
            child,
            if (index != children.length - 1)
              const Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: Color.fromRGBO(0xD8, 0xD8, 0xD8, 1.0),
              ),
          ],
        ],
      ),
    );
  }
}

class InputLabel extends StatelessWidget {
  final String label;
  final String? hintText;
  final Widget child;

  const InputLabel({
    super.key,
    required this.label,
    this.hintText,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12.0, top: 8.0),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color.fromRGBO(0x51, 0x51, 0x51, 1.0),
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Theme(
            data: Theme.of(context).copyWith(
                inputDecorationTheme: const InputDecorationTheme(
              isCollapsed: true,
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              fillColor: Colors.transparent,
            )),
            child: child,
          ),
        ),
      ],
    );
  }
}

class GalleryView extends StatefulWidget {
  final List<Photo> photos;
  const GalleryView({
    super.key,
    required this.photos,
  });

  @override
  State<GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  static const _largeNumber = 1000000000;

  late final PageController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    const center = _largeNumber ~/ 2;
    final int initialIndex;
    if (widget.photos.isEmpty) {
      initialIndex = center;
    } else {
      initialIndex = center ~/ widget.photos.length * widget.photos.length;
    }
    _controller = PageController(
      initialPage: initialIndex,
    );
    _controller.addListener(_restartTimer);
    _restartTimer();
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return const ImageAspect(
        child: ColoredBox(
          color: Colors.grey,
        ),
      );
    }
    return ScrollbarTheme(
      data: const ScrollbarThemeData(
        thumbVisibility: WidgetStatePropertyAll(false),
      ),
      child: ImageAspect(
        child: PageView.builder(
          controller: _controller,
          scrollBehavior: const _AllDevicesScrollBehavior(),
          itemCount: _largeNumber,
          itemBuilder: (context, index) {
            final photo = widget.photos[index % widget.photos.length];
            return PhotoDisplay(
              photo: photo,
            );
          },
        ),
      ),
    );
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _onNext());
  }

  void _onNext() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
    );
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

class HoverPersonDisplay extends StatefulWidget {
  final Widget child;

  const HoverPersonDisplay({
    super.key,
    required this.child,
  });

  @override
  State<HoverPersonDisplay> createState() => _HoverPersonDisplayState();
}

class _HoverPersonDisplayState extends State<HoverPersonDisplay> {
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

class NodeProfile extends StatelessWidget {
  final Person person;
  final String relatednessDescription;
  final VoidCallback? onViewPerspectivePressed;

  const NodeProfile({
    super.key,
    required this.person,
    required this.relatednessDescription,
    required this.onViewPerspectivePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 180,
          child: Stack(
            children: [
              Center(
                child: ImageAspect(
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      _DashedBorder(
                        radius: const Radius.circular(20),
                        child: Container(
                          clipBehavior: Clip.hardEdge,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.all(
                              Radius.circular(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                offset: Offset(0, 10),
                                blurRadius: 44,
                                spreadRadius: -11,
                                color: Color.fromRGBO(0x00, 0x00, 0x00, 0.4),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ProfileImage(person.profile.photo),
                              ),
                              const Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: 72,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(20),
                                      bottomRight: Radius.circular(20),
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Color.fromRGBO(0x00, 0x00, 0x00, 0.40),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      relatednessDescription,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      person.profile.firstName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ProfileImage extends StatelessWidget {
  final Photo photo;

  const ProfileImage(this.photo, {super.key});

  @override
  Widget build(BuildContext context) {
    return switch (photo) {
      NetworkPhoto(:final url) => Image.network(
          url,
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
              layoutBuilder:
                  (topChild, topChildKey, bottomChild, bottomChildKey) {
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
        ),
      MemoryPhoto(:final Uint8List bytes) => Image.memory(
          bytes,
          fit: BoxFit.cover,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _DashedBorder extends StatelessWidget {
  final Radius radius;
  final Widget child;

  const _DashedBorder({
    super.key,
    required this.radius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedPainter(
        radius: radius,
      ),
      child: child,
    );
  }
}

class _DashedPainter extends CustomPainter {
  final Radius radius;

  _DashedPainter({
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // canvas.drawRect(Offset.zero & size, Paint()..color = Colors.orange);

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, radius));
    final dashedPath = path_drawing.dashPath(
      path,
      dashArray: path_drawing.CircularIntervalList<double>([7.0, 12.0]),
    );
    canvas.drawPath(
      dashedPath,
      Paint()
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _DashedPainter oldDelegate) {
    return oldDelegate.radius != radius;
  }
}

class Scaler extends StatefulWidget {
  final Duration duration;
  final bool shouldScale;
  final double scale;
  final VoidCallback onEnd;
  final Widget child;

  const Scaler({
    super.key,
    required this.duration,
    required this.shouldScale,
    required this.scale,
    required this.onEnd,
    required this.child,
  });

  @override
  State<Scaler> createState() => _HoverState();
}

class _HoverState extends State<Scaler> {
  var _targetScale = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) {
        if (widget.shouldScale) {
          setState(() => _targetScale = widget.scale);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant Scaler oldWidget) {
    if (widget.shouldScale != oldWidget.shouldScale) {
      _targetScale = widget.shouldScale ? widget.scale : 1.0;
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: widget.duration,
      curve: Curves.easeOutQuart,
      scale: _targetScale,
      onEnd: () {
        if (!widget.shouldScale) {
          widget.onEnd();
        }
      },
      child: widget.child,
    );
  }
}

class MouseOverlay extends StatefulWidget {
  final bool enabled;
  final bool forceOverlay;
  final Widget Function(BuildContext context, bool overlay) builder;

  const MouseOverlay({
    super.key,
    this.enabled = true,
    this.forceOverlay = false,
    required this.builder,
  });

  @override
  State<MouseOverlay> createState() => _MouseOverlayState();
}

class _MouseOverlayState extends State<MouseOverlay> {
  final _controller = OverlayPortalController();
  final _layerLink = LayerLink();
  bool _entered = false;

  @override
  void didUpdateWidget(covariant MouseOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _controller.isShowing) {
      WidgetsBinding.instance.endOfFrame.then((_) {
        if (mounted) {
          setState(() => _controller.hide());
        }
      });
    }
    if (!oldWidget.forceOverlay && widget.forceOverlay) {
      WidgetsBinding.instance.endOfFrame.then((_) {
        if (mounted) {
          setState(() => _controller.show());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _controller,
        overlayChildBuilder: (context) {
          final shouldScale =
              widget.enabled && (_entered || widget.forceOverlay);
          return Align(
            alignment: Alignment.topLeft,
            child: CompositedTransformFollower(
              link: _layerLink,
              child: Scaler(
                duration: const Duration(milliseconds: 300),
                shouldScale: shouldScale,
                scale: 1.5,
                onEnd: () {
                  if (!shouldScale) {
                    setState(() => _controller.hide());
                  }
                },
                child: _MouseRegionWithWorkaround(
                  enabled: widget.enabled,
                  onEnter: () => setState(() => _entered = true),
                  onExit: () => setState(() => _entered = false),
                  child: widget.builder(context, _controller.isShowing),
                ),
              ),
            ),
          );
        },
        child: _MouseRegionWithWorkaround(
          enabled: widget.enabled,
          onEnter: () {
            setState(() {
              _entered = true;
              _controller.show();
            });
          },
          child: Visibility(
            visible: !_controller.isShowing,
            maintainSize: true,
            maintainState: true,
            maintainAnimation: true,
            maintainSemantics: true,
            child: IgnorePointer(
              ignoring: _controller.isShowing,
              child: widget.builder(context, _controller.isShowing),
            ),
          ),
        ),
      ),
    );
  }
}

/// MouseRegion that handles the edge case where cursor starts inside widget.
/// Additionally ignores touch events causing mouse enter/exit events.
class _MouseRegionWithWorkaround extends StatefulWidget {
  final bool enabled;
  final VoidCallback? onEnter;
  final VoidCallback? onExit;
  final Widget child;

  const _MouseRegionWithWorkaround({
    super.key,
    required this.enabled,
    this.onEnter,
    this.onExit,
    required this.child,
  });

  @override
  State<_MouseRegionWithWorkaround> createState() =>
      _MouseRegionWithWorkaroundState();
}

class _MouseRegionWithWorkaroundState
    extends State<_MouseRegionWithWorkaround> {
  bool _entered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      opaque: false,
      onEnter: (p) {
        if (widget.enabled && !_entered && p.kind == PointerDeviceKind.mouse) {
          setState(() => _entered = true);
          widget.onEnter?.call();
        }
      },
      onHover: (p) {
        if (widget.enabled && !_entered && p.kind == PointerDeviceKind.mouse) {
          setState(() => _entered = true);
          widget.onEnter?.call();
        }
      },
      onExit: (p) {
        if (widget.enabled && _entered && p.kind == PointerDeviceKind.mouse) {
          setState(() => _entered = false);
          widget.onExit?.call();
        }
      },
      child: widget.child,
    );
  }
}

class AwaitingInvite extends StatelessWidget {
  const AwaitingInvite({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      width: 128,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color.fromRGBO(0xFF, 0x38, 0x38, 1.0),
      ),
      child: const Text(
        'Awaiting Invite',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}

class Binoculars extends StatelessWidget {
  final double size;

  const Binoculars({
    super.key,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/binoculars.png',
      width: size,
      fit: BoxFit.cover,
    );
  }
}

class VerifiedBadge extends StatelessWidget {
  final double size;

  const VerifiedBadge({
    super.key,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.9,
        child: SvgPicture.asset(
          'assets/images/badge.svg',
          width: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class ImageAspect extends StatelessWidget {
  static const ratio = 151 / 173;

  final Widget child;

  const ImageAspect({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: ratio,
      child: child,
    );
  }
}

class PhotoDisplay extends StatelessWidget {
  final Photo photo;

  const PhotoDisplay({
    super.key,
    required this.photo,
  });

  @override
  Widget build(BuildContext context) {
    return switch (photo) {
      MemoryPhoto(:final Uint8List bytes) => Image.memory(
          bytes,
          fit: BoxFit.cover,
        ),
      NetworkPhoto(:final url) => Image.network(
          url,
          fit: BoxFit.cover,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

/// Allows all device kinds to scroll the scroll view
class _AllDevicesScrollBehavior extends ScrollBehavior {
  const _AllDevicesScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}
