import 'package:flutter/material.dart';

import 'api.dart';
import 'format.dart';
import 'models.dart';
import 'new_share_screen.dart';
import 'theme.dart';
import 'widgets.dart';

typedef _Data = ({List<Share> shares, Map<int, Clinician> clinicians, List<AccessEvent> log});

/// Who can see the diary, who looked at it, and how to stop sharing.
class SharingScreen extends StatefulWidget {
  const SharingScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<SharingScreen> createState() => _SharingScreenState();
}

class _SharingScreenState extends State<SharingScreen> {
  late Future<_Data> _data = _load();

  Future<_Data> _load() async {
    final (shares, clinicians, log) = await (
      widget.api.listShares(),
      widget.api.listClinicians(),
      widget.api.listAccessLog(),
    ).wait;
    return (shares: shares, clinicians: {for (final c in clinicians) c.id: c}, log: log);
  }

  void _reload() {
    setState(() {
      _data = _load();
    });
  }

  Future<void> _newShare() async {
    final shared = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => NewShareScreen(api: widget.api)));
    if (shared == true) _reload();
  }

  Future<void> _revoke(Share share) async {
    try {
      await widget.api.revokeShare(share.id);
      widget.api.track('share_revoked');
      _reload();
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Couldn't revoke access. Try again.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sharing')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newShare,
        icon: const Icon(Icons.add),
        label: const Text('Share with a doctor'),
      ),
      body: SafeArea(
        child: FutureBuilder(
          future: _data,
          builder: (context, snapshot) {
            final data = snapshot.data;
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.m, 96),
                children: [
                  ContentColumn(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your doctor can read the mood and symptoms you choose to share. '
                          'You can stop at any time.',
                          style: text.bodyMedium,
                        ),
                        if (snapshot.hasError)
                          Message(
                            title: "Couldn't load your sharing settings",
                            body: 'Check your connection and try again.',
                            action: TextButton(onPressed: _reload, child: const Text('Try again')),
                          )
                        else if (data == null)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: Space.xl),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else ...[
                          const SizedBox(height: Space.xl),
                          Text('Who can see your diary', style: text.titleMedium),
                          const SizedBox(height: Space.s),
                          if (data.shares.isEmpty)
                            const Message(
                              title: "You haven't shared your diary",
                              body: 'Share it with your doctor before your next appointment.',
                            )
                          else
                            for (final share in [
                              ...data.shares.where((s) => s.active),
                              ...data.shares.where((s) => !s.active),
                            ])
                              _ShareCard(
                                share: share,
                                clinician: data.clinicians[share.clinicianId],
                                onRevoke: () => _revoke(share),
                              ),
                          const SizedBox(height: Space.xl),
                          Text('Who saw your diary', style: text.titleMedium),
                          const SizedBox(height: Space.s),
                          if (data.log.isEmpty)
                            const Message(
                              title: 'No one has looked yet',
                              body: "When a doctor opens your diary, you'll see it here.",
                            )
                          else
                            for (final event in data.log) _AccessCard(event),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.share, required this.clinician, required this.onRevoke});

  final Share share;
  final Clinician? clinician;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = share.active ? null : text.labelMedium;
    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(clinician?.name ?? 'Your doctor', style: muted ?? text.labelLarge),
              ),
              Text(
                share.active ? 'Active' : 'Stopped ${formatShortDate(dayOf(share.revokedAt!))}',
                style: text.labelMedium,
              ),
            ],
          ),
          if (clinician != null) Text(clinician!.practice, style: text.labelMedium),
          const SizedBox(height: Space.s),
          Text(formatPeriod(share.fromDate, share.toDate), style: muted ?? text.bodyLarge),
          const SizedBox(height: Space.xs),
          Row(
            children: [
              Icon(
                share.includeNotes ? Icons.notes : Icons.lock_outline,
                size: 18,
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: Space.xs),
              Text(
                share.includeNotes ? 'Mood, symptoms and notes' : 'Mood and symptoms only',
                style: text.labelMedium,
              ),
            ],
          ),
          if (share.active) ...[
            const SizedBox(height: Space.s),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: onRevoke, child: const Text('Revoke access')),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard(this.event);

  final AccessEvent event;

  String get _summary => switch (event.entryCount) {
    0 => 'Opened your diary. Nothing was in the shared period.',
    1 => 'Looked at 1 entry',
    final n => 'Looked at $n entries',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PlainCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: Space.m),
            child: Icon(Icons.visibility_outlined, color: AppColors.inkMuted),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.clinicianName, style: text.labelLarge),
                Text(_summary, style: text.bodyMedium),
              ],
            ),
          ),
          Text(formatDateTime(event.accessedAt), style: text.labelMedium),
        ],
      ),
    );
  }
}
