import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heritage/api.dart';
import 'package:heritage/api_util.dart';
import 'package:heritage/authentication.dart';
import 'package:heritage/family_tree_page.dart';
import 'package:heritage/family_tree_page_panels.dart';
import 'package:heritage/onboarding_flow.dart';
import 'package:heritage/restart_app.dart';
import 'package:url_launcher/link.dart';

final _privacyPolicyUri = Uri.parse('https://stitchfam.com/privacy_policy');
final _tosUri = Uri.parse('https://stitchfam.com/tos');

final _tempNotifier = ValueNotifier(Matrix4.identity());

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: TiledBackground(
          transformNotifier: _tempNotifier,
          tint: null,
          child: Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(
                  color: Color.fromRGBO(0x00, 0x00, 0x00, 0.75),
                ),
              ),
              const Align(
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 16),
                    LogoText(width: 230),
                    TaglineText(),
                  ],
                ),
              ),
              Center(
                child: Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 287,
                        height: 327,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color.fromRGBO(0xEC, 0xEC, 0xEC, 1.0),
                          borderRadius: BorderRadius.all(
                            Radius.circular(25),
                          ),
                          boxShadow: [
                            BoxShadow(
                              offset: Offset(0, 3),
                              blurRadius: 20,
                              color: Color.fromRGBO(0x00, 0x00, 0x00, 0.2),
                            )
                          ],
                        ),
                        child: const _LandingPageContent(),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Stitchfam is invite only.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color.fromRGBO(0xFF, 0xFF, 0xFF, 0.25),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextButtonTheme(
                    data: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        foregroundColor:
                            const Color.fromRGBO(0xFF, 0xFF, 0xFF, 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Link(
                          uri: _privacyPolicyUri,
                          target: LinkTarget.blank,
                          builder: (context, followLink) {
                            return TextButton(
                              onPressed: followLink,
                              child: const Text('Privacy Policy'),
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        Link(
                          uri: _tosUri,
                          target: LinkTarget.blank,
                          builder: (context, followLink) {
                            return TextButton(
                              onPressed: followLink,
                              child: const Text('Terms of Service'),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingPageContent extends ConsumerStatefulWidget {
  const _LandingPageContent({super.key});

  @override
  ConsumerState<_LandingPageContent> createState() =>
      _LandingPageContentState();
}

class _LandingPageContentState extends ConsumerState<_LandingPageContent> {
  String _phoneNumber = '';
  bool _awaitingSmsVerification = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_awaitingSmsVerification)
          Expanded(
            child: SignInLogic(
              title: 'Sign in to view\nyour family tree',
              initialPhoneNumber: _phoneNumber,
              onGoogleSignIn: (idToken) async {
                final api = ref.read(apiProvider);
                final result = await api.authenticateOauth(
                  claimUid: null,
                  idToken: idToken,
                );
                if (!mounted) {
                  return;
                }

                result.fold(
                  (l) {
                    showErrorMessage(
                      context: context,
                      message: authErrorToMessage(l, isGoogleOauth: true),
                    );
                  },
                  (r) async {
                    final success = await signInWithCustomToken(r);
                    if (!context.mounted) {
                      return;
                    }
                    if (!success) {
                      showErrorMessage(
                        context: context,
                        message: 'Failed to sign in',
                      );
                    } else {
                      RestartApp.of(context).restart();
                    }
                  },
                );
              },
              onSendSms: (phoneNumber) async {
                setState(() => _phoneNumber = phoneNumber);
                final api = ref.read(apiProvider);
                final result = await api.sendSms(phoneNumber: phoneNumber);
                if (!mounted) {
                  return;
                }
                result.fold(
                  (l) {
                    showErrorMessage(
                      context: context,
                      message: smsErrorToMessage(l),
                    );
                  },
                  (r) => setState(() => _awaitingSmsVerification = true),
                );
              },
            ),
          )
        else
          Expanded(
            child: SignUpPhoneVerificationLogic(
              onResendCode: () async {
                final api = ref.read(apiProvider);
                final result = await api.sendSms(phoneNumber: _phoneNumber);
                if (!mounted) {
                  return;
                }
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
                  claimUid: null,
                  phoneNumber: _phoneNumber,
                  smsCode: smsCode,
                );
                if (!mounted) {
                  return;
                }
                result.fold(
                  (l) {
                    showErrorMessage(
                      context: context,
                      message: authErrorToMessage(l, isGoogleOauth: false),
                    );
                  },
                  (r) async {
                    final success = await signInWithCustomToken(r);
                    if (!context.mounted) {
                      return;
                    }

                    if (!success) {
                      showErrorMessage(
                        context: context,
                        message: 'Failed to sign in',
                      );
                    } else {
                      RestartApp.of(context).restart();
                    }
                  },
                );
              },
              onBack: () => setState(() => _awaitingSmsVerification = false),
            ),
          ),
      ],
    );
  }
}
