#!/usr/bin/env python3
"""
Extracts ordered session event sequences from a flat log file.
Groups by session_id, sorts each group by timestamp.
"""
import re
from collections import defaultdict

LOG_RE = re.compile(
    r"(?P<ts>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)\s+"
    r"user_id=(?P<uid>\S+)\s+"
    r"session_id=(?P<sid>\S+)\s+"
    r"action=(?P<action>\S+)\s+"
    r"page=(?P<page>\S+)\s+"
    r"latency_ms=(?P<ms>\d+)"
)

def extract_sessions(log_file: str = "logs/app.log") -> dict:
    buckets: dict[str, list] = defaultdict(list)

    with open(log_file, "r") as fh:
        for raw in fh:
            m = LOG_RE.match(raw.strip())
            if not m:
                continue
            buckets[m.group("sid")].append({
                "timestamp":  m.group("ts"),
                "user_id":    m.group("uid"),
                "action":     m.group("action"),
                "page":       m.group("page"),
                "latency_ms": int(m.group("ms")),
            })

    result = {}
    for sid, events in buckets.items():
        events.sort(key=lambda e: e["timestamp"])
        result[sid] = {
            "session_id": sid,
            "user_id":    events[0]["user_id"],
            "start_time": events[0]["timestamp"],
            "end_time":   events[-1]["timestamp"],
            "events":     events,
            "page_count": len(events),
        }
    return result

if __name__ == "__main__":
    s = extract_sessions()
    print(f"Extracted {len(s)} sessions")
    for sid, sess in list(s.items())[:3]:
        pages = " → ".join(e["page"] for e in sess["events"])
        print(f"  {sid} ({sess['user_id']}): {pages}")
