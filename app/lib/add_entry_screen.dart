import 'package:flutter/material.dart';

import 'api.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

const commonSymptoms = ['headache', 'fatigue', 'nausea', 'dizziness', 'pain', 'poor sleep'];

class AddEntryScreen extends StatefulWidget {
  const AddEntryScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final _otherSymptoms = TextEditingController();
  final _note = TextEditingController();
  final _symptoms = <String>{};
  int _mood = 3;
  bool _saving = false;

  @override
  void dispose() {
    _otherSymptoms.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final other = _otherSymptoms.text.split(',').map((s) => s.trim().toLowerCase());
    final note = _note.text.trim();
    final entry = DiaryEntry(
      recordedAt: DateTime.now(),
      mood: _mood,
      symptoms: {..._symptoms, ...other.where((s) => s.isNotEmpty)}.toList(),
      note: note.isEmpty ? null : note,
    );
    try {
      await widget.api.createEntry(entry);
      if (mounted) Navigator.of(context).pop(true);
    } on Exception {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Couldn't save the entry. Try again.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('New entry')),
      bottomNavigationBar: SafeArea(
        child: ContentColumn(
          child: Padding(
            padding: const EdgeInsets.all(Space.m),
            child: FilledButton(onPressed: _saving ? null : _save, child: const Text('Save entry')),
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
                Text('How are you feeling?', style: text.titleMedium),
                const SizedBox(height: Space.m),
                MoodPicker(value: _mood, onChanged: (mood) => setState(() => _mood = mood)),
                const SizedBox(height: Space.xl),
                Text('Symptoms', style: text.titleMedium),
                const SizedBox(height: Space.s),
                Wrap(
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: [
                    for (final symptom in commonSymptoms)
                      FilterChip(
                        label: Text(sentenceCase(symptom)),
                        selected: _symptoms.contains(symptom),
                        onSelected: (on) =>
                            setState(() => on ? _symptoms.add(symptom) : _symptoms.remove(symptom)),
                      ),
                  ],
                ),
                const SizedBox(height: Space.m),
                TextField(
                  controller: _otherSymptoms,
                  decoration: const InputDecoration(
                    labelText: 'Other symptoms',
                    helperText: 'Separate several with commas',
                  ),
                ),
                const SizedBox(height: Space.xl),
                Text('Note', style: text.titleMedium),
                const SizedBox(height: Space.s),
                TextField(
                  controller: _note,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(hintText: 'What happened, what helped?'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Five large swatches, stormy to sunny. The chosen mood's name shows below.
class MoodPicker extends StatelessWidget {
  const MoodPicker({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (final mood in Mood.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                  child: _Swatch(mood: mood, selected: mood == value, onTap: () => onChanged(mood)),
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.m),
        Text(Mood.label(value), style: Theme.of(context).textTheme.headlineMedium),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.mood, required this.selected, required this.onTap});

  final int mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Mood $mood of 5, ${Mood.label(mood)}',
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('mood-$mood'),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: selected ? 72 : 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Mood.color(mood),
            borderRadius: Radii.control,
            border: Border.all(color: selected ? AppColors.ink : Colors.transparent, width: 3),
          ),
          child: Text(
            '$mood',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Mood.onColor(mood)),
          ),
        ),
      ),
    );
  }
}
