from typing import Dict, Any, Tuple, Optional, List
import jsonschema
from jsonschema import validate

class LogValidator:
    def __init__(self):
        self.schemas: Dict[str, Dict[str, Any]] = {}
        
    def register_schema(self, subject: str, schema: Dict[str, Any]) -> Tuple[int, str]:
        """Register a new schema version for a subject."""
        if subject not in self.schemas:
            self.schemas[subject] = {}
            
        # Generate version number
        version = len(self.schemas[subject]) + 1
        
        # Store schema
        self.schemas[subject][version] = schema
        
        return version, f"{subject}_v{version}"
        
    def get_schema(self, subject: str, version: Optional[int] = None) -> Optional[Dict[str, Any]]:
        """Get a schema version for a subject."""
        if subject not in self.schemas:
            return None
            
        if version is None:
            # Get latest version
            version = max(self.schemas[subject].keys())
            
        return self.schemas[subject].get(version)
        
    def validate_log(self, subject: str, log: Dict[str, Any], version: Optional[int] = None) -> bool:
        """Validate a log against a schema version."""
        schema = self.get_schema(subject, version)
        if not schema:
            return False
            
        try:
            validate(instance=log, schema=schema)
            return True
        except jsonschema.exceptions.ValidationError:
            return False
            
    def validate_batch(self, subject: str, logs: List[Dict[str, Any]], version: Optional[int] = None) -> Tuple[int, int]:
        """Validate a batch of logs against a schema version."""
        schema = self.get_schema(subject, version)
        if not schema:
            return 0, len(logs)
            
        valid_count = 0
        for log in logs:
            try:
                validate(instance=log, schema=schema)
                valid_count += 1
            except jsonschema.exceptions.ValidationError:
                continue
                
        return valid_count, len(logs)
