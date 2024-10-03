import 'package:flutter/material.dart';
import 'package:heritage/family_tree_page_panels.dart';
import 'package:heritage/help.dart';

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          const Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LogoText(),
                  Text(
                    'Build your family tree\nwith your family!',
                    textAlign: TextAlign.center,
                    style: TextStyle(),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: Image.asset(
              'assets/images/app_loading.webp',
              width: 300,
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
    );
  }
}
