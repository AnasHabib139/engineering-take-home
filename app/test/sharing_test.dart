import 'dart:convert';

import 'package:diary_app/api.dart';
import 'package:diary_app/format.dart';
import 'package:diary_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _doctors = [
  {'id': 1, 'name': 'Dr. Lena Hofmann', 'practice': 'Praxis Hofmann, München'},
  {'id': 2, 'name': 'Dr. Felix Braun', 'practice': 'Hausarztpraxis Schwabing'},
];

http.Response _json(Object body, int status) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

/// An in-memory stand-in for the sharing endpoints.
MockClient fakeApi({
  List<Map<String, dynamic>>? shares,
  List<Map<String, dynamic>>? accessLog,
  List<http.Request>? log,
}) {
  final stored = shares ?? [];
  return MockClient((request) async {
    log?.add(request);
    final path = request.url.path;
    if (request.method == 'GET' && path.endsWith('/entries')) return http.Response('[]', 200);
    if (request.method == 'GET' && path.endsWith('/clinicians')) {
      return _json(_doctors, 200);
    }
    if (request.method == 'GET' && path.endsWith('/shares')) {
      return _json(stored, 200);
    }
    if (request.method == 'GET' && path.endsWith('/access-log')) {
      return _json(accessLog ?? [], 200);
    }
    if (request.method == 'POST' && path.endsWith('/shares')) {
      final share = {
        ...jsonDecode(request.body) as Map<String, dynamic>,
        'id': stored.length + 1,
        'created_at': '2026-10-08T09:12:00Z',
        'revoked_at': null,
      };
      stored.insert(0, share);
      return _json(share, 201);
    }
    if (request.method == 'POST' && path.endsWith('/revoke')) {
      final share = stored.firstWhere((s) => path.contains('/shares/${s['id']}/'));
      share['revoked_at'] = '2026-10-09T08:00:00Z';
      return _json(share, 200);
    }
    if (request.method == 'POST' && path.endsWith('/telemetry')) return http.Response('', 204);
    return http.Response('Not found', 404);
  });
}

Future<void> openSharing(WidgetTester tester, ApiClient api) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(DiaryApp(api: api));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Share with your doctor'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows who can see the diary and who looked, in plain words', (tester) async {
    final api = ApiClient(
      client: fakeApi(
        shares: [
          {
            'id': 2,
            'clinician_id': 2,
            'from_date': '2026-09-01',
            'to_date': '2026-09-07',
            'include_notes': false,
            'revoked_at': '2026-09-10T08:00:00Z',
          },
          {
            'id': 1,
            'clinician_id': 1,
            'from_date': '2026-10-01',
            'to_date': '2026-10-07',
            'include_notes': true,
            'revoked_at': null,
          },
        ],
        accessLog: [
          {
            'clinician_id': 1,
            'clinician_name': 'Dr. Lena Hofmann',
            'accessed_at': '2026-10-08T10:03:00Z',
            'entry_ids': [3, 5],
          },
        ],
      ),
    );

    await openSharing(tester, api);

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Mood, symptoms and notes'), findsOneWidget);
    expect(find.text('Mood and symptoms only'), findsOneWidget);
    expect(find.text('Revoke access'), findsOneWidget); // only the active share
    expect(find.text('Looked at 2 entries'), findsOneWidget);
  });

  testWidgets('invites the patient to share when nothing is shared yet', (tester) async {
    await openSharing(tester, ApiClient(client: fakeApi()));

    expect(find.text("You haven't shared your diary"), findsOneWidget);
    expect(find.text('No one has looked yet'), findsOneWidget);
  });

  testWidgets('shares the last 7 days with a doctor, notes off by default', (tester) async {
    final requests = <http.Request>[];
    await openSharing(tester, ApiClient(client: fakeApi(log: requests)));

    await tester.tap(find.text('Share with a doctor'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a doctor above'), findsOneWidget);

    await tester.tap(find.text('Dr. Lena Hofmann'));
    await tester.pumpAndSettle();
    expect(find.text('Dr. Lena Hofmann, Praxis Hofmann, München'), findsOneWidget);
    expect(find.text('Mood and symptoms only'), findsOneWidget);
    await tester.tap(find.text('Share my diary'));
    await tester.pumpAndSettle();

    final today = dayOf(DateTime.now());
    final sent = jsonDecode(
      requests.lastWhere((r) => r.method == 'POST' && r.url.path.endsWith('/shares')).body,
    );
    expect(sent, {
      'clinician_id': 1,
      'from_date': formatApiDate(DateTime(today.year, today.month, today.day - 6)),
      'to_date': formatApiDate(today),
      'include_notes': false,
    });
    expect(
      requests.where((r) => r.url.path.endsWith('/telemetry')).map((r) => r.body),
      contains(contains('share_created')),
    );
    expect(find.text('Revoke access'), findsOneWidget);
  });

  testWidgets('includes notes only when the patient turns them on', (tester) async {
    final requests = <http.Request>[];
    await openSharing(tester, ApiClient(client: fakeApi(log: requests)));

    await tester.tap(find.text('Share with a doctor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dr. Felix Braun'));
    await tester.tap(find.text('Include my notes'));
    await tester.pumpAndSettle();
    expect(find.text('Mood, symptoms and notes'), findsOneWidget);
    await tester.tap(find.text('Last 30 days'));
    await tester.tap(find.text('Share my diary'));
    await tester.pumpAndSettle();

    final sent = jsonDecode(
      requests.lastWhere((r) => r.method == 'POST' && r.url.path.endsWith('/shares')).body,
    );
    expect(sent['clinician_id'], 2);
    expect(sent['include_notes'], true);
  });

  testWidgets("can't share until a doctor is chosen", (tester) async {
    await openSharing(tester, ApiClient(client: fakeApi()));

    await tester.tap(find.text('Share with a doctor'));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('revokes access', (tester) async {
    final requests = <http.Request>[];
    final api = ApiClient(
      client: fakeApi(
        log: requests,
        shares: [
          {
            'id': 1,
            'clinician_id': 1,
            'from_date': '2026-10-01',
            'to_date': '2026-10-07',
            'include_notes': false,
            'revoked_at': null,
          },
        ],
      ),
    );
    await openSharing(tester, api);

    await tester.tap(find.text('Revoke access'));
    await tester.pumpAndSettle();

    expect(
      requests.any((r) => r.method == 'POST' && r.url.path.endsWith('/shares/1/revoke')),
      true,
    );
    expect(find.text('Revoke access'), findsNothing);
    expect(find.textContaining('Stopped'), findsOneWidget);
    expect(
      requests.where((r) => r.url.path.endsWith('/telemetry')).map((r) => r.body),
      contains(contains('share_revoked')),
    );
  });
}
