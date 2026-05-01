"""
Log Simulator — generates realistic user-session log events.
Produces JSON lines that mimic an application log stream.
"""
import random, time, uuid, json, sys
from datetime import datetime, timezone

PAGES   = ["/", "/products", "/product/detail", "/cart", "/checkout", "/confirmation"]
EVENTS  = ["page_view", "add_to_cart", "checkout_start", "purchase", "page_view", "page_view"]
WEIGHTS = [0.35, 0.20, 0.15, 0.08, 0.15, 0.07]

def _latency_ms(page: str) -> float:
    """Simulate realistic latency distribution per page."""
    base = {"/" : 120, "/products": 280, "/product/detail": 350,
            "/cart": 200, "/checkout": 450, "/confirmation": 180}
    mu = base.get(page, 250)
    # log-normal to get occasional spikes
    return max(10.0, random.lognormvariate(0, 0.5) * mu)

def _status_code() -> int:
    r = random.random()
    if r < 0.003: return 500
    if r < 0.006: return 503
    if r < 0.012: return 404
    return 200

def generate_events(n: int = 10_000):
    """Yield n synthetic log event dicts."""
    user_pool = [str(uuid.uuid4()) for _ in range(n // 8)]
    session_pool: dict[str, str] = {}

    for _ in range(n):
        user_id = random.choice(user_pool)
        if user_id not in session_pool:
            session_pool[user_id] = str(uuid.uuid4())

        page   = random.choices(PAGES, k=1)[0]
        event  = random.choices(EVENTS, weights=WEIGHTS, k=1)[0]
        status = _status_code()

        # refresh session occasionally (simulates new visit)
        if random.random() < 0.04:
            session_pool[user_id] = str(uuid.uuid4())

        yield {
            "timestamp"  : datetime.now(timezone.utc).isoformat(),
            "user_id"    : user_id,
            "session_id" : session_pool[user_id],
            "event_type" : event,
            "page"       : page,
            "latency_ms" : round(_latency_ms(page), 2),
            "status_code": status,
        }

if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 100
    for ev in generate_events(n):
        print(json.dumps(ev))
