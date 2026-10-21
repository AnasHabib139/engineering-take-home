from collections.abc import Sequence
from datetime import UTC, date, datetime
from typing import Annotated, Any
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import Row, func, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.auth import User, current_clinician, current_patient, current_user
from app.db import get_db
from app.metrics import (
    ACCESS_LOG_FAILURES,
    APP_EVENTS,
    CLINICIAN_READS,
    SHARES_CREATED,
    SHARES_REVOKED,
)
from app.models import AccessLog, Clinician, DiaryEntry, Patient, Share
from app.schemas import (
    AccessLogOut,
    ClinicianEntryOut,
    ClinicianOut,
    EntryIn,
    EntryOut,
    Me,
    ShareIn,
    ShareOut,
    TelemetryEvent,
)

router = APIRouter()

# Version of the consent text shown in the app when a patient shares (O.Cons_3).
CONSENT_VERSION = "2026-10-v1"

Db = Annotated[Session, Depends(get_db)]
AnyUser = Annotated[User, Depends(current_user)]
PatientUser = Annotated[User, Depends(current_patient)]
ClinicianUser = Annotated[User, Depends(current_clinician)]


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/me", response_model=Me)
def me(user: AnyUser) -> User:
    return user


@router.get("/clinicians", response_model=list[ClinicianOut])
def list_clinicians(_: AnyUser, db: Db) -> Sequence[Clinician]:
    return db.scalars(select(Clinician).order_by(Clinician.name)).all()


@router.get("/entries", response_model=list[EntryOut])
def list_entries(user: PatientUser, db: Db) -> Sequence[DiaryEntry]:
    query = (
        select(DiaryEntry)
        .where(DiaryEntry.patient_id == user.id)
        .order_by(DiaryEntry.recorded_at.desc())
    )
    return db.scalars(query).all()


@router.post("/entries", response_model=EntryOut, status_code=201)
def create_entry(body: EntryIn, user: PatientUser, db: Db) -> DiaryEntry:
    entry = DiaryEntry(patient_id=user.id, **body.model_dump())
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return entry


@router.post("/shares", response_model=ShareOut, status_code=201)
def create_share(body: ShareIn, user: PatientUser, db: Db) -> Share:
    if db.get(Clinician, body.clinician_id) is None:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Unknown clinician")
    share = Share(patient_id=user.id, consent_version=CONSENT_VERSION, **body.model_dump())
    db.add(share)
    db.commit()
    db.refresh(share)
    SHARES_CREATED.inc()
    return share


@router.get("/shares", response_model=list[ShareOut])
def list_shares(user: PatientUser, db: Db) -> Sequence[Share]:
    query = select(Share).where(Share.patient_id == user.id).order_by(Share.id.desc())
    return db.scalars(query).all()


@router.post("/shares/{share_id}/revoke", response_model=ShareOut)
def revoke_share(share_id: int, user: PatientUser, db: Db) -> Share:
    share = db.scalar(select(Share).where(Share.id == share_id, Share.patient_id == user.id))
    if share is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Share not found")
    if share.revoked_at is None:
        share.revoked_at = func.now()
        db.commit()
        db.refresh(share)
        SHARES_REVOKED.inc()
    return share


def patient_day(entry: DiaryEntry, tz: ZoneInfo) -> tuple[date, datetime]:
    """The calendar day an entry belongs to in the patient's time zone, and its real instant.

    App-v1 entries stored the patient's local wall-clock time as if it were UTC, so for those the
    wall-clock time is reinterpreted in the patient's zone instead of converted.
    """
    instant = entry.recorded_at
    if entry.source == "app-v1":
        instant = instant.astimezone(UTC).replace(tzinfo=tz)
    return instant.astimezone(tz).date(), instant.astimezone(UTC)


@router.get("/clinician/patients/{patient_id}/entries", response_model=list[ClinicianEntryOut])
def clinician_entries(patient_id: int, user: ClinicianUser, db: Db) -> list[dict[str, Any]]:
    shares = db.scalars(
        select(Share)
        .where(
            Share.patient_id == patient_id,
            Share.clinician_id == user.id,
            Share.revoked_at.is_(None),
        )
        .order_by(Share.id.desc())
    ).all()
    if not shares:
        # Same answer for "no such patient" and "not shared with you": no patient enumeration.
        CLINICIAN_READS.labels("denied").inc()
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Not found")

    patient = db.get_one(Patient, patient_id)
    tz = ZoneInfo(patient.timezone)
    # ponytail: filters in Python; move the day filter into SQL if diaries grow to thousands of rows
    entries = db.scalars(select(DiaryEntry).where(DiaryEntry.patient_id == patient_id)).all()
    visible = []
    for entry in entries:
        day, instant = patient_day(entry, tz)
        covering = [s for s in shares if s.from_date <= day <= s.to_date]
        if covering:
            show_note = any(s.include_notes for s in covering)
            visible.append((instant, entry, show_note))
    visible.sort(key=lambda item: item[0], reverse=True)

    # Record the access before any data leaves: if this fails, the doctor gets nothing (O.Log_1).
    try:
        db.add(
            AccessLog(
                patient_id=patient_id,
                share_id=shares[0].id,  # newest active share
                clinician_id=user.id,
                entry_ids=[entry.id for _, entry, _ in visible],
            )
        )
        db.commit()
    except SQLAlchemyError:
        db.rollback()
        ACCESS_LOG_FAILURES.inc()
        raise HTTPException(
            status.HTTP_500_INTERNAL_SERVER_ERROR, "Could not record access"
        ) from None
    CLINICIAN_READS.labels("ok").inc()
    return [
        {
            "id": entry.id,
            "recorded_at": instant,
            "mood": entry.mood,
            "symptoms": entry.symptoms,
            "note": entry.note if show_note else None,
        }
        for instant, entry, show_note in visible
    ]


@router.get("/access-log", response_model=list[AccessLogOut])
def access_log(user: PatientUser, db: Db) -> Sequence[Row[Any]]:
    query = (
        select(
            AccessLog.clinician_id,
            Clinician.name.label("clinician_name"),
            AccessLog.accessed_at,
            AccessLog.entry_ids,
        )
        .join(Clinician, Clinician.id == AccessLog.clinician_id)
        .where(AccessLog.patient_id == user.id)
        .order_by(AccessLog.id.desc())
    )
    return db.execute(query).all()


@router.post("/telemetry", status_code=204)
def telemetry(body: TelemetryEvent, _: AnyUser) -> Response:
    APP_EVENTS.labels(body.event).inc()
    return Response(status_code=204)
