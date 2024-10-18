import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:heritage/api.dart';
import 'package:heritage/api_util.dart';
import 'package:heritage/auth/sign_in_button.dart';
import 'package:heritage/authentication.dart';
import 'package:heritage/family_tree_page.dart';
import 'package:heritage/graph.dart';
import 'package:heritage/heritage_app.dart';
import 'package:heritage/profile_display.dart';
import 'package:heritage/util.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:lottie/lottie.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  final LinkedNode<Person> person;
  final List<Person> activePeople;
  final Future<void> Function(Profile profile) onSave;
  final VoidCallback onDone;

  const OnboardingFlow({
    super.key,
    required this.person,
    required this.activePeople,
    required this.onSave,
    required this.onDone,
  });

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  late final Timer _timer;
  int _step = 0;
  String _phoneNumber = '';
  late String _firstName = widget.person.data.profile.firstName;
  late String _lastName = widget.person.data.profile.lastName;
  late Gender? _gender = widget.person.data.profile.gender;
  late Photo _photo = widget.person.data.profile.photo;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), () {
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
    return Stack(
      alignment: Alignment.center,
      children: [
        ModalBarrier(
          dismissible: false,
          color: _step == 0
              ? const Color.fromRGBO(0x00, 0x00, 0x00, 0.1)
              : const Color.fromRGBO(0x00, 0x00, 0x00, 0.5),
        ),
        Center(
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Material(
              type: MaterialType.transparency,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: [
                  Center(
                    child: Lottie.asset(
                      'assets/images/logo.json',
                      width: 60,
                    ),
                  ),
                  _ActivePeopleStep(
                    activePeople: widget.activePeople,
                    onDone: () => setState(() => _step++),
                  ),
                  _Container(
                    child: SignInLogic(
                      title: 'Sign up to join\nyour family',
                      initialPhoneNumber: _phoneNumber,
                      onGoogleSignIn: (idToken) async {
                        final api = ref.read(apiProvider);
                        final result = await api.authenticateOauth(
                          claimUid: widget.person.id,
                          idToken: idToken,
                        );
                        if (!mounted) {
                          return;
                        }

                        result.fold(
                          (l) {
                            showErrorMessage(
                              context: context,
                              message:
                                  authErrorToMessage(l, isGoogleOauth: true),
                            );
                          },
                          (r) async {
                            final userRecord = await FirebaseAuth.instance
                                .signInWithCustomToken(r);
                            if (!context.mounted) {
                              return;
                            }
                            if (userRecord.user == null) {
                              showErrorMessage(
                                context: context,
                                message: 'Failed to link account',
                              );
                            } else {
                              setState(() => _step += 2);
                            }
                          },
                        );
                      },
                      onSendSms: (phoneNumber) async {
                        setState(() => _phoneNumber = phoneNumber);
                        final api = ref.read(apiProvider);
                        final result =
                            await api.sendSms(phoneNumber: phoneNumber);
                        result.fold(
                          (l) {
                            showErrorMessage(
                              context: context,
                              message: smsErrorToMessage(l),
                            );
                          },
                          (r) {
                            if (mounted) {
                              setState(() => _step++);
                            }
                          },
                        );
                      },
                    ),
                  ),
                  _Container(
                    child: SignUpPhoneVerificationLogic(
                      onResendCode: () async {
                        final api = ref.read(apiProvider);
                        final result =
                            await api.sendSms(phoneNumber: _phoneNumber);
                        result.fold(
                          (l) {
                            showErrorMessage(
                              context: context,
                              message: smsErrorToMessage(l),
                            );
                          },
                          (r) {},
                        );
                      },
                      onSubmit: (smsCode) async {
                        if (_phoneNumber.isEmpty) {
                          return;
                        }
                        final api = ref.read(apiProvider);
                        final result = await api.authenticatePhone(
                          claimUid: widget.person.id,
                          phoneNumber: _phoneNumber,
                          smsCode: smsCode,
                        );
                        result.fold(
                          (l) {
                            showErrorMessage(
                              context: context,
                              message:
                                  authErrorToMessage(l, isGoogleOauth: false),
                            );
                          },
                          (r) => setState(() => _step++),
                        );
                      },
                      onBack: () => setState(() => _step--),
                    ),
                  ),
                  _NameStep(
                    title: 'Your name',
                    initialFirstName: _firstName,
                    initialLastName: _lastName,
                    onDone: (firstName, lastName) {
                      setState(() {
                        _firstName = firstName;
                        _lastName = lastName;
                        _step++;
                      });
                    },
                  ),
                  _GenderStep(
                    title: 'Your gender',
                    initialGender: _gender,
                    onDone: (gender) {
                      setState(() {
                        _gender = gender;
                        _step++;
                      });
                    },
                  ),
                  _PhotoStep(
                    title: 'Add Your Photo',
                    buttonLabel: 'Next',
                    initialPhoto: _photo,
                    onPhoto: (photo) => setState(() => _photo = photo),
                    onDone: _uploading ? null : _upload,
                  ),
                  _EndAnimationStep(
                    newPerson:
                        widget.person.data.copyWith.profile(photo: _photo),
                    activePeople: widget.activePeople,
                    onDone: widget.onDone,
                  ),
                ][_step],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _upload() async {
    final profile = widget.person.data.profile.copyWith(
      firstName: _firstName,
      lastName: _lastName,
      gender: _gender,
      photo: _photo,
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

class CreatePersonFlow extends StatefulWidget {
  final Relationship relationship;
  final Future<Id?> Function(
    String firstName,
    String lastName,
    Photo? photo,
  ) onSaveProfile;
  final Future<void> Function(Id id, OwnershipUnableReason reason)
      onSetOwnershipUnable;
  final Future<void> Function(Id id, String name) onShareInvite;
  final void Function(Id newId) onDone;

  const CreatePersonFlow({
    super.key,
    required this.relationship,
    required this.onSaveProfile,
    required this.onSetOwnershipUnable,
    required this.onShareInvite,
    required this.onDone,
  });

  @override
  State<CreatePersonFlow> createState() => _CreatePersonFlowState();
}

class _CreatePersonFlowState extends State<CreatePersonFlow> {
  int _step = 0;
  String _firstName = '';
  String _lastName = '';
  Photo? _photo;
  bool _uploading = false;
  Id? _newId;

  @override
  Widget build(BuildContext context) {
    final newId = _newId;
    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Material(
              type: MaterialType.transparency,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: [
                  _NameStep(
                    title: 'Edit Name',
                    initialFirstName: null,
                    initialLastName: null,
                    onDone: (firstName, lastName) {
                      setState(() {
                        _firstName = firstName;
                        _lastName = lastName;
                        _step++;
                      });
                    },
                  ),
                  _PhotoStep(
                    title: 'Edit Photo',
                    optional: true,
                    buttonLabel: 'Next',
                    initialPhoto: null,
                    onPhoto: (photo) => setState(() => _photo = photo),
                    onDone: _uploading ? null : _upload,
                  ),
                  _ShareStep(
                    name: _firstName,
                    onShareInvite: newId == null
                        ? null
                        : () async {
                            await widget.onShareInvite(newId, _firstName);
                            if (mounted) {
                              widget.onDone(newId);
                            }
                          },
                    onMarkAsUnownable: () => setState(() => _step++),
                    onDone: newId == null ? null : () => widget.onDone(newId),
                  ),
                  _UnableToOwnStep(
                    name: _firstName,
                    onBack: () => setState(() => _step--),
                    onDone: newId == null || _uploading
                        ? null
                        : (reason) async {
                            setState(() => _uploading = true);
                            await widget.onSetOwnershipUnable(newId, reason);
                            if (mounted) {
                              setState(() => _uploading = false);
                              widget.onDone(newId);
                            }
                          },
                  ),
                ][_step],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _upload() async {
    setState(() => _uploading = true);
    final id = await widget.onSaveProfile(_firstName, _lastName, _photo);
    if (mounted) {
      setState(() {
        _newId = id;
        _uploading = false;
        _step++;
      });
    }
  }
}

class EditPersonFlow extends ConsumerStatefulWidget {
  final Person person;
  final Future<void> Function(Profile profile) onSave;
  final Future<void> Function(String name) onShareInvite;
  final Future<void> Function(OwnershipUnableReason reason)
      onSetOwnershipUnable;
  final void Function() onDone;

  const EditPersonFlow({
    super.key,
    required this.person,
    required this.onSave,
    required this.onShareInvite,
    required this.onSetOwnershipUnable,
    required this.onDone,
  });

  @override
  ConsumerState<EditPersonFlow> createState() => _EditPersonFlowState();
}

class _EditPersonFlowState extends ConsumerState<EditPersonFlow> {
  int _step = 0;
  late String _firstName = widget.person.profile.firstName;
  late String _lastName = widget.person.profile.lastName;
  late Photo? _photo = widget.person.profile.photo;
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Material(
              type: MaterialType.transparency,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: [
                  _NameStep(
                    title: 'Edit Name',
                    initialFirstName: _firstName,
                    initialLastName: _lastName,
                    onDone: (firstName, lastName) {
                      setState(() {
                        _firstName = firstName;
                        _lastName = lastName;
                        _step++;
                      });
                    },
                  ),
                  _PhotoStep(
                    title: 'Edit Photo',
                    optional: true,
                    buttonLabel: 'Done',
                    initialPhoto: _photo,
                    onPhoto: (photo) => setState(() => _photo = photo),
                    onDone: _uploading ? null : _upload,
                  ),
                  _ShareStep(
                    name: _firstName,
                    onShareInvite: () async {
                      await widget.onShareInvite(_firstName);
                      if (mounted) {
                        widget.onDone();
                      }
                    },
                    onMarkAsUnownable: () => setState(() => _step++),
                    onDone: widget.onDone,
                  ),
                  _UnableToOwnStep(
                    name: _firstName,
                    onBack: () => setState(() => _step--),
                    onDone: _uploading
                        ? null
                        : (reason) async {
                            setState(() => _uploading = true);
                            await widget.onSetOwnershipUnable(reason);
                            if (mounted) {
                              setState(() => _uploading = false);
                              widget.onDone();
                            }
                          },
                  ),
                ][_step],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _upload() async {
    final photo = _photo;
    if (photo == null) {
      return;
    }
    final profile = widget.person.profile.copyWith(
      firstName: _firstName,
      lastName: _lastName,
      photo: photo,
    );
    setState(() => _uploading = true);
    await widget.onSave(profile);
    if (!mounted) {
      return;
    }
    if (widget.person.isUnownable) {
      widget.onDone();
    } else {
      setState(() {
        _uploading = false;
        _step++;
      });
    }
  }
}

class _ActivePeopleStep extends StatefulWidget {
  final List<Person> activePeople;
  final VoidCallback onDone;

  const _ActivePeopleStep({
    super.key,
    required this.activePeople,
    required this.onDone,
  });

  @override
  State<_ActivePeopleStep> createState() => _ActivePeopleStepState();
}

class _ActivePeopleStepState extends State<_ActivePeopleStep> {
  late final List<bool> _visibility;
  late final Timer _timer;
  int _count = 0;
  bool _controlsVisible = false;

  static const _fadeDuration = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    _visibility = List.generate(widget.activePeople.length, (_) => false);
    _timer = Timer.periodic(
      const Duration(milliseconds: 600),
      (_) {
        if (_count < _visibility.length) {
          setState(() => _visibility[_count] = true);
        } else if (_count == _visibility.length) {
          _controlsVisible = true;
        } else {
          _timer.cancel();
        }
        setState(() => _count++);
      },
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedOpacity(
            duration: _fadeDuration,
            opacity: _controlsVisible ? 1.0 : 0.0,
            child: const Text(
              'Your family has been waiting for you',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color.fromRGBO(0x3B, 0x3B, 0x3B, 1.0),
              ),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (index, person) in widget.activePeople.indexed)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      clipBehavior: Clip.antiAlias,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                      child: PhotoDisplay(
                        photo: person.profile.photo,
                      ),
                    ),
                    Positioned(
                      right: -6,
                      top: -6,
                      child: AnimatedOpacity(
                        duration: _fadeDuration,
                        opacity: _visibility[index] ? 1.0 : 0.0,
                        child: const VerifiedBadge(size: 36),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const Spacer(),
          IgnorePointer(
            ignoring: !_controlsVisible,
            child: AnimatedOpacity(
              duration: _fadeDuration,
              opacity: _controlsVisible ? 1.0 : 0.0,
              child: _Button(
                onPressed: widget.onDone,
                child: const Text('Join and build'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EndAnimationStep extends StatelessWidget {
  final Person newPerson;
  final List<Person> activePeople;
  final VoidCallback onDone;

  const _EndAnimationStep({
    super.key,
    required this.newPerson,
    required this.activePeople,
    required this.onDone,
  });

  static const _fadeDuration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final halfCount = activePeople.length ~/ 2;
    final leftPeople = activePeople.take(halfCount);
    final rightPeople = activePeople.skip(halfCount);
    return _Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: const Text(
              'Welcome Fam!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
            ).animate().fadeIn(
                  delay: const Duration(seconds: 3),
                  duration: _fadeDuration,
                ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 100,
            child: OverflowBox(
              maxWidth: 3400,
              maxHeight: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final person in leftPeople)
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          clipBehavior: Clip.antiAlias,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: PhotoDisplay(
                            photo: person.profile.photo,
                          ),
                        ),
                        const Positioned(
                          right: -6,
                          top: -6,
                          child: VerifiedBadge(size: 36),
                        ),
                      ],
                    ),
                  SizedBox(
                    width: 100,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          clipBehavior: Clip.antiAlias,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: PhotoDisplay(
                            photo: newPerson.profile.photo,
                          ),
                        ),
                        const Positioned(
                          right: -4,
                          top: -4,
                          child: VerifiedBadge(size: 48),
                        ).animate().fadeIn(
                              delay: const Duration(seconds: 2),
                              duration: _fadeDuration,
                            ),
                      ],
                    ),
                  ).animate().fadeIn(
                        delay: const Duration(seconds: 1),
                        duration: _fadeDuration,
                      ),
                  for (final person in rightPeople)
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          clipBehavior: Clip.antiAlias,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: PhotoDisplay(
                            photo: person.profile.photo,
                          ),
                        ),
                        const Positioned(
                          right: -6,
                          top: -6,
                          child: VerifiedBadge(size: 36),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const Spacer(),
          _Button(
            onPressed: onDone,
            child: const Text('Join and build'),
          ).animate().fadeIn(
                delay: const Duration(seconds: 3),
                duration: _fadeDuration,
              ),
        ],
      ),
    );
  }
}

class SignInLogic extends StatefulWidget {
  final String title;
  final String initialPhoneNumber;
  final Future<void> Function(String idToken) onGoogleSignIn;
  final Future<void> Function(String phoneNumber)? onSendSms;

  const SignInLogic({
    super.key,
    required this.title,
    required this.initialPhoneNumber,
    required this.onGoogleSignIn,
    required this.onSendSms,
  });

  @override
  State<SignInLogic> createState() => _SignInLogicState();
}

class _SignInLogicState extends State<SignInLogic> {
  bool _sending = false;
  late final _phoneNumberNotifier =
      ValueNotifier<String>(widget.initialPhoneNumber);
  late final StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    _subscription =
        googleSignIn.onCurrentUserChanged.listen(_onCurrentUserChanged);
  }

  @override
  void dispose() {
    _subscription.cancel();
    _phoneNumberNotifier.dispose();
    super.dispose();
  }

  void _onCurrentUserChanged(GoogleSignInAccount? account) async {
    final auth = await account?.authentication;
    final idToken = auth?.idToken;
    if (idToken == null) {
      return;
    }

    widget.onGoogleSignIn(idToken);
  }

  @override
  Widget build(BuildContext context) {
    final onSendSms = widget.onSendSms;
    return Column(
      children: [
        const SizedBox(height: 0),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color.fromRGBO(0x3B, 0x3B, 0x3B, 1.0),
            ),
          ),
        ),
        const Spacer(),
        buildSignInButton(),
        const Row(
          children: [
            Expanded(
              child: Divider(),
            ),
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('or'),
            ),
            Expanded(
              child: Divider(),
            ),
          ],
        ),
        IntlPhoneField(
          initialValue: widget.initialPhoneNumber,
          initialCountryCode: 'US',
          keyboardType: TextInputType.number,
          disableLengthCheck: true,
          decoration: const InputDecoration(
            hintText: 'Phone number',
          ),
          onChanged: (value) =>
              _phoneNumberNotifier.value = value.completeNumber,
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder(
          valueListenable: _phoneNumberNotifier,
          builder: (context, value, child) {
            return _Button(
              onPressed: _sending || value.isEmpty || onSendSms == null
                  ? null
                  : () async {
                      setState(() => _sending = true);
                      await onSendSms(value);
                      setState(() => _sending = false);
                    },
              child: _sending ? const _LoadingIndicator() : const Text('Next'),
            );
          },
        ),
      ],
    );
  }
}

class SignUpPhoneVerificationLogic extends StatefulWidget {
  final Future<void> Function(String smsCode)? onSubmit;
  final VoidCallback? onResendCode;
  final VoidCallback? onBack;

  const SignUpPhoneVerificationLogic({
    super.key,
    required this.onResendCode,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  State<SignUpPhoneVerificationLogic> createState() =>
      _SignUpPhoneVerificationLogicState();
}

class _SignUpPhoneVerificationLogicState
    extends State<SignUpPhoneVerificationLogic> {
  final _smsController = TextEditingController();
  bool _submitting = false;
  Timer? _resendTimer;

  @override
  void dispose() {
    _smsController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Enter your\nverification code',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color.fromRGBO(0x3B, 0x3B, 0x3B, 1.0),
                ),
              ),
            ),
            const Spacer(),
            TextFormField(
              controller: _smsController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: 'Verification code',
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: _submitting ||
                        _resendTimer != null ||
                        widget.onResendCode == null
                    ? null
                    : () {
                        setState(() {
                          _resendTimer = Timer(
                            const Duration(seconds: 10),
                            () => setState(() => _resendTimer = null),
                          );
                        });
                        _smsController.clear();
                        widget.onResendCode?.call();
                      },
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: const Text('Resend Code'),
              ),
            ),
            const Spacer(),
            const SizedBox(height: 16),
            ValueListenableBuilder(
              valueListenable: _smsController,
              builder: (context, value, child) {
                return _Button(
                  onPressed: _submitting ||
                          value.text.length < 6 ||
                          widget.onSubmit == null
                      ? null
                      : () async {
                          setState(() => _submitting = true);
                          await widget.onSubmit?.call(value.text);
                          if (mounted) {
                            setState(() => _submitting = false);
                          }
                        },
                  child: _submitting
                      ? const _LoadingIndicator()
                      : const Text('Next'),
                );
              },
            ),
          ],
        ),
        Positioned(
          left: -16,
          top: -16,
          child: IconButton(
            onPressed: _submitting ? null : widget.onBack,
            style: IconButton.styleFrom(padding: EdgeInsets.zero),
            icon: const Icon(
              CupertinoIcons.chevron_back,
              color: Color.fromRGBO(0xA4, 0xA4, 0xA4, 1.0),
            ),
          ),
        ),
      ],
    );
  }
}

