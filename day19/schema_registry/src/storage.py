from typing import Dict, Any, Optional
import json
import os
from datetime import datetime, UTC

class Storage:
    def __init__(self, storage_dir: str = "data"):
        self.storage_dir = storage_dir
        os.makedirs(storage_dir, exist_ok=True)
        
    def save_schema(self, subject: str, version: int, schema: Dict[str, Any]) -> None:
        """Save a schema version to storage."""
        schema_data = {
            'subject': subject,
            'version': version,
            'schema': schema,
            'registered_at': datetime.now(UTC).isoformat()
        }
        
        file_path = os.path.join(self.storage_dir, f"{subject}_v{version}.json")
        with open(file_path, 'w') as f:
            json.dump(schema_data, f, indent=2)
            
    def get_schema(self, subject: str, version: Optional[int] = None) -> Optional[Dict[str, Any]]:
        """Retrieve a schema version from storage."""
        if version is None:
            # Get latest version
            versions = [f for f in os.listdir(self.storage_dir) if f.startswith(f"{subject}_v")]
            if not versions:
                return None
            version = max(int(v.split('_v')[1].split('.')[0]) for v in versions)
            
        file_path = os.path.join(self.storage_dir, f"{subject}_v{version}.json")
        if not os.path.exists(file_path):
            return None
            
        with open(file_path, 'r') as f:
            return json.load(f)
            
    def list_subjects(self) -> list:
        """List all registered subjects."""
        subjects = set()
        for filename in os.listdir(self.storage_dir):
            if filename.endswith('.json'):
                subject = filename.split('_v')[0]
                subjects.add(subject)
        return sorted(list(subjects))
        
    def get_versions(self, subject: str) -> list:
        """Get all versions for a subject."""
        versions = []
        for filename in os.listdir(self.storage_dir):
            if filename.startswith(f"{subject}_v") and filename.endswith('.json'):
                version = int(filename.split('_v')[1].split('.')[0])
                versions.append(version)
        return sorted(versions)
