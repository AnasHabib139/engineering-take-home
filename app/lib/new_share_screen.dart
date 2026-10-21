import 'package:flutter/material.dart';

import 'api.dart';
import 'format.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

typedef _Preset = ({String label, DateTimeRange range});

/// The quick choices for the period, ending today.
List<_Preset> _presets(DateTime today) => [
  (
    label: 'Last 7 days',
    range: DateTimeRange(start: DateTime(today.year, today.month, today.day - 6), end: today),
  ),
  (
    label: 'Last 30 days',
    range: DateTimeRange(start: DateTime(today.year, today.month, today.day - 29), end: today),
  ),
  (label: 'This month', range: DateTimeRange(start: DateTime(today.year, today.month), end: today)),
];

/// Choose a doctor, a period and whether notes are included. The summary shows exactly what is
/// shared before the patient confirms.
class NewShareScreen extends StatefulWidget {
  const NewShareScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<NewShareScreen> createState() => _NewShareScreenState();
}

class _NewShareScreenState extends State<NewShareScreen> {
  late final Future<List<Clinician>> _clinicians = widget.api.listClinicians();
  late DateTimeRange _range = _presets(dayOf(DateTime.now())).first.range;
  Clinician? _clinician;
  bool _includeNotes = false;
  bool _saving = false;

  Future<void> _pickDates() async {
    final today = dayOf(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
      initialDateRange: _range,
      helpText: 'Choose the days to share',
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _share() async {
    setState(() => _saving = true);
    try {
      await widget.api.createShare(
        clinicianId: _clinician!.id,
        from: _range.start,
        to: _range.end,
        includeNotes: _includeNotes,
      );
      widget.api.track('share_created');
      if (mounted) Navigator.of(context).pop(true);
    } on Exception {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Couldn't share your diary. Try again.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final presets = _presets(dayOf(DateTime.now()));
    final isPreset = presets.any((p) => p.range == _range);
    return Scaffold(
      appBar: AppBar(title: const Text('Share with a doctor')),
      bottomNavigationBar: SafeArea(
        child: ContentColumn(
          child: Padding(
            padding: const EdgeInsets.all(Space.m),
            child: FilledButton(
              onPressed: _clinician == null || _saving ? null : _share,
              child: const Text('Share my diary'),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Space.m),
        children: [
          ContentColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Who is it for?', style: text.titleMedium),
                const SizedBox(height: Space.s),
                FutureBuilder(
                  future: _clinicians,
                  builder: (context, snapshot) {
                    final clinicians = snapshot.data;
                    if (snapshot.hasError) {
                      return const Message(
                        title: "Couldn't load your doctors",
                        body: 'Go back and try again.',
                      );
                    }
                    if (clinicians == null) {
                      return const Padding(
                        padding: EdgeInsets.all(Space.l),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return Column(
                      children: [
                        for (final clinician in clinicians)
                          _DoctorCard(
                            clinician: clinician,
                            selected: clinician.id == _clinician?.id,
                            onTap: () => setState(() => _clinician = clinician),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: Space.xl),
                Text('Which days?', style: text.titleMedium),
                const SizedBox(height: Space.s),
                Wrap(
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: [
                    for (final preset in presets)
                      FilterChip(
                        label: Text(preset.label),
                        selected: preset.range == _range,
                        onSelected: (_) => setState(() => _range = preset.range),
                      ),
                    FilterChip(
                      avatar: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(isPreset ? 'Pick dates' : formatPeriod(_range.start, _range.end)),
                      selected: !isPreset,
                      onSelected: (_) => _pickDates(),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xl),
                PlainCard(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Include my notes', style: text.labelLarge),
                    subtitle: Text(
                      'Off by default. Your notes can be very personal.',
                      style: text.bodyMedium,
                    ),
                    value: _includeNotes,
                    onChanged: (on) => setState(() => _includeNotes = on),
                  ),
                ),
                const SizedBox(height: Space.xl),
                Text("What you're sharing", style: text.titleMedium),
                const SizedBox(height: Space.s),
                _Summary(
                  doctor: _clinician == null
                      ? 'Choose a doctor above'
                      : '${_clinician!.name}, ${_clinician!.practice}',
                  data: _includeNotes ? 'Mood, symptoms and notes' : 'Mood and symptoms only',
                  period: formatPeriod(_range.start, _range.end),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({required this.clinician, required this.selected, required this.onTap});

  final Clinician clinician;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shape = RoundedRectangleBorder(
      borderRadius: Radii.card,
      side: BorderSide(color: selected ? AppColors.ink : AppColors.line, width: selected ? 2 : 1),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s),
      child: Semantics(
        button: true,
        selected: selected,
        label: '${clinician.name}, ${clinician.practice}',
        excludeSemantics: true,
        child: Material(
          color: AppColors.surface,
          shape: shape,
          child: InkWell(
            customBorder: shape,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(Space.m),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(clinician.name, style: text.labelLarge),
                        Text(clinician.practice, style: text.labelMedium),
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: selected ? AppColors.primary : AppColors.inkMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The consent summary: recipient, categories of data and period (O.Purp_1).
class _Summary extends StatelessWidget {
  const _Summary({required this.doctor, required this.data, required this.period});

  final String doctor;
  final String data;
  final String period;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: Space.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.labelMedium),
          Text(value, style: text.bodyLarge),
        ],
      ),
    );
    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row('Shared with', doctor),
          row('What they can see', data),
          row('Days', period),
          Text(
            'You can stop sharing at any time. It takes effect straight away.',
            style: text.bodyMedium,
          ),
        ],
      ),
    );
  }
}
