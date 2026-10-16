# Brief: sharing the diary with a doctor

Notes from the kick-off call, lightly edited. You weren't there, so here is what was said.

**Mara (Product):** Patients keep asking to show their diary to their doctor before an
appointment. So: a patient picks their doctor and a period, the doctor can read the diary for
that period, and the patient can stop sharing at any time. The clinician portal team has already
built their side against `API.md`, so please stick to that contract.

**Dr. Keller (Medical lead):** Two things from the clinical side. When a patient shares "last
week", they mean the days as they see them in their diary, in their own time zone. If someone
logs a headache at half past midnight, it belongs to that day, not to the day before. And
honestly, I don't need their private notes. Mood and symptoms are what I work with.

**Selin (Data protection):** Then notes stay private unless the patient explicitly includes
them. Also, a doctor must never be able to find out whether someone is a patient of ours at
all. And every time a doctor reads a diary, we record it and show it to the patient. Our
auditors expect those records to be kept for ten years.

**Mara:** Patients should see that in plain words: who looked at their diary, and when.

**Selin:** One more thing. If a patient asks us to erase their data, we have to remove it. All
of it.

**Dr. Keller:** All of it? Including the record of which doctor saw what? That's our evidence
if something goes wrong clinically.

**Mara:** Let's not build erasure in this iteration, but please don't build anything that makes
it impossible. Write down how you would do it.

**Tom (Mobile lead):** Two warnings from the app side. First, app version 2.3 is still on about
a third of phones and we can't force an update. It parses `/entries` and `/me` strictly: one new
or renamed field and it crashes. So those responses stay exactly as they are. Second, entries
written by the old app (v1, until April) were sent without a time zone, and the backend stored
the local time as if it were UTC. They are marked `source = 'app-v1'`. We never fixed those rows.

**Lukas (Platform, on call this week):** One more from me. Doctors will open this right before
an appointment. If it breaks, the clinic calls support and support calls me, usually at 8 in the
morning. I'd like to see it break before they do. Tell me what you'd measure, what should wake me
up and what can wait until the morning, and how I'd see what's going on when it's on fire.

**Selin:** And no patient data in your monitoring either, please. Metrics end up in more places
than the database does.

**Mara:** And from my side: in three months I have to say whether sharing was worth building.
Do patients actually use it, and do the ones who share keep logging their diary? Great, thanks
all. Two hours, and tell us what you would do next.
