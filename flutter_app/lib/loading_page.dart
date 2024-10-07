import 'package:flutter/material.dart';
import 'package:heritage/family_tree_page_panels.dart';
import 'package:heritage/help.dart';
import 'package:lottie/lottie.dart';

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color.fromRGBO(0xD8, 0xE8, 0xFC, 1.0),
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset(
                    'assets/images/logo.json',
                    width: 180,
                    height: 180,
                  ),
                  const SizedBox(
                    width: 350,
                    height: 98,
                    child: LogoText(
                      width: 350,
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    height: 68,
                    child: Image.asset(
                      'assets/images/tagline.png',
                      width: 240,
                    ),
                  ),
                ],
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child: AppVersion(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
