import 'package:flutter/material.dart';

import 'api.dart';
import 'diary_screen.dart';
import 'theme.dart';

void main() => runApp(DiaryApp(api: ApiClient()));

class DiaryApp extends StatelessWidget {
  const DiaryApp({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Symptom Diary',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: DiaryScreen(api: api),
    );
  }
}
