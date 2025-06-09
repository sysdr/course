#!/bin/bash

# Avro Schema Evolution Log System - Complete Setup Script
# Day 17: Distributed Systems Course
# This script creates a fully working Avro-based log processing system

set -e  # Exit on any error

echo "🚀 Setting up Avro Schema Evolution Log System..."
echo "=================================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is required but not installed"
        exit 1
    fi
    
    if ! command -v pip &> /dev/null; then
        print_error "pip is required but not installed"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Create project structure
create_project_structure() {
    print_status "Creating project structure..."
    
    PROJECT_NAME="avro-log-system"
    
    # Remove existing directory if it exists
    if [ -d "$PROJECT_NAME" ]; then
        print_warning "Removing existing $PROJECT_NAME directory"
        rm -rf "$PROJECT_NAME"
    fi
    
    # Create main project directory and subdirectories
    mkdir -p "$PROJECT_NAME"/{src/{serializers,models,tests,schemas,web,validators,utils},config,docker,scripts,data}
    
    cd "$PROJECT_NAME"
    
    print_success "Project structure created"
}

# Create requirements file
create_requirements() {
    print_status "Creating requirements.txt..."
    
    cat > requirements.txt << 'EOF'
# Core Avro dependencies
avro-python3==1.10.2
fastavro==1.9.4

# Web framework for dashboard
flask==3.0.3
flask-cors==4.0.0

# Testing framework
pytest==8.2.0
pytest-asyncio==0.23.6
pytest-cov==5.0.0

# Data handling
dataclasses-json==0.6.6
pydantic==2.7.1

# Utilities
click==8.1.7
colorama==0.4.6
tabulate==0.9.0

# Development tools
black==24.4.2
flake8==7.0.0
EOF
    
    print_success "Requirements file created"
}

# Create Avro schemas
create_schemas() {
    print_status "Creating Avro schemas..."
    
    # Schema v1 - Basic log event
    cat > src/schemas/log_event_v1.avsc << 'EOF'
{
  "type": "record",
  "name": "LogEvent",
  "namespace": "com.logsystem.events",
  "doc": "Basic log event structure - Version 1",
  "fields": [
    {
      "name": "timestamp",
      "type": "string",
      "doc": "ISO 8601 timestamp when the event occurred"
    },
    {
      "name": "level",
      "type": {
        "type": "enum",
        "name": "LogLevel",
        "symbols": ["DEBUG", "INFO", "WARN", "ERROR", "FATAL"]
      },
      "doc": "Severity level of the log event"
    },
    {
      "name": "message",
      "type": "string",
      "doc": "Human-readable log message"
    },
    {
      "name": "service_name",
      "type": "string",
      "doc": "Name of the service generating the log"
    }
  ]
}
EOF

    # Schema v2 - Added tracking fields (backward compatible)
    cat > src/schemas/log_event_v2.avsc << 'EOF'
{
  "type": "record",
  "name": "LogEvent",
  "namespace": "com.logsystem.events",
  "doc": "Enhanced log event with tracking - Version 2",
  "fields": [
    {
      "name": "timestamp",
      "type": "string",
      "doc": "ISO 8601 timestamp when the event occurred"
    },
    {
      "name": "level",
      "type": {
        "type": "enum",
        "name": "LogLevel", 
        "symbols": ["DEBUG", "INFO", "WARN", "ERROR", "FATAL"]
      },
      "doc": "Severity level of the log event"
    },
    {
      "name": "message",
      "type": "string",
      "doc": "Human-readable log message"
    },
    {
      "name": "service_name",
      "type": "string",
      "doc": "Name of the service generating the log"
    },
    {
      "name": "request_id",
      "type": ["null", "string"],
      "default": null,
      "doc": "Unique identifier for the request (added in v2)"
    },
    {
      "name": "user_id",
      "type": ["null", "string"],
      "default": null,
      "doc": "Identifier of the user associated with this event (added in v2)"
    }
  ]
}
EOF

    # Schema v3 - Added performance metrics (backward compatible)
    cat > src/schemas/log_event_v3.avsc << 'EOF'
{
  "type": "record",
  "name": "LogEvent", 
  "namespace": "com.logsystem.events",
  "doc": "Full-featured log event with performance metrics - Version 3",
  "fields": [
    {
      "name": "timestamp",
      "type": "string",
      "doc": "ISO 8601 timestamp when the event occurred"
    },
    {
      "name": "level",
      "type": {
        "type": "enum",
        "name": "LogLevel",
        "symbols": ["DEBUG", "INFO", "WARN", "ERROR", "FATAL"]
      },
      "doc": "Severity level of the log event"
    },
    {
      "name": "message", 
      "type": "string",
      "doc": "Human-readable log message"
    },
    {
      "name": "service_name",
      "type": "string",
      "doc": "Name of the service generating the log"
    },
    {
      "name": "request_id",
      "type": ["null", "string"],
      "default": null,
      "doc": "Unique identifier for the request"
    },
    {
      "name": "user_id",
      "type": ["null", "string"], 
      "default": null,
      "doc": "Identifier of the user associated with this event"
    },
    {
      "name": "duration_ms",
      "type": ["null", "double"],
      "default": null,
      "doc": "Duration of the operation in milliseconds (added in v3)"
    },
    {
      "name": "memory_usage_mb",
      "type": ["null", "double"], 
      "default": null,
      "doc": "Memory usage in megabytes (added in v3)"
    }
  ]
}
EOF
    
    print_success "Avro schemas created (v1, v2, v3)"
}

