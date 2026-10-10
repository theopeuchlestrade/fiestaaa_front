import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RouteBackButton extends StatelessWidget {
  const RouteBackButton({super.key, required this.fallback});
  final String fallback;
  @override
  Widget build(BuildContext context) => BackButton(
    onPressed: () {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(fallback);
      }
    },
  );
}
