import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ErrorPage extends StatelessWidget {
  const ErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            const Text('Something went wrong.'),
            FilledButton(
              onPressed: () => context.goNamed('initial'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
