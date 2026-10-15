"""Demo data. Runs on every API start and only inserts into an empty database."""

from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import SessionLocal
from app.models import Clinician, DiaryEntry, Patient

# (days ago, UTC hour, UTC minute, mood, symptoms, note)
ENTRIES = [
    (0, 7, 15, 4, ["fatigue"], "Better sleep than yesterday."),
    (1, 22, 30, 2, ["headache", "nausea"], "Woke up with a headache, took ibuprofen."),
    (2, 18, 0, 3, [], None),
    (4, 6, 45, 3, ["fatigue"], "Skipped the morning walk."),
    (6, 20, 10, 5, [], "Good day, no complaints."),
]

# Written by app v1 in March 2026: local wall-clock time, stored as if it were UTC.
APP_V1_ENTRIES = [
    (datetime(2026, 3, 12, 8, 10, tzinfo=UTC), 3, ["headache"], "First week with the app."),
    (datetime(2026, 3, 14, 23, 50, tzinfo=UTC), 2, ["pain"], "Couldn't sleep, back pain again."),
    (datetime(2026, 3, 15, 9, 30, tzinfo=UTC), 3, [], None),
]


def seed_users(db: Session) -> Patient:
    """Adds two patients and two clinicians; returns the first patient."""
    anna = Patient(name="Anna Becker", email="anna.becker@example.com", timezone="Europe/Berlin")
    db.add_all(
        [
            anna,
            Patient(name="Jonas Weber", email="jonas.weber@example.com", timezone="Europe/Lisbon"),
            Clinician(name="Dr. Lena Hofmann", practice="Praxis Hofmann, München"),
            Clinician(name="Dr. Felix Braun", practice="Hausarztpraxis Schwabing"),
        ]
    )
    db.flush()
    return anna


def seed_entries(db: Session, patient_id: int) -> None:
    today = datetime.now(UTC)
    for days_ago, hour, minute, mood, symptoms, note in ENTRIES:
        recorded_at = (today - timedelta(days=days_ago)).replace(
            hour=hour, minute=minute, second=0, microsecond=0
        )
        db.add(
            DiaryEntry(
                patient_id=patient_id,
                recorded_at=recorded_at,
                mood=mood,
                symptoms=symptoms,
                note=note,
            )
        )
    for recorded_at, mood, symptoms, note in APP_V1_ENTRIES:
        db.add(
            DiaryEntry(
                patient_id=patient_id,
                recorded_at=recorded_at,
                mood=mood,
                symptoms=symptoms,
                note=note,
                source="app-v1",
            )
        )


def main() -> None:
    with SessionLocal() as db:
        if db.scalar(select(Patient).limit(1)) is not None:
            return
        anna = seed_users(db)
        seed_entries(db, patient_id=anna.id)
        db.commit()


if __name__ == "__main__":
    main()
