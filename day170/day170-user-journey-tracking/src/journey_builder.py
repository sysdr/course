#!/usr/bin/env python3
"""
Builds journey path objects from extracted sessions.
A journey is the deduplicated ordered sequence of pages in a session.
"""
from collections import Counter

def build_journeys(sessions: dict) -> list[dict]:
    journeys = []
    for sid, session in sessions.items():
        pages = [e["page"] for e in session["events"]]
        # Collapse consecutive identical pages (e.g. browser refresh)
        deduped = [pages[0]]
        for p in pages[1:]:
            if p != deduped[-1]:
                deduped.append(p)

        total_latency = sum(e["latency_ms"] for e in session["events"])
        avg_latency   = round(total_latency / len(session["events"]), 1)
        converted     = deduped[-1] == "/confirmation"

        journeys.append({
            "session_id":    sid,
            "user_id":       session["user_id"],
            "path":          deduped,
            "path_str":      " → ".join(deduped),
            "steps":         len(deduped),
            "avg_latency_ms": avg_latency,
            "converted":     converted,
            "start_time":    session["start_time"],
        })
    return journeys

def get_top_paths(journeys: list[dict], top_n: int = 10) -> list[dict]:
    path_counter = Counter(j["path_str"] for j in journeys)
    return [{"path": p, "count": c} for p, c in path_counter.most_common(top_n)]

if __name__ == "__main__":
    from session_extractor import extract_sessions
    sessions  = extract_sessions()
    journeys  = build_journeys(sessions)
    top_paths = get_top_paths(journeys)
    print(f"Built {len(journeys)} journeys")
    for tp in top_paths[:5]:
        print(f"  [{tp['count']:2d}x] {tp['path']}")
