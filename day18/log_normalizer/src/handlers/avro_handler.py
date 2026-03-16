"""Handler for Avro-serialized log entries"""

import io
from datetime import datetime
from .base import BaseHandler
from ..models.log_entry import LogEntry

try:
    import avro.io
    import avro.schema
    _AVRO_AVAILABLE = True
except ImportError:
    _AVRO_AVAILABLE = False

# Minimal Avro schema for log entry (same shape as LogEntry)
LOG_ENTRY_AVRO_SCHEMA = """
{
  "type": "record",
  "name": "LogEntry",
  "fields": [
    {"name": "timestamp", "type": "string"},
    {"name": "level", "type": "string"},
    {"name": "message", "type": "string"},
    {"name": "source", "type": "string"}
  ]
}
"""


class AvroHandler(BaseHandler):
    """Handler for Avro-formatted log entries"""

    def __init__(self):
        self._schema = None
        if _AVRO_AVAILABLE:
            self._schema = avro.schema.parse(LOG_ENTRY_AVRO_SCHEMA)

    def can_handle(self, raw_data: bytes) -> float:
        """Check if data can be decoded as Avro with our log entry schema."""
        if not _AVRO_AVAILABLE or not raw_data:
            return 0.0
        try:
            text = raw_data.decode("utf-8")
            if text.strip().startswith("{") or text.strip().startswith("["):
                return 0.0
        except UnicodeDecodeError:
            pass
        try:
            decoder = avro.io.BinaryDecoder(io.BytesIO(raw_data))
            reader = avro.io.DatumReader(self._schema)
            record = reader.read(decoder)
            if record and isinstance(record.get("message"), str):
                return 0.85
        except Exception:
            pass
        return 0.4

    def parse(self, raw_data: bytes) -> LogEntry:
        """Parse Avro log entry into LogEntry."""
        if not _AVRO_AVAILABLE:
            raise RuntimeError(
                "Avro support requires avro-python3; pip install avro-python3"
            )
        decoder = avro.io.BinaryDecoder(io.BytesIO(raw_data))
        reader = avro.io.DatumReader(self._schema)
        record = reader.read(decoder)
        timestamp = self._parse_timestamp(record.get("timestamp") or "")
        return LogEntry(
            timestamp=timestamp,
            level=(record.get("level") or "INFO").upper(),
            message=record.get("message") or "",
            source=record.get("source") or "unknown",
            metadata={},
        )

    def _parse_timestamp(self, timestamp_str: str) -> datetime:
        if not timestamp_str:
            return datetime.now()
        try:
            return datetime.fromisoformat(
                timestamp_str.replace("Z", "+00:00")
            )
        except ValueError:
            return datetime.now()
