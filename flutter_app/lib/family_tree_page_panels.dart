import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heritage/api.dart';
import 'package:heritage/date.dart';
import 'package:heritage/file_picker.dart';
import 'package:heritage/graph_provider.dart';
import 'package:heritage/profile_update.dart';
import 'package:heritage/util.dart';

class ProfileEditor extends StatelessWidget {
  final String id;
  final Profile profile;

  const ProfileEditor({
    super.key,
    required this.id,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        profileUpdateProvider.overrideWith(
            (ref) => ProfileUpdateNotifier(initialProfile: profile)),
      ],
      child: _ProfileEditor(
        id: id,
      ),
    );
  }
}

class _ProfileEditor extends ConsumerStatefulWidget {
  final String id;
  final bool hasDifferentOwner;

  const _ProfileEditor({
    super.key,
    required this.id,
    this.hasDifferentOwner = false,
  });

  @override
  ConsumerState<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<_ProfileEditor> {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: _pickPhoto,
            child: AspectRatio(
              aspectRatio: 1.0,
              child: ProfileImage(
                imageUrl:
                    ref.watch(profileUpdateProvider.select((p) => p.imageUrl)),
                image: ref.watch(profileUpdateProvider.select((p) => p.image)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            onChanged: ref.read(profileUpdateProvider.notifier).name,
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
        ],
      ),
    );
  }

  void _pickPhoto() async {
    final image = await pickPhoto(context);
    if (!mounted) {
      return;
    }
    if (image != null) {
      ref.read(profileUpdateProvider.notifier).image(image);
    }
  }

  void _submit() async {
    final profileUpdate = ref.read(profileUpdateProvider);
    final notifier = ref.read(graphProvider.notifier);
    setState(() => _submitting = true);
    await notifier.updateProfile(widget.id, profileUpdate);
    if (mounted) {
      setState(() => _submitting = false);

      Navigator.of(context).pop();
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
      return Image.memory(
        image,
        fit: BoxFit.cover,
      );
    } else if (imageUrl != null) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
      );
    }
    return const FittedBox(
      fit: BoxFit.cover,
      child: Icon(
        Icons.person,
      ),
    );
  }
}
