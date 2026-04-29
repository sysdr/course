#!/usr/bin/env python3
"""
Generates realistic e-commerce application logs for user journey tracking.
Log format: ISO_TS user_id=UXX session_id=SXX action=ACTION page=PAGE latency_ms=N
"""
import os
import sys
import random
from datetime import datetime, timedelta, timezone

JOURNEY_TEMPLATES = [
    ["/home", "/products", "/product/detail", "/cart", "/checkout", "/payment", "/confirmation"],
    ["/home", "/search",   "/product/detail", "/cart", "/checkout", "/payment", "/confirmation"],
    ["/home", "/products", "/product/detail", "/cart", "/checkout"],
    ["/home", "/search",   "/product/detail", "/cart"],
    ["/home", "/products", "/product/detail", "/home"],
    ["/home", "/profile"],
    ["/home", "/products"],
    ["/home", "/search",   "/product/detail", "/home"],
    ["/home", "/products", "/product/detail", "/cart", "/checkout", "/payment"],
]

PAGE_ACTION = {
    "/home": "page_view", "/products": "page_view", "/product/detail": "page_view",
    "/search": "search", "/cart": "add_to_cart", "/checkout": "page_view",
    "/payment": "purchase", "/confirmation": "page_view", "/profile": "page_view",
}

def generate_logs(num_sessions: int = 80, output_file: str = "logs/app.log") -> str:
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    lines = []
    base_time = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(hours=4)
    user_pool = [f"u{i:03d}" for i in range(1, 25)]

    for idx in range(num_sessions):
        user_id    = random.choice(user_pool)
        session_id = f"s{idx + 1:04d}"
        template   = random.choice(JOURNEY_TEMPLATES)
        current_t  = base_time + timedelta(minutes=random.randint(0, 240))

        for page in template:
            action  = PAGE_ACTION.get(page, "page_view")
            latency = random.randint(15, 600)
            ts      = current_t.strftime("%Y-%m-%dT%H:%M:%SZ")
            lines.append(
                f"{ts} user_id={user_id} session_id={session_id} "
                f"action={action} page={page} latency_ms={latency}"
            )
            current_t += timedelta(seconds=random.randint(4, 180))

    random.shuffle(lines)   # deliberately unordered — extractor must sort
    with open(output_file, "w") as f:
        f.write("\n".join(lines) + "\n")

    print(f"Generated {len(lines)} log lines across {num_sessions} sessions → {output_file}")
    return output_file

if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 80
    generate_logs(n)
