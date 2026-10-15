import 'package:flutter/material.dart';

import 'theme.dart';

/// Centres a screen's content and caps its width (see DESIGN.md, Layout).
class ContentColumn extends StatelessWidget {
  const ContentColumn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Space.maxContentWidth),
        child: child,
      ),
    );
  }
}

/// A small pill for a symptom name.
class SymptomTag extends StatelessWidget {
  const SymptomTag(this.symptom, {super.key});

  final String symptom;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: const ShapeDecoration(
        color: AppColors.paper,
        shape: StadiumBorder(side: BorderSide(color: AppColors.line)),
      ),
      child: Text(sentenceCase(symptom), style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

String sentenceCase(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
