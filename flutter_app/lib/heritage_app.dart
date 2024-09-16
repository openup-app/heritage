import 'package:flutter/material.dart';
import 'package:heritage/tree_test_page.dart';

class HeritageApp extends StatelessWidget {
  const HeritageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Family Tree',
      home: TreeTestPage(),
    );
  }
}
