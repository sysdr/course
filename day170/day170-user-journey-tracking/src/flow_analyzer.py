#!/usr/bin/env python3
"""
Analyzes user flow from journey paths.
Computes: node visit counts, weighted transition edges,
entry/exit distributions, conversion rate, avg path length.
"""
from collections import Counter

def analyze_flow(journeys: list[dict]) -> dict:
    node_counts  = Counter()
    edge_counts  = Counter()
    entry_counts = Counter()
    exit_counts  = Counter()

    for j in journeys:
        path = j["path"]
        if not path:
            continue
        entry_counts[path[0]]  += 1
        exit_counts[path[-1]]  += 1
        for page in path:
            node_counts[page] += 1
        for i in range(len(path) - 1):
            edge_counts[(path[i], path[i + 1])] += 1

    total      = len(journeys)
    converted  = sum(1 for j in journeys if j["converted"])
    conv_rate  = round(converted / total * 100, 1) if total else 0.0
    avg_length = round(sum(len(j["path"]) for j in journeys) / total, 1) if total else 0.0

    nodes = [{"id": page, "count": cnt} for page, cnt in node_counts.most_common()]
    edges = [
        {"source": src, "target": tgt, "count": cnt}
        for (src, tgt), cnt in sorted(edge_counts.items(), key=lambda x: -x[1])
    ]

    return {
        "nodes":              nodes,
        "edges":              edges,
        "entry_points":       dict(entry_counts.most_common()),
        "exit_points":        dict(exit_counts.most_common()),
        "conversion_rate":    conv_rate,
        "total_sessions":     total,
        "converted_sessions": converted,
        "avg_path_length":    avg_length,
    }

if __name__ == "__main__":
    from session_extractor import extract_sessions
    from journey_builder   import build_journeys
    sessions = extract_sessions()
    journeys = build_journeys(sessions)
    flow     = analyze_flow(journeys)
    print(f"Sessions:        {flow['total_sessions']}")
    print(f"Conversions:     {flow['converted_sessions']}  ({flow['conversion_rate']}%)")
    print(f"Avg path length: {flow['avg_path_length']} steps")
    print("Top edges:")
    for e in flow["edges"][:6]:
        print(f"  {e['source']:20s} → {e['target']:20s}  [{e['count']}]")
