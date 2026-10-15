from datetime import datetime

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field


class EntryIn(BaseModel):
    recorded_at: AwareDatetime
    mood: int = Field(ge=1, le=5)
    symptoms: list[str] = Field(default_factory=list, max_length=20)
    note: str | None = Field(default=None, max_length=2000)


class EntryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    recorded_at: datetime
    mood: int
    symptoms: list[str]
    note: str | None


class ClinicianOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    practice: str


class Me(BaseModel):
    role: str
    id: int
    name: str
