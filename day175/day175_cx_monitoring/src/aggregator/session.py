"""
SessionAggregator — stitches log events into user sessions.

Session closes when:
  • 30-minute idle gap detected (via min-heap expiry check)
  • explicit purchase event received (funnel completed)
"""
import heapq, time
from dataclasses import dataclass, field
from typing import Optional

FUNNEL_ORDER = {
    "page_view"      : 0,
    "add_to_cart"    : 1,
    "checkout_start" : 2,
    "purchase"       : 3,
}

@dataclass
class _Session:
    user_id    : str
    session_id : str
    start_ts   : float = field(default_factory=time.time)
    last_ts    : float = field(default_factory=time.time)
    latencies  : list  = field(default_factory=list)
    errors     : int   = 0
    max_stage  : int   = 0
    converted  : bool  = False

    def update(self, ev: dict):
        now = time.time()
        self.last_ts = now
        lms = ev.get("latency_ms", 0)
        if lms > 0:
            self.latencies.append(lms)
        if ev.get("status_code", 200) >= 500:
            self.errors += 1
        stage = FUNNEL_ORDER.get(ev.get("event_type", ""), 0)
        if stage > self.max_stage:
            self.max_stage = stage
        if ev.get("event_type") == "purchase":
            self.converted = True

@dataclass(order=True)
class _Expiry:
    expiry_ts  : float
    session_id : str = field(compare=False)
    user_id    : str = field(compare=False)

@dataclass
class SessionSummary:
    user_id         : str
    session_id      : str
    duration_sec    : float
    latencies_ms    : list
    error_count     : int
    max_funnel_stage: int   # 0-3
    converted       : bool

class SessionAggregator:
    def __init__(self, idle_timeout: int = 1800):
        self._timeout   = idle_timeout
        self._sessions  : dict[str, _Session] = {}
        self._heap      : list[_Expiry]        = []

    def ingest(self, ev: dict) -> Optional[SessionSummary]:
        uid = ev.get("user_id", "unknown")
        sid = ev.get("session_id", "unknown")

        # New or changed session
        if uid not in self._sessions or self._sessions[uid].session_id != sid:
            closed = self._close(uid)
            self._sessions[uid] = _Session(user_id=uid, session_id=sid)
            heapq.heappush(self._heap, _Expiry(time.time() + self._timeout, sid, uid))
            if closed:
                return closed

        sess = self._sessions[uid]
        sess.update(ev)

        if sess.converted:
            return self._close(uid)
        return None

    def flush_expired(self) -> list[SessionSummary]:
        now = time.time()
        out = []
        while self._heap and self._heap[0].expiry_ts <= now:
            exp = heapq.heappop(self._heap)
            if exp.user_id in self._sessions:
                s = self._sessions[exp.user_id]
                if s.session_id == exp.session_id:
                    sm = self._close(exp.user_id)
                    if sm: out.append(sm)
        return out

    def flush_all(self) -> list[SessionSummary]:
        out = []
        for uid in list(self._sessions.keys()):
            sm = self._close(uid)
            if sm: out.append(sm)
        return out

    def _close(self, uid: str) -> Optional[SessionSummary]:
        if uid not in self._sessions:
            return None
        s = self._sessions.pop(uid)
        return SessionSummary(
            user_id          = s.user_id,
            session_id       = s.session_id,
            duration_sec     = time.time() - s.start_ts,
            latencies_ms     = s.latencies,
            error_count      = s.errors,
            max_funnel_stage = s.max_stage,
            converted        = s.converted,
        )
