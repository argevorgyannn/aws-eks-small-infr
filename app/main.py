import json
import logging
import sys
import time

from fastapi import FastAPI, Query, Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, generate_latest


class JsonFormatter(logging.Formatter):
    """One JSON object per line, easy to parse in Loki."""

    def format(self, record):
        entry = {
            "time": self.formatTime(record),
            "level": record.levelname,
            "message": record.getMessage(),
        }
        entry.update(getattr(record, "fields", {}))
        return json.dumps(entry)


handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JsonFormatter())
logger = logging.getLogger("app")
logger.setLevel(logging.INFO)
logger.addHandler(handler)

REQUESTS = Counter("http_requests_total", "Total HTTP requests", ["method", "path", "status"])
LATENCY = Histogram("http_request_duration_seconds", "HTTP request latency in seconds", ["method", "path"])
IN_PROGRESS = Gauge("http_requests_in_progress", "Requests currently being processed")

app = FastAPI(title="demo-app")


@app.middleware("http")
async def observe(request: Request, call_next):
    if request.url.path in ("/metrics", "/healthz"):
        return await call_next(request)

    start = time.perf_counter()
    status = 500
    IN_PROGRESS.inc()
    try:
        response = await call_next(request)
        status = response.status_code
        return response
    finally:
        IN_PROGRESS.dec()
        duration = time.perf_counter() - start
        route = request.scope.get("route")
        path = route.path if route else "unmatched"  # route template keeps label cardinality low
        REQUESTS.labels(request.method, path, str(status)).inc()
        LATENCY.labels(request.method, path).observe(duration)
        logger.info(
            "request",
            extra={"fields": {"method": request.method, "path": request.url.path,
                              "status": status, "duration_ms": round(duration * 1000, 2)}},
        )


@app.get("/")
def index():
    return {"message": "hello from demo-app"}


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/work")
def work(ms: int = Query(100, ge=1, le=2000)):
    """Burns CPU for `ms` milliseconds. Used to trigger CPU alerts and for load tests."""
    end = time.perf_counter() + ms / 1000
    while time.perf_counter() < end:
        pass
    return {"burned_ms": ms}


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