class _NameStep extends StatefulWidget {
  final String title;
  final String? initialFirstName;
  final String? initialLastName;
  final void Function(String firstName, String lastName) onDone;

  const _NameStep({
    super.key,
    required this.title,
    required this.initialFirstName,
    required this.initialLastName,
    required this.onDone,
  });

  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  late String _firstName = widget.initialFirstName ?? '';
  late String _lastName = widget.initialLastName ?? '';

  @override
  Widget build(BuildContext context) {
    return _Container(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Title(
            icon: SvgPicture.asset(
              'assets/images/id_card.svg',
            ),
            label: widget.title,
          ),
          const Spacer(),
          MinimalProfileEditor(
            initialFirstName: widget.initialFirstName,
            initialLastName: widget.initialLastName,
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
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

class _GenderStep extends StatefulWidget {
  final String title;
  final Gender? initialGender;
  final void Function(Gender? gender) onDone;

  const _GenderStep({
    super.key,
    required this.title,
    required this.initialGender,
    required this.onDone,
  });

  @override
  State<_GenderStep> createState() => _GenderStepState();
}

class _GenderStepState extends State<_GenderStep> {
  late Gender? _gender = widget.initialGender;

  @override
  Widget build(BuildContext context) {
    final gender = _gender;
    return _Container(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Title(
            icon: const Icon(Icons.face_sharp),
            label: widget.title,
          ),
          const Spacer(),
          for (final g in [...Gender.values, null]) ...[
            RadioListTile(
              title: Text(_genderToLabel(g)),
              value: g,
              groupValue: gender,
              onChanged: (value) {
                if (value == g) {
                  setState(() => _gender = g);
                }
              },
            ),
          ],
          const Spacer(),
          _Button(
            onPressed: () => widget.onDone(gender),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  String _genderToLabel(Gender? gender) {
    return switch (gender) {
      Gender.male => 'Male',
      Gender.female => 'Female',
      null => 'Unspecified',
    };
  }
}

class _PhotoStep extends StatefulWidget {
  final String title;
  final bool optional;
  final String buttonLabel;
  final Photo? initialPhoto;
  final void Function(Photo photo) onPhoto;
  final VoidCallback? onDone;

  const _PhotoStep({
    super.key,
    required this.title,
    this.optional = false,
    required this.buttonLabel,
    required this.initialPhoto,
    required this.onPhoto,
    required this.onDone,
  });

  @override
  State<_PhotoStep> createState() => _PhotoStepState();
}

class _PhotoStepState extends State<_PhotoStep> {
  late Photo? _photo = widget.initialPhoto;

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    return _Container(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Title(
            icon: const Icon(Icons.photo),
            label: widget.title,
            optional: widget.optional,
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: OutlinedButton(
                clipBehavior: Clip.antiAlias,
                onPressed: () async {
                  final photo = await pickPhotoWithCropper(context);
                  if (context.mounted && photo != null) {
                    setState(() => _photo = photo);
                    widget.onPhoto(photo);
                  }
                },
                style: OutlinedButton.styleFrom(
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
                    _ => Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SvgPicture.asset(
                          'assets/images/add_photo_2.svg',
                        ),
                      ),
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
          _Button(
            onPressed:
                _photo == null && !widget.optional ? null : widget.onDone,
            child: widget.onDone == null
                ? const _LoadingIndicator()
                : Text(widget.buttonLabel),
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
    _timer = Timer(const Duration(seconds: 5), () {
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
      child: _Container(
        backgroundColor: primaryColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 48),
            const _Title(
              color: Colors.white,
              icon: null,
              label: 'The tree is built together!\nAdd anyone, anytime.',
            ),
            Expanded(
              child: Center(
                child: Lottie.asset(
                  'assets/images/tree.json',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareStep extends StatelessWidget {
  final String name;
  final VoidCallback? onShareInvite;
  final VoidCallback? onMarkAsUnownable;
  final VoidCallback? onDone;

  const _ShareStep({
    super.key,
    required this.name,
    required this.onShareInvite,
    required this.onMarkAsUnownable,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return _Container(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Give $name\naccess',
              maxLines: 2,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color.fromRGBO(0x3B, 0x3B, 0x3B, 1.0),
              ),
            ),
          ),
          const SizedBox(height: 50),
          FilledButton.icon(
            onPressed: onShareInvite,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(84),
              foregroundColor: Colors.white,
              backgroundColor: primaryColor,
            ),
            icon: const Icon(Icons.ios_share),
            label: Text('Invite $name'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onMarkAsUnownable,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              foregroundColor: Colors.grey,
            ),
            child: const Text('Tap here for child, disabled, deceased'),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onDone,
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnableToOwnStep extends StatefulWidget {
  final String name;
  final VoidCallback onBack;
  final void Function(OwnershipUnableReason reason)? onDone;

  const _UnableToOwnStep({
    super.key,
    required this.name,
    required this.onBack,
    required this.onDone,
  });

  @override
  State<_UnableToOwnStep> createState() => _UnableToOwnStepState();
}

class _UnableToOwnStepState extends State<_UnableToOwnStep> {
  OwnershipUnableReason? _reason;

  @override
  Widget build(BuildContext context) {
    final reason = _reason;
    return _Container(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 32.0),
                child: Text(
                  '${widget.name} can\'t join',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color.fromRGBO(0x3B, 0x3B, 0x3B, 1.0),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('${widget.name} is:'),
              const SizedBox(height: 16),
              for (final r in OwnershipUnableReason.values) ...[
                RadioListTile(
                  title: Text(_reasonToSentence(r)),
                  value: r,
                  groupValue: reason,
                  onChanged: (value) {
                    if (value == r) {
                      setState(() => _reason = r);
                    }
                  },
                ),
              ],
              const Spacer(),
              _Button(
                onPressed: reason == null || widget.onDone == null
                    ? null
                    : () => widget.onDone?.call(reason),
                child: widget.onDone == null
                    ? const _LoadingIndicator()
                    : const Text('Done'),
              ),
            ],
          ),
          Positioned(
            left: -16,
            top: -3,
            child: IconButton(
              onPressed: widget.onBack,
              style: IconButton.styleFrom(padding: EdgeInsets.zero),
              icon: const Icon(
                CupertinoIcons.chevron_back,
                color: Color.fromRGBO(0xA4, 0xA4, 0xA4, 1.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _reasonToSentence(OwnershipUnableReason reason) {
    return switch (reason) {
      OwnershipUnableReason.child => 'A child',
      OwnershipUnableReason.deceased => 'Deceased',
      OwnershipUnableReason.disabled => 'Disabled',
    };
  }
}

class _Title extends StatelessWidget {
  final Color? color;
  final Widget? icon;
  final String label;
  final bool optional;

  const _Title({
    super.key,
    this.color = const Color.fromRGBO(0x3B, 0x3B, 0x3B, 1.0),
    required this.icon,
    required this.label,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              icon!,
              const SizedBox(width: 4),
            ],
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color.fromRGBO(0x3B, 0x3B, 0x3B, 1.0),
              ),
            ),
          ],
        ),
        if (optional)
          const Text(
            'Optional',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Color.fromRGBO(0x67, 0x67, 0x67, 1.0),
            ),
          ),
      ],
    );
  }
}

class _Container extends StatelessWidget {
  final Color backgroundColor;
  final Widget child;

  const _Container({
    super.key,
    this.backgroundColor = const Color.fromRGBO(0xEC, 0xEC, 0xEC, 1.0),
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 304,
      height: 348,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.all(
          Radius.circular(24),
        ),
        boxShadow: const [
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

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      ),
    );
  }
}
