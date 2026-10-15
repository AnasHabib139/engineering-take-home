# Design

The app is for patients who log how they feel, often on a bad day. It should feel calm, plain
and easy to read. New screens must look like the existing ones: reuse the tokens and widgets
below rather than adding new styles.

## Principles

- **Mood is the only colour that speaks.** The five mood colours run from stormy to sunny.
  Everything else stays neutral (ink on paper) so the mood stands out.
- **No judgement.** A low mood is not an error: never use red or warning styles for it.
- **Legible first.** Large type, generous spacing, one column.
- **Never colour alone.** Every mood colour is paired with its label (`Mood.label`).

## Tokens (`lib/theme.dart`)

| Token | Value | Use |
| --- | --- | --- |
| `AppColors.ink` | `#18233A` | Text, icons, selected outlines |
| `AppColors.inkMuted` | `#5A6478` | Secondary text: dates, times, helper text |
| `AppColors.paper` | `#F3F5F9` | Screen background |
| `AppColors.surface` | `#FFFFFF` | Cards, inputs, chips |
| `AppColors.line` | `#DDE2EA` | Borders, empty states |
| `AppColors.primary` | `#2F3E9E` | The one main action per screen |
| `AppColors.error` | `#B3261E` | Real errors only (failed request, invalid input) |
| `Mood.color(1…5)` | `#4B4E8C` `#5272A6` `#A9B4C4` `#F0C75E` `#F59E3D` | Very low → very good |

**Type:** Atkinson Hyperlegible (bundled, built for low-vision readers), regular and bold only.
Use the theme styles, never a raw `fontSize`:

| Style | Size / weight | Use |
| --- | --- | --- |
| `headlineMedium` | 32 bold | Screen title, the chosen mood |
| `titleMedium` | 18 bold | Section and day headings |
| `bodyLarge` | 16 | Primary content, e.g. a note |
| `bodyMedium` | 15, muted | Supporting text |
| `labelLarge` | 16 bold | Buttons, the mood name on a card |
| `labelMedium` | 14, muted | Times, symptom tags, metadata |

**Spacing:** `Space.xs/s/m/l/xl` = 4 / 8 / 16 / 24 / 40. Screen padding is `Space.m`; gaps
between sections are `Space.xl`.

**Shape:** cards `Radii.card` (16), inputs and buttons `Radii.control` (12), chips are pills.
No shadows; cards sit on the paper background.

## Layout

- One column, left-aligned, wrapped in `ContentColumn` (max 560 px wide) so it reads well on a
  phone and in a desktop browser.
- Screen title in `headlineMedium`, then content grouped under `titleMedium` headings.
- The main action is a `FloatingActionButton.extended` on lists, or a full-width
  `FilledButton` pinned to the bottom on forms.

## Components

| Widget | Where | Use it for |
| --- | --- | --- |
| `EntryCard` | `diary_screen.dart` | One diary entry: mood rail, mood name, time, symptoms, note |
| `MoodPicker` | `add_entry_screen.dart` | Choosing a mood |
| `SymptomTag` | `widgets.dart` | Showing a symptom (read-only) |
| `FilterChip` | Flutter | Choosing from a short list |
| `ContentColumn` | `widgets.dart` | Every screen's content |

A list of people or records (e.g. clinicians) uses white cards like `EntryCard`, without the
mood rail.

## Words

- Sentence case everywhere. No all-caps labels.
- Buttons say what happens: "Save entry", "Revoke access", not "Submit" or "OK".
- Errors say what failed and what to do: "Couldn't save the entry. Try again."
- Empty screens invite the next step: "Your diary is empty. Note how you feel today."
- Write for patients: "your doctor", not "clinician entity"; "who saw your diary", not
  "audit log".

## Accessibility

- Text contrast at least 4.5:1 (the tokens above meet it; check new combinations).
- Tap targets at least 48 × 48 px.
- Custom controls get a `Semantics` label, like the mood swatches.
