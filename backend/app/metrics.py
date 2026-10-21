"""Prometheus metrics, served on /metrics and scraped by the platform team."""

from collections.abc import Iterable

from prometheus_client import REGISTRY, Counter, Histogram
from prometheus_client.core import GaugeMetricFamily
from prometheus_client.registry import Collector
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.db import SessionLocal

REQUESTS = Counter(
    "http_requests_total",
    "HTTP requests by route template and status.",
    ["method", "route", "status"],
)
APP_EVENTS = Counter("app_events_total", "Product events sent by the app.", ["event"])
SHARES_CREATED = Counter("shares_created_total", "Diary shares created by patients.")
SHARES_REVOKED = Counter("shares_revoked_total", "Diary shares revoked by patients.")
CLINICIAN_READS = Counter(
    "clinician_reads_total", "Doctor reads of a shared diary by outcome.", ["outcome"]
)
ACCESS_LOG_FAILURES = Counter(
    "access_log_write_failures_total", "Doctor reads that could not be recorded in the access log."
)
LATENCY = Histogram(
    "http_request_duration_seconds", "HTTP request duration by route template.", ["method", "route"]
)


class CohortCollector(Collector):
    """Aggregate counts of patients who have shared their diary versus those who haven't.

    Computed from the database on every scrape. Only counts leave the database, never ids or
    anything about a single patient (O.Log_4 and the "no patient data in metrics" rule).
    """

    QUERY = text(
        """
        SELECT p.id IN (SELECT patient_id FROM shares) AS sharer,
               count(*) AS patients,
               count(*) FILTER (WHERE EXISTS (
                   SELECT 1 FROM diary_entries e
                   WHERE e.patient_id = p.id AND e.recorded_at > now() - interval '7 days'
               )) AS logging
        FROM patients p
        GROUP BY 1
        """
    )

    def collect(self) -> Iterable[GaugeMetricFamily]:
        patients = GaugeMetricFamily(
            "diary_patients",
            "Patients by whether they have ever shared their diary.",
            labels=["cohort"],
        )
        logging = GaugeMetricFamily(
            "diary_patients_logging_7d",
            "Patients with a diary entry in the last 7 days, by sharing cohort.",
            labels=["cohort"],
        )
        counts = {"sharers": (0, 0), "others": (0, 0)}
        try:
            with SessionLocal() as db:
                for sharer, total, active in db.execute(self.QUERY):
                    counts["sharers" if sharer else "others"] = (total, active)
        except SQLAlchemyError:
            return  # a database problem must not take /metrics down with it
        for cohort, (total, active) in counts.items():
            patients.add_metric([cohort], total)
            logging.add_metric([cohort], active)
        yield patients
        yield logging


REGISTRY.register(CohortCollector())


# Start known series at 0: Prometheus can't see the first increment of a series that appears
# already above 0, so rate() and increase() would miss each event's first occurrence.
for _event in ("entry_created", "sharing_opened", "share_created", "share_revoked"):
    APP_EVENTS.labels(_event)
for _outcome in ("ok", "denied"):
    CLINICIAN_READS.labels(_outcome)
