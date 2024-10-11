import 'package:flutter/material.dart';
import 'package:heritage/family_tree_page_panels.dart';
import 'package:heritage/storage.dart';

class LandingPage extends StatefulWidget {
  final Storage storage;
  final LandingPageStatus? status;

  const LandingPage({
    super.key,
    required this.storage,
    required this.status,
  });

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  @override
  void initState() {
    super.initState();
    if (widget.status == LandingPageStatus.decline) {
      widget.storage.clearUid();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(223, 235, 250, 1.0),
      body: Center(
        child: Container(
          width: 287,
          height: 287,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
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
          child: switch (widget.status) {
            null || LandingPageStatus.decline => const _LandingPageContent(),
            LandingPageStatus.invalidLink => const _InvalidLinkContent(),
          },
        ),
      ),
    );
  }
}

class _LandingPageContent extends StatelessWidget {
  const _LandingPageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(height: 24),
        LogoText(width: 230),
        Spacer(),
        _InviteOnlyText(),
        Spacer(),
        SizedBox(height: 70),
      ],
    );
  }
}

class _InvalidLinkContent extends StatelessWidget {
  const _InvalidLinkContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(height: 24),
        LogoText(
          width: 230,
        ),
        SizedBox(height: 40),
        Text(
          'Ask your family\for a login link',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color.fromRGBO(0x00, 0xAE, 0xFF, 1.0),
          ),
        ),
        Spacer(),
        SizedBox(height: 24),
        _InviteOnlyText(),
        SizedBox(height: 24),
      ],
    );
  }
}

class _InviteOnlyText extends StatelessWidget {
  const _InviteOnlyText({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Stitchfam is currently invite only',
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color.fromRGBO(0x9E, 0x9E, 0x9E, 1.0),
      ),
    );
  }
}

enum LandingPageStatus { invalidLink, decline }
