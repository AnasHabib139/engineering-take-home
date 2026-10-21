import logging
import time
from collections.abc import Awaitable, Callable

from fastapi import FastAPI, Request, Response
from fastapi.responses import JSONResponse
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest

from app.api import router
from app.metrics import LATENCY, REQUESTS

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
logger = logging.getLogger("diary.requests")

app = FastAPI(title="Symptom Diary API")
app.include_router(router)


@app.middleware("http")
async def log_requests(
    request: Request, call_next: Callable[[Request], Awaitable[Response]]
) -> Response:
    started = time.perf_counter()
    try:
        response = await call_next(request)
    except Exception as error:
        # Only the type is logged: messages can carry SQL parameters, i.e. health data (O.Log_4).
        logger.error("Unhandled %s", type(error).__name__)
        # Generic body, no internals (O.Err_1). Answered here so the request is still counted.
        response = JSONResponse({"detail": "Internal server error"}, status_code=500)
    route = request.scope["route"].path if "route" in request.scope else "unmatched"
    REQUESTS.labels(request.method, route, response.status_code).inc()
    LATENCY.labels(request.method, route).observe(time.perf_counter() - started)
    # The route template, never the raw path or body: both can carry patient data (O.Log_4).
    logger.info(
        "%s %s -> %s in %.0f ms",
        request.method,
        route,
        response.status_code,
        (time.perf_counter() - started) * 1000,
    )
    return response


@app.get("/metrics", include_in_schema=False)
def metrics() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
