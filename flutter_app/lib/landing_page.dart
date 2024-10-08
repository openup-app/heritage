import 'package:flutter/material.dart';
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
      body: Center(
        child: widget.status == LandingPageStatus.invalidLink
            ? const Text('Invalid link')
            : const Text('This app is invite only!'),
      ),
    );
  }
}

enum LandingPageStatus { invalidLink, decline }
