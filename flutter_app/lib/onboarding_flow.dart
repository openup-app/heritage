import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heritage/api.dart';
import 'package:heritage/family_tree_page.dart';
import 'package:heritage/graph.dart';
import 'package:heritage/heritage_app.dart';
import 'package:heritage/profile_display.dart';
import 'package:heritage/util.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  final LinkedNode<Person> person;
  final LinkedNode<Person> referral;
  final Future<void> Function(Profile profile) onSave;
  final VoidCallback onDone;

  const OnboardingFlow({
    super.key,
    required this.person,
    required this.referral,
    required this.onSave,
    required this.onDone,
  });

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  late final Timer _timer;
  int _step = 0;
  String _firstName = '';
  String _lastName = '';
  Photo? _photo;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _step++);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: switch (_step) {
          0 => const SizedBox.shrink(),
          1 => _IntroStep(
              person: widget.person,
              referral: widget.referral,
              onDone: () => setState(() => _step++),
            ),
          2 => _NameStep(
              onDone: (firstName, lastName) {
                setState(() {
                  _firstName = firstName;
                  _lastName = lastName;
                  _step++;
                });
              },
            ),
          3 => _PhotoStep(
              onDone: _uploading
                  ? null
                  : (photo) async {
                      setState(() => _photo = photo);
                      await _upload();
                    },
            ),
          4 => _ExitStep(
              onDone: widget.onDone,
            ),
          _ => const SizedBox.shrink()
        },
      ),
    );
  }

  Future<void> _upload() async {
    final photo = _photo;
    if (photo == null) {
      return;
    }
    final profile = widget.person.data.profile.copyWith(
      firstName: _firstName,
      lastName: _lastName,
      photo: photo,
    );
    setState(() => _uploading = true);
    await widget.onSave(profile);
    if (!mounted) {
      return;
    }
    setState(() {
      _uploading = false;
      _step++;
    });
  }
}

class _IntroStep extends StatelessWidget {
  final LinkedNode<Person> person;
  final LinkedNode<Person> referral;
  final VoidCallback onDone;

  const _IntroStep({
    super.key,
    required this.person,
    required this.referral,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final description = relatednessDescription(
      referral,
      person,
      pov: PointOfView.second,
    );
    return _Container(
      child: Column(
        children: [
          const Spacer(),
          Center(
            child: _Title(
                icon: null,
                label:
                    '${referral.data.profile.firstName} wants to add you\nas $description!'),
          ),
          const SizedBox(height: 80),
          _Button(
            onPressed: onDone,
            child: const Text('Okay'),
          ),
        ],
      ),
    );
  }
}

class _NameStep extends StatefulWidget {
  final void Function(String firstName, String lastName) onDone;

  const _NameStep({
    super.key,
    required this.onDone,
  });

  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  String _firstName = '';
  String _lastName = '';

  @override
  Widget build(BuildContext context) {
    return _Container(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Title(
            icon: Icon(Icons.person),
            label: 'Your name',
          ),
          const Spacer(),
          MinimalProfileEditor(
            onUpdate: (firstName, lastName) {
              setState(() {
                _firstName = firstName;
                _lastName = lastName;
              });
            },
          ),
          const Spacer(),
          _Button(
            onPressed: _firstName.isEmpty || _lastName.isEmpty
                ? null
                : () => widget.onDone(_firstName, _lastName),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _PhotoStep extends StatefulWidget {
  final void Function(Photo photo)? onDone;
  const _PhotoStep({
    super.key,
    required this.onDone,
  });

  @override
  State<_PhotoStep> createState() => _PhotoStepState();
}

class _PhotoStepState extends State<_PhotoStep> {
  Photo? _photo;

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    return _Container(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Title(
            icon: Icon(Icons.photo),
            label: 'Add your photo',
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
          Flexible(
            child: OutlinedButton(
              clipBehavior: Clip.antiAlias,
              onPressed: () async {
                final photo = await pickPhotoWithCropper(context);
                if (context.mounted && photo != null) {
                  setState(() => _photo = photo);
                }
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromWidth(124),
                backgroundColor: const Color.fromRGBO(0xEA, 0xF8, 0xFF, 1.0),
              ),
              child: ImageAspect(
                child: switch (photo) {
                  NetworkPhoto(:final url) => Image.network(
                      url,
                      fit: BoxFit.cover,
                    ),
                  MemoryPhoto(:final Uint8List bytes) => Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                    ),
                  _ => const Icon(Icons.photo),
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
          _Button(
            onPressed: photo == null
                ? null
                : widget.onDone == null
                    ? null
                    : () => widget.onDone!(photo),
            child: widget.onDone == null
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _ExitStep extends StatefulWidget {
  final VoidCallback onDone;

  const _ExitStep({
    super.key,
    required this.onDone,
  });

  @override
  State<_ExitStep> createState() => _ExitStepState();
}

class _ExitStepState extends State<_ExitStep> {
  late final Timer _timer;
  bool _show = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _show = false);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _show ? 1.0 : 0.0,
      onEnd: widget.onDone,
      child: const _Container(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 48),
            _Title(
              icon: null,
              label: 'Build the tree by\nadding family anytime',
            ),
            Expanded(
              child: Center(
                  child: Icon(
                Icons.add,
              )),
            ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final Widget? icon;
  final String label;

  const _Title({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          icon!,
          const SizedBox(width: 4),
        ],
        DefaultTextStyle.merge(
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
          child: Text(label),
        ),
      ],
    );
  }
}

class _Container extends StatelessWidget {
  final Widget child;

  const _Container({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 304,
      height: 348,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(
          Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, -7),
            blurRadius: 32,
            color: Color.fromRGBO(0x00, 0x00, 0x00, 0.15),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Button extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const _Button({
    super.key,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: primaryColor,
        minimumSize: const Size.fromHeight(48),
      ),
      child: child,
    );
  }
}