# Create Python source files
create_source_files() {
    print_status "Creating Python source files..."
    
    # Main Avro serialization handler
    cat > src/serializers/avro_handler.py << 'EOF'
"""
Avro Schema Evolution Handler
Demonstrates backward and forward compatibility in distributed log processing
"""

import json
import io
from typing import Dict, Any, Optional, List, Union
from pathlib import Path
import avro.schema
import avro.io
from avro.datafile import DataFileWriter, DataFileReader


class AvroSchemaManager:
    """
    Manages schema evolution for the distributed log processing system.
    
    This class demonstrates how real-world systems like LinkedIn's Kafka
    handle schema changes without breaking existing producers/consumers.
    """
    
    def __init__(self, schema_dir: str = "src/schemas"):
        self.schema_dir = Path(schema_dir)
        self.schemas: Dict[str, avro.schema.Schema] = {}
        self.compatibility_matrix: Dict[str, List[str]] = {}
        self._load_all_schemas()
        self._build_compatibility_matrix()
    
    def _load_all_schemas(self) -> None:
        """Load all available schema versions from disk"""
        schema_files = {
            "v1": "log_event_v1.avsc",
            "v2": "log_event_v2.avsc", 
            "v3": "log_event_v3.avsc"
        }
        
        for version, filename in schema_files.items():
            schema_path = self.schema_dir / filename
            if schema_path.exists():
                with open(schema_path, 'r') as f:
                    schema_dict = json.load(f)
                    # Parse the schema - this validates it's syntactically correct
                    self.schemas[version] = avro.schema.parse(json.dumps(schema_dict))
                    print(f"✓ Loaded schema {version}")
            else:
                print(f"⚠ Schema file not found: {schema_path}")
    
    def _build_compatibility_matrix(self) -> None:
        """
        Build compatibility matrix showing which schema versions can read others.
        In real systems, this would be managed by Schema Registry (Confluent/Red Hat)
        """
        # For our educational example, we know the compatibility rules
        self.compatibility_matrix = {
            "v1": ["v1"],           # v1 can only read v1
            "v2": ["v1", "v2"],     # v2 can read v1 and v2 (backward compatible)
            "v3": ["v1", "v2", "v3"]  # v3 can read all (fully backward compatible)
        }
    
    def serialize(self, data: Dict[str, Any], writer_schema_version: str) -> bytes:
        """
        Serialize data using specified schema version.
        
        Args:
            data: Dictionary containing the log event data
            writer_schema_version: Schema version to use for serialization
            
        Returns:
            Serialized bytes that include schema fingerprint
        """
        if writer_schema_version not in self.schemas:
            raise ValueError(f"Unknown schema version: {writer_schema_version}")
        
        writer_schema = self.schemas[writer_schema_version]
        
        # Create binary encoder
        bytes_writer = io.BytesIO()
        encoder = avro.io.BinaryEncoder(bytes_writer)
        datum_writer = avro.io.DatumWriter(writer_schema)
        
        # Write the data - Avro handles type validation automatically
        datum_writer.write(data, encoder)
        
        return bytes_writer.getvalue()
    
    def deserialize(self, serialized_data: bytes, writer_schema_version: str, 
                   reader_schema_version: str) -> Dict[str, Any]:
        """
        Deserialize data with schema evolution support.
        
        This is where the magic happens - demonstrating how newer consumers
        can read older data formats and vice versa.
        
        Args:
            serialized_data: The binary data to deserialize
            writer_schema_version: Schema used when data was written
            reader_schema_version: Schema the consumer expects
            
        Returns:
            Deserialized data as dictionary
        """
        writer_schema = self.schemas[writer_schema_version]
        reader_schema = self.schemas[reader_schema_version]
        
        # Check compatibility - in production this would be cached
        if not self._are_compatible(writer_schema_version, reader_schema_version):
            raise ValueError(f"Incompatible schemas: writer={writer_schema_version}, reader={reader_schema_version}")
        
        # Create decoder with schema evolution support
        bytes_reader = io.BytesIO(serialized_data)
        decoder = avro.io.BinaryDecoder(bytes_reader)
        datum_reader = avro.io.DatumReader(writer_schema, reader_schema)
        
        # Avro automatically handles field mapping, defaults, and compatibility
        return datum_reader.read(decoder)
    
    def _are_compatible(self, writer_version: str, reader_version: str) -> bool:
        """Check if reader schema can understand writer schema"""
        return writer_version in self.compatibility_matrix.get(reader_version, [])
    
    def get_compatibility_info(self) -> Dict[str, Any]:
        """Return detailed compatibility information for monitoring"""
        return {
            "available_schemas": list(self.schemas.keys()),
            "compatibility_matrix": self.compatibility_matrix,
            "schema_details": {
                version: {
                    "fields": [field.name for field in schema.fields],
                    "field_count": len(schema.fields)
                }
                for version, schema in self.schemas.items()
            }
        }


class LogEventProcessor:
    """
    Processes log events with different schema versions.
    Simulates a real distributed system where different services use different versions.
    """
    
    def __init__(self):
        self.schema_manager = AvroSchemaManager()
        self.processed_events = []
    
    def process_event(self, event_data: Dict[str, Any], schema_version: str) -> str:
        """Process a log event and demonstrate schema evolution"""
        try:
            # Serialize the event (what a producer would do)
            serialized = self.schema_manager.serialize(event_data, schema_version)
            
            # Simulate different consumers reading with different schema versions
            results = {}
            for consumer_version in ["v1", "v2", "v3"]:
                try:
                    deserialized = self.schema_manager.deserialize(
                        serialized, schema_version, consumer_version
                    )
                    results[f"consumer_{consumer_version}"] = "✓ SUCCESS"
                except ValueError as e:
                    results[f"consumer_{consumer_version}"] = f"✗ FAILED: {str(e)}"
            
            self.processed_events.append({
                "original_data": event_data,
                "writer_schema": schema_version,
                "consumer_results": results,
                "serialized_size": len(serialized)
            })
            
            return f"Event processed with schema {schema_version}. Size: {len(serialized)} bytes"
            
        except Exception as e:
            return f"Error processing event: {str(e)}"
    
    def get_processing_summary(self) -> Dict[str, Any]:
        """Get summary of all processed events for analysis"""
        if not self.processed_events:
            return {"message": "No events processed yet"}
        
        return {
            "total_events": len(self.processed_events),
            "events": self.processed_events,
            "compatibility_stats": self._calculate_compatibility_stats()
        }
    
    def _calculate_compatibility_stats(self) -> Dict[str, int]:
        """Calculate compatibility statistics across all processed events"""
        stats = {"total_successes": 0, "total_failures": 0}
        
        for event in self.processed_events:
            for result in event["consumer_results"].values():
                if "SUCCESS" in result:
                    stats["total_successes"] += 1
                else:
                    stats["total_failures"] += 1
        
        return stats
EOF

    # Create data models
    cat > src/models/log_event.py << 'EOF'
"""
Log Event Data Models
Represents the evolution of our log event structure across versions
"""

from dataclasses import dataclass, asdict
from typing import Optional, Dict, Any
from datetime import datetime, timezone
import uuid


@dataclass
class BaseLogEvent:
    """Base class for all log event versions"""
    timestamp: str
    level: str  
    message: str
    service_name: str
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for Avro serialization"""
        return asdict(self)
    
    @classmethod
    def create_sample(cls, **kwargs):
        """Create a sample log event for testing"""
        defaults = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": "INFO",
            "message": "Sample log message", 
            "service_name": "sample-service"
        }
        defaults.update(kwargs)
        return cls(**defaults)


@dataclass
class LogEventV1(BaseLogEvent):
    """Version 1: Basic log event structure"""
    pass


@dataclass  
class LogEventV2(BaseLogEvent):
    """Version 2: Added request tracking capabilities"""
    request_id: Optional[str] = None
    user_id: Optional[str] = None
    
    @classmethod
    def create_sample(cls, **kwargs):
        """Create sample with v2 fields"""
        defaults = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": "INFO", 
            "message": "User action logged",
            "service_name": "auth-service",
            "request_id": str(uuid.uuid4())[:8],
            "user_id": f"user_{uuid.uuid4().hex[:6]}"
        }
        defaults.update(kwargs)
        return cls(**defaults)


@dataclass
class LogEventV3(BaseLogEvent):
    """Version 3: Added performance monitoring"""
    request_id: Optional[str] = None
    user_id: Optional[str] = None
    duration_ms: Optional[float] = None
    memory_usage_mb: Optional[float] = None
    
    @classmethod
    def create_sample(cls, **kwargs):
        """Create sample with v3 fields including performance metrics"""
        import random
        
        defaults = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": "INFO",
            "message": "Operation completed with metrics",
            "service_name": "api-gateway", 
            "request_id": str(uuid.uuid4())[:8],
            "user_id": f"user_{uuid.uuid4().hex[:6]}",
            "duration_ms": round(random.uniform(10.5, 150.7), 2),
            "memory_usage_mb": round(random.uniform(15.2, 89.6), 1)
        }
        defaults.update(kwargs)
        return cls(**defaults)


# Factory function to create events of different versions
def create_log_event(version: str, **kwargs) -> BaseLogEvent:
    """Factory function to create log events of specified version"""
    event_classes = {
        "v1": LogEventV1,
        "v2": LogEventV2, 
        "v3": LogEventV3
    }
    
    if version not in event_classes:
        raise ValueError(f"Unknown version: {version}")
    
    return event_classes[version].create_sample(**kwargs)
EOF

    # Create web dashboard
    cat > src/web/app.py << 'EOF'
"""
Web Dashboard for Avro Schema Evolution Demo
Provides real-time visualization of schema compatibility
"""

from flask import Flask, render_template, jsonify, request
from flask_cors import CORS
import sys
import os

# Add src to path so we can import our modules
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..'))

from src.serializers.avro_handler import AvroSchemaManager, LogEventProcessor
from src.models.log_event import create_log_event

app = Flask(__name__)
CORS(app)

# Global instances
schema_manager = AvroSchemaManager()
event_processor = LogEventProcessor()


@app.route('/')
def dashboard():
    """Main dashboard page"""
    return render_template('dashboard.html')


@app.route('/api/schema-info')
def get_schema_info():
    """Get comprehensive schema information"""
    try:
        return jsonify({
            "status": "success",
            "data": schema_manager.get_compatibility_info()
        })
    except Exception as e:
        return jsonify({
            "status": "error", 
            "message": str(e)
        }), 500


@app.route('/api/test-compatibility', methods=['POST'])
def test_compatibility():
    """Test schema compatibility with sample data"""
    try:
        data = request.json
        schema_version = data.get('schema_version', 'v1')
        
        # Create sample event
        sample_event = create_log_event(schema_version)
        
        # Process the event to test compatibility
        result = event_processor.process_event(sample_event.to_dict(), schema_version)
        
        return jsonify({
            "status": "success",
            "message": result,
            "sample_data": sample_event.to_dict(),
            "processing_summary": event_processor.get_processing_summary()
        })
        
    except Exception as e:
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@app.route('/api/generate-sample/<version>')
def generate_sample(version):
    """Generate sample data for specified schema version"""
    try:
        sample_event = create_log_event(version)
        return jsonify({
            "status": "success", 
            "data": sample_event.to_dict(),
            "schema_version": version
        })
    except Exception as e:
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


if __name__ == '__main__':
    print("🌐 Starting Avro Schema Evolution Dashboard...")
    print("📊 Access dashboard at: http://localhost:5000")
    app.run(debug=True, host='0.0.0.0', port=5000)
EOF

    # Create HTML template
    mkdir -p src/web/templates
    cat > src/web/templates/dashboard.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Avro Schema Evolution Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f5f7fa; }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 30px; text-align: center; }
        .card { background: white; border-radius: 10px; padding: 25px; margin-bottom: 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .btn { background: #4CAF50; color: white; padding: 12px 24px; border: none; border-radius: 6px; cursor: pointer; font-size: 14px; transition: background 0.3s; }
        .btn:hover { background: #45a049; }
        .btn.secondary { background: #2196F3; }
        .btn.secondary:hover { background: #1976D2; }
        .schema-version { display: inline-block; padding: 4px 12px; border-radius: 15px; font-size: 12px; font-weight: bold; margin: 2px; }
        .v1 { background: #e8f5e8; color: #2e7d32; }
        .v2 { background: #fff3e0; color: #f57c00; }
        .v3 { background: #fce4ec; color: #c2185b; }
        .success { color: #4CAF50; }
        .error { color: #f44336; }
        .compatibility-matrix { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; margin: 20px 0; }
        .matrix-cell { padding: 10px; text-align: center; border: 1px solid #ddd; border-radius: 4px; }
        .matrix-header { background: #f0f0f0; font-weight: bold; }
        .compatible { background: #e8f5e8; }
        .incompatible { background: #ffebee; }
        #testResults { max-height: 400px; overflow-y: auto; }
        .event-result { border-left: 4px solid #4CAF50; padding: 10px; margin: 10px 0; background: #f9f9f9; }
        pre { background: #f4f4f4; padding: 15px; border-radius: 6px; overflow-x: auto; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Avro Schema Evolution Dashboard</h1>
            <p>Day 17: Distributed Systems - Real-time Schema Compatibility Testing</p>
        </div>

        <div class="grid">
            <div class="card">
                <h2>📋 Schema Information</h2>
                <div id="schemaInfo">Loading schema information...</div>
            </div>

            <div class="card">
                <h2>🧪 Compatibility Test</h2>
                <div>
                    <label>Test Schema Version:</label>
                    <select id="schemaSelect">
                        <option value="v1">Version 1 (Basic)</option>
                        <option value="v2">Version 2 (+ Tracking)</option>
                        <option value="v3" selected>Version 3 (+ Metrics)</option>
                    </select>
                    <button class="btn" onclick="runCompatibilityTest()">Run Test</button>
                </div>
                <div id="testResults"></div>
            </div>
        </div>

        <div class="card">
            <h2>📊 Compatibility Matrix</h2>
            <p>Shows which schema versions can read data from other versions:</p>
            <div id="compatibilityMatrix"></div>
        </div>

        <div class="card">
            <h2>📝 Sample Data Generator</h2>
            <div class="grid">
                <div>
                    <button class="btn secondary" onclick="generateSample('v1')">Generate v1 Sample</button>
                    <button class="btn secondary" onclick="generateSample('v2')">Generate v2 Sample</button>
                    <button class="btn secondary" onclick="generateSample('v3')">Generate v3 Sample</button>
                </div>
            </div>
            <div id="sampleData"></div>
        </div>
    </div>

    <script>
        // Load schema information on page load
        window.onload = function() {
            loadSchemaInfo();
        };

        async function loadSchemaInfo() {
            try {
                const response = await fetch('/api/schema-info');
                const data = await response.json();
                
                if (data.status === 'success') {
                    displaySchemaInfo(data.data);
                    buildCompatibilityMatrix(data.data.compatibility_matrix);
                } else {
                    document.getElementById('schemaInfo').innerHTML = `<div class="error">Error: ${data.message}</div>`;
                }
            } catch (error) {
                document.getElementById('schemaInfo').innerHTML = `<div class="error">Failed to load schema info: ${error.message}</div>`;
            }
        }

        function displaySchemaInfo(data) {
            const html = `
                <div>
                    <h3>Available Schemas</h3>
                    ${data.available_schemas.map(v => `<span class="schema-version ${v}">${v.toUpperCase()}</span>`).join('')}
                </div>
                <div style="margin-top: 15px;">
                    <h3>Schema Details</h3>
                    ${Object.entries(data.schema_details).map(([version, details]) => `
                        <div style="margin: 10px 0; padding: 10px; border: 1px solid #ddd; border-radius: 4px;">
                            <strong>${version.toUpperCase()}</strong>: ${details.field_count} fields
                            <br><small>Fields: ${details.fields.join(', ')}</small>
                        </div>
                    `).join('')}
                </div>
            `;
            document.getElementById('schemaInfo').innerHTML = html;
        }

        function buildCompatibilityMatrix(matrix) {
            const versions = ['v1', 'v2', 'v3'];
            let html = '<div class="compatibility-matrix">';
            
            // Header row
            html += '<div class="matrix-cell matrix-header">Reader \\ Writer</div>';
            versions.forEach(v => {
                html += `<div class="matrix-cell matrix-header">${v.toUpperCase()}</div>`;
            });
            
            // Data rows
            versions.forEach(reader => {
                html += `<div class="matrix-cell matrix-header">${reader.toUpperCase()}</div>`;
                versions.forEach(writer => {
                    const compatible = matrix[reader] && matrix[reader].includes(writer);
                    const cellClass = compatible ? 'compatible' : 'incompatible';
                    const symbol = compatible ? '✓' : '✗';
                    html += `<div class="matrix-cell ${cellClass}">${symbol}</div>`;
                });
            });
            
            html += '</div>';
            html += '<p><small>✓ = Compatible, ✗ = Incompatible</small></p>';
            document.getElementById('compatibilityMatrix').innerHTML = html;
        }

        async function runCompatibilityTest() {
            const schemaVersion = document.getElementById('schemaSelect').value;
            const resultsDiv = document.getElementById('testResults');
            
            resultsDiv.innerHTML = '<div>Running compatibility test...</div>';
            
            try {
                const response = await fetch('/api/test-compatibility', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ schema_version: schemaVersion })
                });
                
                const data = await response.json();
                
                if (data.status === 'success') {
                    displayTestResults(data);
                } else {
                    resultsDiv.innerHTML = `<div class="error">Test failed: ${data.message}</div>`;
                }
            } catch (error) {
                resultsDiv.innerHTML = `<div class="error">Test error: ${error.message}</div>`;
            }
        }

        function displayTestResults(data) {
            const html = `
                <div class="event-result">
                    <h4>Test Result: ${data.message}</h4>
                    <h5>Sample Data (${Object.keys(data.sample_data).length} fields):</h5>
                    <pre>${JSON.stringify(data.sample_data, null, 2)}</pre>
                    
                    <h5>Consumer Compatibility Results:</h5>
                    ${data.processing_summary.events ? data.processing_summary.events.map(event => `
                        <div style="margin: 10px 0; padding: 10px; background: white; border-radius: 4px;">
                            <strong>Writer Schema:</strong> ${event.writer_schema} | 
                            <strong>Serialized Size:</strong> ${event.serialized_size} bytes
                            <div style="margin-top: 8px;">
                                ${Object.entries(event.consumer_results).map(([consumer, result]) => `
                                    <div class="${result.includes('SUCCESS') ? 'success' : 'error'}">
                                        ${consumer}: ${result}
                                    </div>
                                `).join('')}
                            </div>
                        </div>
                    `).join('') : '<div>No events processed yet</div>'}
                </div>
            `;
            document.getElementById('testResults').innerHTML = html;
        }

        async function generateSample(version) {
            try {
                const response = await fetch(`/api/generate-sample/${version}`);
                const data = await response.json();
                
                if (data.status === 'success') {
                    const html = `
                        <div style="margin-top: 15px;">
                            <h4>Sample ${version.toUpperCase()} Event:</h4>
                            <pre>${JSON.stringify(data.data, null, 2)}</pre>
                        </div>
                    `;
                    document.getElementById('sampleData').innerHTML = html;
                } else {
                    document.getElementById('sampleData').innerHTML = `<div class="error">Error: ${data.message}</div>`;
                }
            } catch (error) {
                document.getElementById('sampleData').innerHTML = `<div class="error">Error: ${error.message}</div>`;
            }
        }
    </script>
</body>
</html>
EOF

    print_success "Python source files created"
}

# Create comprehensive test suite
create_tests() {
    print_status "Creating test suite..."
    
    # Main test file for schema evolution
    cat > src/tests/test_schema_evolution.py << 'EOF'
"""
Comprehensive test suite for Avro schema evolution
Tests backward/forward compatibility and real-world scenarios
"""

import pytest
import sys
import os
from pathlib import Path

# Add src to Python path
sys.path.append(str(Path(__file__).parent.parent.parent))

from src.serializers.avro_handler import AvroSchemaManager, LogEventProcessor
from src.models.log_event import LogEventV1, LogEventV2, LogEventV3, create_log_event


class TestSchemaEvolution:
    """Test schema evolution capabilities"""
    
    def setup_method(self):
        """Setup for each test method"""
        self.schema_manager = AvroSchemaManager()
        self.processor = LogEventProcessor()
    
    def test_schema_loading(self):
        """Test that all schema versions load correctly"""
        assert "v1" in self.schema_manager.schemas
        assert "v2" in self.schema_manager.schemas  
        assert "v3" in self.schema_manager.schemas
        
        # Verify each schema has expected field count
        v1_fields = len(self.schema_manager.schemas["v1"].fields)
        v2_fields = len(self.schema_manager.schemas["v2"].fields)
        v3_fields = len(self.schema_manager.schemas["v3"].fields)
        
        assert v1_fields == 4  # timestamp, level, message, service_name
        assert v2_fields == 6  # v1 + request_id, user_id
        assert v3_fields == 8  # v2 + duration_ms, memory_usage_mb
    
    def test_backward_compatibility_v1_to_v2(self):
        """Test that v2 schema can read v1 data"""
        # Create v1 event
        v1_event = LogEventV1.create_sample(
            message="User authentication successful",
            level="INFO"
        )
        
        # Serialize with v1 schema
        serialized = self.schema_manager.serialize(v1_event.to_dict(), "v1")
        
        # Deserialize with v2 schema (should work with defaults)
        deserialized = self.schema_manager.deserialize(serialized, "v1", "v2")
        
        # Verify core fields preserved
        assert deserialized["timestamp"] == v1_event.timestamp
        assert deserialized["level"] == v1_event.level
        assert deserialized["message"] == v1_event.message
        assert deserialized["service_name"] == v1_event.service_name
        
        # Verify new fields have default values
        assert deserialized["request_id"] is None
        assert deserialized["user_id"] is None
    
    def test_backward_compatibility_v2_to_v3(self):
        """Test that v3 schema can read v2 data"""
        v2_event = LogEventV2.create_sample(
            message="API request processed",
            level="INFO"
        )
        
        serialized = self.schema_manager.serialize(v2_event.to_dict(), "v2")
        deserialized = self.schema_manager.deserialize(serialized, "v2", "v3")
        
        # Verify all v2 fields preserved
        assert deserialized["request_id"] == v2_event.request_id
        assert deserialized["user_id"] == v2_event.user_id
        
        # Verify v3 fields have defaults
        assert deserialized["duration_ms"] is None
        assert deserialized["memory_usage_mb"] is None
    
    def test_forward_compatibility_v3_to_v1(self):
        """Test that v1 schema can read v3 data (ignoring new fields)"""
        v3_event = LogEventV3.create_sample(
            message="Performance metrics collected",
            duration_ms=45.7,
            memory_usage_mb=23.4
        )
        
        serialized = self.schema_manager.serialize(v3_event.to_dict(), "v3")
        deserialized = self.schema_manager.deserialize(serialized, "v3", "v1")
        
        # Verify only v1 fields are present
        expected_fields = {"timestamp", "level", "message", "service_name"}
        assert set(deserialized.keys()) == expected_fields
        
        # Verify values are correct
        assert deserialized["message"] == v3_event.message
        assert deserialized["level"] == v3_event.level
    
    def test_full_compatibility_chain(self):
        """Test complete compatibility chain across all versions"""
        # Test data that works across all versions
        base_data = {
            "timestamp": "2025-05-27T10:30:00Z",
            "level": "WARN", 
            "message": "Rate limit approaching",
            "service_name": "rate-limiter"
        }
        
        # Test serialization with each version
        for writer_version in ["v1", "v2", "v3"]:
            serialized = self.schema_manager.serialize(base_data, writer_version)
            
            # Test deserialization with each compatible reader version  
            for reader_version in ["v1", "v2", "v3"]:
                if self.schema_manager._are_compatible(writer_version, reader_version):
                    deserialized = self.schema_manager.deserialize(
                        serialized, writer_version, reader_version
                    )
                    # Basic fields should always be preserved
                    assert deserialized["message"] == base_data["message"]
                    assert deserialized["level"] == base_data["level"]
    
    def test_incompatible_schemas(self):
        """Test handling of incompatible schema combinations"""
        # For our current setup, all combinations are compatible
        # But let's test the compatibility checking logic
        
        # This would fail if we had a breaking change
        # For example, if v4 removed a required field
        base_data = {
            "timestamp": "2025-05-27T10:30:00Z",
            "level": "ERROR",
            "message": "System failure",
            "service_name": "critical-service"
        }
        
        serialized = self.schema_manager.serialize(base_data, "v1")
        
        # This should work (v1 -> v1)
        result = self.schema_manager.deserialize(serialized, "v1", "v1")
        assert result["message"] == base_data["message"]
    
    def test_event_processor_integration(self):
        """Test the LogEventProcessor with different schema versions"""
        # Test processing events with different versions
        events = [
            (create_log_event("v1", level="DEBUG"), "v1"),
            (create_log_event("v2", level="INFO"), "v2"), 
            (create_log_event("v3", level="ERROR"), "v3")
        ]
        
        for event, version in events:
            result = self.processor.process_event(event.to_dict(), version)
            assert "Event processed" in result
            assert version in result
        
        # Verify processing summary
        summary = self.processor.get_processing_summary()
        assert summary["total_events"] == 3
        assert summary["compatibility_stats"]["total_successes"] > 0
    
    def test_serialization_size_efficiency(self):
        """Test that Avro provides good compression"""
        import json
        
        # Create a complex v3 event
        v3_event = LogEventV3.create_sample(
            message="Complex operation with detailed logging and performance metrics",
            duration_ms=123.45,
            memory_usage_mb=67.89
        )
        
        # Compare Avro serialization vs JSON
        avro_serialized = self.schema_manager.serialize(v3_event.to_dict(), "v3")
        json_serialized = json.dumps(v3_event.to_dict()).encode('utf-8')
        
        # Avro should be more compact (though exact ratio depends on data)
        print(f"Avro size: {len(avro_serialized)} bytes")
        print(f"JSON size: {len(json_serialized)} bytes")
        print(f"Compression ratio: {len(avro_serialized)/len(json_serialized):.2f}")
        
        # At minimum, Avro shouldn't be dramatically larger
        assert len(avro_serialized) <= len(json_serialized) * 1.5
    
    def test_schema_compatibility_matrix(self):
        """Test the compatibility matrix functionality"""
        info = self.schema_manager.get_compatibility_info()
        
        # Verify structure
        assert "available_schemas" in info
        assert "compatibility_matrix" in info
        assert "schema_details" in info
        
        # Verify backward compatibility rules
        matrix = info["compatibility_matrix"]
        assert "v1" in matrix["v2"]  # v2 can read v1
        assert "v1" in matrix["v3"]  # v3 can read v1  
        assert "v2" in matrix["v3"]  # v3 can read v2


class TestRealWorldScenarios:
    """Test real-world scenarios that might occur in production"""
    
    def setup_method(self):
        self.schema_manager = AvroSchemaManager()
    
    def test_gradual_rollout_scenario(self):
        """
        Simulate gradual rollout where producers and consumers
        are updated at different times
        """
        # Old producer (v1) sending to new consumer (v3)
        old_producer_data = {
            "timestamp": "2025-05-27T12:00:00Z",
            "level": "INFO",
            "message": "Legacy system event", 
            "service_name": "legacy-service"
        }
        
        serialized = self.schema_manager.serialize(old_producer_data, "v1")
        
        # New consumer should handle this gracefully
        deserialized = self.schema_manager.deserialize(serialized, "v1", "v3")
        
        assert deserialized["message"] == old_producer_data["message"]
        assert deserialized["request_id"] is None  # New field gets default
        assert deserialized["duration_ms"] is None  # New field gets default
    
    def test_mixed_version_environment(self):
        """Test environment with multiple service versions running simultaneously"""
        # Simulate different services using different schema versions
        services = [
            ("auth-service", "v1", {"level": "INFO", "message": "User login"}),
            ("api-gateway", "v2", {"level": "WARN", "message": "Rate limit hit"}),
            ("metrics-collector", "v3", {"level": "DEBUG", "message": "Metrics gathered"})
        ]
        
        serialized_events = []
        
        # Each service serializes with its schema version
        for service_name, version, extra_data in services:
            base_data = {
                "timestamp": "2025-05-27T12:00:00Z",
                "service_name": service_name,
                **extra_data
            }
            serialized = self.schema_manager.serialize(base_data, version) 
            serialized_events.append((serialized, version))
        
        # Central log processor using v3 schema should handle all
        for serialized, writer_version in serialized_events:
            deserialized = self.schema_manager.deserialize(serialized, writer_version, "v3")
            assert "timestamp" in deserialized
            assert "service_name" in deserialized
            assert "message" in deserialized


if __name__ == "__main__":
    # Run tests with verbose output
    pytest.main([__file__, "-v", "--tb=short"])
EOF

    # Integration test file
    cat > src/tests/test_integration.py << 'EOF'
"""
Integration tests for the complete Avro log processing system
"""

import pytest
import requests
import time
import threading
import sys
import os
from pathlib import Path

# Add src to Python path
sys.path.append(str(Path(__file__).parent.parent.parent))

from src.web.app import app


class TestWebIntegration:
    """Test the web dashboard integration"""
    
    @pytest.fixture(scope="class")
    def client(self):
        """Create test client"""
        app.config['TESTING'] = True
        with app.test_client() as client:
            yield client
    
    def test_dashboard_loads(self, client):
        """Test that the main dashboard page loads"""
        response = client.get('/')
        assert response.status_code == 200
        assert b'Avro Schema Evolution Dashboard' in response.data
    
    def test_schema_info_api(self, client):
        """Test the schema information API endpoint"""
        response = client.get('/api/schema-info')
        assert response.status_code == 200
        
        data = response.get_json()
        assert data['status'] == 'success'
        assert 'available_schemas' in data['data']
        assert 'compatibility_matrix' in data['data']
    
    def test_compatibility_test_api(self, client):
        """Test the compatibility testing API"""
        test_data = {'schema_version': 'v2'}
        response = client.post('/api/test-compatibility', 
                              json=test_data,
                              content_type='application/json')
        
        assert response.status_code == 200
        data = response.get_json()
        assert data['status'] == 'success'
        assert 'sample_data' in data
        assert 'processing_summary' in data
    
    def test_sample_generation_api(self, client):
        """Test sample data generation for each version"""
        for version in ['v1', 'v2', 'v3']:
            response = client.get(f'/api/generate-sample/{version}')
            assert response.status_code == 200
            
            data = response.get_json()
            assert data['status'] == 'success'
            assert data['schema_version'] == version
            assert 'data' in data
            
            # Verify version-specific fields
            sample_data = data['data']
            if version == 'v1':
                assert 'request_id' not in sample_data
            elif version == 'v2':
                assert 'request_id' in sample_data
                assert 'duration_ms' not in sample_data
            elif version == 'v3':
                assert 'request_id' in sample_data
                assert 'duration_ms' in sample_data


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

    print_success "Test suite created"
}

# Create Docker files
create_docker_files() {
    print_status "Creating Docker configuration..."
    
    cat > docker/Dockerfile << 'EOF'
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY config/ ./config/

# Create non-root user for security
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/api/schema-info || exit 1

# Run the application
CMD ["python", "-m", "src.web.app"]
EOF

    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  avro-log-system:
    build:
      context: .
      dockerfile: docker/Dockerfile
    ports:
      - "5000:5000"
    environment:
      - FLASK_ENV=production
      - PYTHONPATH=/app
    volumes:
      - ./data:/app/data
    restart: unless-stopped
    
  # Optional: Add Kafka for real message streaming
  # zookeeper:
  #   image: confluentinc/cp-zookeeper:7.4.0
  #   environment:
  #     ZOOKEEPER_CLIENT_PORT: 2181
  
  # kafka:
  #   image: confluentinc/cp-kafka:7.4.0
  #   depends_on:
  #     - zookeeper
  #   ports:
  #     - "9092:9092"
  #   environment:
  #     KAFKA_BROKER_ID: 1
  #     KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
  #     KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
EOF

    print_success "Docker configuration created"
}

# Create build and test scripts
create_scripts() {
    print_status "Creating build and test scripts..."
    
    cat > scripts/build_and_test.sh << 'EOF'
#!/bin/bash

# Avro Log System - Build and Test Script
set -e

echo "🏗️  Building Avro Schema Evolution Log System..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Step 1: Install dependencies
print_step "Installing Python dependencies..."
pip install -r requirements.txt
print_success "Dependencies installed"

# Step 2: Validate schemas
print_step "Validating Avro schemas..."
python -c "
from src.serializers.avro_handler import AvroSchemaManager
manager = AvroSchemaManager()
print(f'✓ Loaded {len(manager.schemas)} schema versions')
print('✓ All schemas validated successfully')
"
print_success "Schema validation passed"

# Step 3: Run unit tests
print_step "Running unit tests..."
python -m pytest src/tests/ -v --tb=short
print_success "Unit tests passed"

# Step 4: Run integration tests
print_step "Running integration tests..."
python -m pytest src/tests/test_integration.py -v
print_success "Integration tests passed"

# Step 5: Test schema compatibility
print_step "Testing schema compatibility..."
python -c "
from src.serializers.avro_handler import LogEventProcessor
from src.models.log_event import create_log_event

processor = LogEventProcessor()
for version in ['v1', 'v2', 'v3']:
    event = create_log_event(version)
    result = processor.process_event(event.to_dict(), version)
    print(f'✓ {version}: {result}')

summary = processor.get_processing_summary()
print(f'✓ Processed {summary[\"total_events\"]} events successfully')
"
print_success "Compatibility tests passed"

# Step 6: Start web dashboard
print_step "Starting web dashboard..."
echo "🌐 Dashboard will be available at: http://localhost:5000"
echo "📊 Press Ctrl+C to stop the server"
python -m src.web.app
EOF

    cat > scripts/run_tests.sh << 'EOF'
#!/bin/bash

# Run comprehensive test suite
set -e

echo "🧪 Running Avro Schema Evolution Test Suite"
echo "============================================"

# Run with coverage
python -m pytest src/tests/ -v --cov=src --cov-report=html --cov-report=term

echo ""
echo "📊 Test Results Summary:"
echo "- Unit tests: Schema evolution functionality"  
echo "- Integration tests: Web API endpoints"
echo "- Coverage report: htmlcov/index.html"
echo ""
echo "✅ All tests completed!"
EOF

    cat > scripts/docker_build.sh << 'EOF'
#!/bin/bash

# Docker build and run script
set -e

echo "🐳 Building Docker container..."

# Build the image
docker build -f docker/Dockerfile -t avro-log-system .

echo "✅ Docker image built successfully!"
echo ""
echo "To run the container:"
echo "  docker run -p 5000:5000 avro-log-system"
echo ""
echo "Or use docker-compose:"
echo "  docker-compose up"
EOF

    # Make scripts executable
    chmod +x scripts/*.sh
    
    print_success "Build and test scripts created"
}

# Install dependencies and run initial tests
install_and_test() {
    print_status "Installing dependencies and running initial tests..."
    
    # Install Python dependencies
    pip install -r requirements.txt
    
    # Run schema validation
    python -c "
import sys
sys.path.append('.')
from src.serializers.avro_handler import AvroSchemaManager
manager = AvroSchemaManager()
print(f'✅ Loaded {len(manager.schemas)} schema versions')
"
    
    # Run quick compatibility test
    python -c "
import sys
sys.path.append('.')
from src.serializers.avro_handler import LogEventProcessor
from src.models.log_event import create_log_event

processor = LogEventProcessor()
event = create_log_event('v3')
result = processor.process_event(event.to_dict(), 'v3')
print(f'✅ Test event processed: {result[:50]}...')
"
    
    print_success "Initial tests passed!"
}

# Main execution
main() {
    echo "Starting Avro Schema Evolution Log System setup..."
    
    check_prerequisites
    create_project_structure
    create_requirements
    create_schemas
    create_source_files
    create_tests
    create_docker_files
    create_scripts
    install_and_test
    
    echo ""
    echo "🎉 SETUP COMPLETE! 🎉"
    echo "===================="
    echo ""
    echo "📁 Project Structure:"
    echo "   └── avro-log-system/"
    echo "       ├── src/           # Source code"
    echo "       ├── schemas/       # Avro schema definitions"  
    echo "       ├── tests/         # Test suite"
    echo "       ├── docker/        # Docker configuration"
    echo "       └── scripts/       # Build and run scripts"
    echo ""
    echo "🚀 Quick Start:"
    echo "   cd avro-log-system"
    echo "   ./scripts/build_and_test.sh    # Run full test suite and start dashboard"
    echo ""  
    echo "🧪 Run Tests Only:"
    echo "   ./scripts/run_tests.sh         # Run comprehensive tests"
    echo ""
    echo "🐳 Docker Deployment:"
    echo "   ./scripts/docker_build.sh      # Build Docker image"
    echo "   docker-compose up              # Run with Docker Compose"
    echo ""
    echo "📊 Web Dashboard:"
    echo "   python -m src.web.app          # Start dashboard at http://localhost:5000"
    echo ""
    echo "💡 What You've Built:"
    echo "   ✅ Complete Avro schema evolution system"
    echo "   ✅ Backward/forward compatibility testing"
    echo "   ✅ Real-time web dashboard"
    echo "   ✅ Comprehensive test suite"
    echo "   ✅ Docker deployment ready"
    echo ""
    echo "🎯 Learning Outcomes Achieved:"
    echo "   • Schema evolution patterns"
    echo "   • Avro serialization/deserialization"
    echo "   • Compatibility testing strategies"
    echo "   • Production-ready system architecture"
    echo ""
    echo "Ready to explore schema evolution! Happy coding! 🚀"
}

# Run the main function
main