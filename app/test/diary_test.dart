import 'dart:convert';

import 'package:diary_app/api.dart';
import 'package:diary_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// An in-memory stand-in for the diary API.
MockClient fakeApi(List<Map<String, dynamic>> entries, {List<http.Request>? log}) {
  return MockClient((request) async {
    log?.add(request);
    if (request.method == 'GET' && request.url.path.endsWith('/entries')) {
      return http.Response(jsonEncode(entries), 200);
    }
    if (request.method == 'POST' && request.url.path.endsWith('/entries')) {
      final entry = {...jsonDecode(request.body) as Map<String, dynamic>, 'id': entries.length + 1};
      entries.insert(0, entry);
      return http.Response(jsonEncode(entry), 201);
    }
    return http.Response('Not found', 404);
  });
}

void main() {
  testWidgets('shows the diary entries', (tester) async {
    final api = ApiClient(
      client: fakeApi([
        {
          'id': 1,
          'recorded_at': '2026-10-05T08:30:00Z',
          'mood': 4,
          'symptoms': ['headache'],
          'note': 'Slept badly',
        },
      ]),
    );

    await tester.pumpWidget(DiaryApp(api: api));
    await tester.pumpAndSettle();

    expect(find.text('Good'), findsOneWidget);
    expect(find.text('Headache'), findsOneWidget);
    expect(find.text('Slept badly'), findsOneWidget);
  });

  testWidgets('adds an entry and shows it in the list', (tester) async {
    final requests = <http.Request>[];
    final api = ApiClient(client: fakeApi([], log: requests));

    await tester.pumpWidget(DiaryApp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('Your diary is empty'), findsOneWidget);

    await tester.tap(find.text('New entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mood-5')));
    await tester.tap(find.text('Headache'));
    await tester.enterText(find.widgetWithText(TextField, 'Other symptoms'), 'Back pain');
    await tester.enterText(
      find.widgetWithText(TextField, 'What happened, what helped?'),
      'Feeling great',
    );
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();

    final sent = jsonDecode(requests.firstWhere((r) => r.method == 'POST').body);
    expect(sent['mood'], 5);
    expect(sent['symptoms'], ['headache', 'back pain']);
    expect(find.text('Very good'), findsOneWidget);
    expect(find.text('Feeling great'), findsOneWidget);
  });
}
