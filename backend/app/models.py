from datetime import date, datetime

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    false,
    func,
)
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class Patient(Base):
    __tablename__ = "patients"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(200))
    email: Mapped[str] = mapped_column(String(320), unique=True)
    timezone: Mapped[str] = mapped_column(String(64))  # IANA name, e.g. "Europe/Berlin"
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Clinician(Base):
    __tablename__ = "clinicians"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(200))
    practice: Mapped[str] = mapped_column(String(200))


class DiaryEntry(Base):
    __tablename__ = "diary_entries"
    __table_args__ = (CheckConstraint("mood BETWEEN 1 AND 5", name="mood_range"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    patient_id: Mapped[int] = mapped_column(ForeignKey("patients.id"), index=True)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    mood: Mapped[int]
    symptoms: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list)
    note: Mapped[str | None] = mapped_column(Text)
    # "app-v1" entries were sent without a time zone and stored as if they were UTC.
    source: Mapped[str] = mapped_column(String(16), server_default="app-v2")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Share(Base):
    __tablename__ = "shares"
    __table_args__ = (CheckConstraint("from_date <= to_date", name="share_period"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    patient_id: Mapped[int] = mapped_column(ForeignKey("patients.id"), index=True)
    clinician_id: Mapped[int] = mapped_column(ForeignKey("clinicians.id"), index=True)
    # Inclusive calendar dates in the patient's own time zone.
    from_date: Mapped[date] = mapped_column(Date)
    to_date: Mapped[date] = mapped_column(Date)
    include_notes: Mapped[bool] = mapped_column(server_default=false())
    # Version of the consent text the patient agreed to (O.Cons_3).
    consent_version: Mapped[str] = mapped_column(String(32))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class AccessLog(Base):
    """One row per doctor read. Append-only: a trigger rejects UPDATE and DELETE (O.Log_3).

    patient_id and share_id are deliberately not foreign keys, so erasing a patient's data never
    has to touch these records.
    """

    __tablename__ = "access_log"

    id: Mapped[int] = mapped_column(primary_key=True)
    patient_id: Mapped[int] = mapped_column(index=True)
    share_id: Mapped[int | None]
    clinician_id: Mapped[int] = mapped_column(ForeignKey("clinicians.id"))
    entry_ids: Mapped[list[int]] = mapped_column(ARRAY(Integer), default=list)
    accessed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
