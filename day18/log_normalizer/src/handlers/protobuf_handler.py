"""Handler for Protobuf-formatted logs"""

from datetime import datetime
from .base import BaseHandler
from ..models.log_entry import LogEntry

try:
    from ..proto.log_entry_pb2 import LogEntryProto
    _PROTO_AVAILABLE = True
except ImportError:
    LogEntryProto = None
    _PROTO_AVAILABLE = False


class ProtobufHandler(BaseHandler):
    """Handler for Protobuf-serialized log entries"""

    def can_handle(self, raw_data: bytes) -> float:
        """Check if data looks like protobuf (binary, not valid JSON/text)."""
        if not _PROTO_AVAILABLE:
            return 0.0
        try:
            text = raw_data.decode("utf-8")
            if text.strip().startswith("{") or text.strip().startswith("[") or text.strip().startswith("<"):
                return 0.0
        except UnicodeDecodeError:
            pass
        if len(raw_data) < 2:
            return 0.0
        try:
            msg = LogEntryProto()
            msg.ParseFromString(raw_data)
            if msg.message or msg.level:
                return 0.85
        except Exception:
            pass
        return 0.4

    def parse(self, raw_data: bytes) -> LogEntry:
        """Parse Protobuf log entry into LogEntry."""
        if not _PROTO_AVAILABLE:
            raise RuntimeError(
                "Protobuf support requires generated proto; run: "
                "python -m grpc_tools.protoc -I src/proto --python_out=src/proto src/proto/log_entry.proto"
            )
        msg = LogEntryProto()
        msg.ParseFromString(raw_data)
        timestamp = self._parse_timestamp(msg.timestamp or "")
        return LogEntry(
            timestamp=timestamp,
            level=(msg.level or "INFO").upper(),
            message=msg.message or "",
            source=msg.source or "unknown",
            metadata={},
        )

    def _parse_timestamp(self, timestamp_str: str) -> datetime:
        if not timestamp_str:
            return datetime.now()
        try:
            return datetime.fromisoformat(timestamp_str.replace("Z", "+00:00"))
        except ValueError:
            return datetime.now()
