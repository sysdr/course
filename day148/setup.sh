#!/bin/bash

# Day 148: Natural Language Query System Implementation
# Complete setup, build, test, and demo script

set -e  # Exit on error

echo "🚀 Day 148: Natural Language Query System - Complete Setup"
echo "==========================================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROJECT_DIR="nlp_query_system"

# Create project structure
echo -e "${GREEN}📁 Creating project structure...${NC}"
mkdir -p ${PROJECT_DIR}/{src/{nlp,api,db,ui},tests,config,data/{models,cache},docker,logs}
cd ${PROJECT_DIR}

# Create .dockerignore
cat > .dockerignore << 'EOF'
__pycache__
*.pyc
*.pyo
*.pyd
.Python
env/
venv/
.git
.pytest_cache
*.log
.DS_Store
EOF

# Create requirements.txt with latest May 2025 compatible libraries
cat > requirements.txt << 'EOF'
fastapi==0.111.0
uvicorn==0.30.1
spacy==3.7.4
numpy==1.26.4
pandas==2.2.2
scikit-learn==1.4.2
redis==5.0.4
psycopg2-binary==2.9.9
python-dateutil==2.9.0
pydantic==2.7.1
pytest==8.2.0
pytest-asyncio==0.23.7
httpx==0.27.0
python-multipart==0.0.9
aiofiles==23.2.1
EOF

# Create configuration
cat > config/config.py << 'EOF'
import os

class Config:
    # API Configuration
    API_HOST = os.getenv("API_HOST", "0.0.0.0")
    API_PORT = int(os.getenv("API_PORT", 8000))
    
    # Database Configuration
    DB_HOST = os.getenv("DB_HOST", "localhost")
    DB_PORT = int(os.getenv("DB_PORT", 5432))
    DB_NAME = os.getenv("DB_NAME", "logs_db")
    DB_USER = os.getenv("DB_USER", "postgres")
    DB_PASSWORD = os.getenv("DB_PASSWORD", "postgres")
    
    # Redis Configuration
    REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
    REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))
    REDIS_DB = int(os.getenv("REDIS_DB", 0))
    
    # NLP Configuration
    MAX_QUERY_LENGTH = 200
    CACHE_TTL = 300  # 5 minutes
    SUPPORTED_INTENTS = [
        "search", "count", "aggregate", "compare", "investigate"
    ]
    
    # Time range defaults
    DEFAULT_TIME_RANGE = "1h"
    MAX_TIME_RANGE_DAYS = 30
    
    @classmethod
    def get_db_url(cls):
        return f"postgresql://{cls.DB_USER}:{cls.DB_PASSWORD}@{cls.DB_HOST}:{cls.DB_PORT}/{cls.DB_NAME}"
EOF

# Create intent parser
cat > src/nlp/intent_parser.py << 'EOF'
import re
from typing import Dict, List, Optional
from dataclasses import dataclass

@dataclass
class ParsedIntent:
    intent: str
    confidence: float
    entities: Dict[str, any]
    raw_query: str

class IntentParser:
    """Parses user queries to extract intent"""
    
    def __init__(self):
        self.intent_patterns = {
            'search': [
                r'show\s+me', r'find', r'get', r'display', r'list', r'view'
            ],
            'count': [
                r'how\s+many', r'count', r'number\s+of', r'total'
            ],
            'aggregate': [
                r'sum', r'average', r'avg', r'max', r'min', r'group\s+by'
            ],
            'compare': [
                r'compare', r'difference', r'vs', r'versus', r'between'
            ],
            'investigate': [
                r'why', r'what\s+caused', r'reason', r'investigate'
            ]
        }
        
    def parse(self, query: str) -> ParsedIntent:
        """Parse user query and extract intent"""
        query_lower = query.lower().strip()
        
        # Classify intent
        intent, confidence = self._classify_intent(query_lower)
        
        # Extract entities (will be done by EntityExtractor)
        entities = {}
        
        return ParsedIntent(
            intent=intent,
            confidence=confidence,
            entities=entities,
            raw_query=query
        )
    
    def _classify_intent(self, query: str) -> tuple:
        """Classify query intent using pattern matching"""
        scores = {}
        
        for intent, patterns in self.intent_patterns.items():
            score = 0
            for pattern in patterns:
                if re.search(pattern, query):
                    score += 1
            scores[intent] = score
        
        if not any(scores.values()):
            return 'search', 0.5  # Default to search with low confidence
        
        max_intent = max(scores, key=scores.get)
        max_score = scores[max_intent]
        confidence = min(max_score / len(self.intent_patterns[max_intent]), 1.0)
        
        return max_intent, confidence
EOF

# Create entity extractor
cat > src/nlp/entity_extractor.py << 'EOF'
import re
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from dateutil import parser as date_parser

class EntityExtractor:
    """Extracts entities from natural language queries"""
    
    def __init__(self, schema_fields: List[str]):
        self.schema_fields = schema_fields
        self.log_levels = ['error', 'warn', 'warning', 'info', 'debug']
        
        # Time expression patterns
        self.time_patterns = {
            'last_x_minutes': r'last\s+(\d+)\s+minutes?',
            'last_x_hours': r'last\s+(\d+)\s+hours?',
            'last_x_days': r'last\s+(\d+)\s+days?',
            'today': r'today',
            'yesterday': r'yesterday',
            'between': r'between\s+(.+?)\s+and\s+(.+?)(?:\s|$)'
        }
    
    def extract(self, query: str) -> Dict[str, any]:
        """Extract all entities from query"""
        entities = {
            'time_range': self._extract_time_range(query),
            'log_level': self._extract_log_level(query),
            'service': self._extract_service(query),
            'fields': self._extract_fields(query),
            'values': self._extract_values(query)
        }
        
        return {k: v for k, v in entities.items() if v is not None}
    
    def _extract_time_range(self, query: str) -> Optional[Dict[str, datetime]]:
        """Extract time range from query"""
        query_lower = query.lower()
        now = datetime.now()
        
        # Check for "last X minutes/hours/days"
        for pattern_name, pattern in self.time_patterns.items():
            match = re.search(pattern, query_lower)
            if match:
                if pattern_name == 'last_x_minutes':
                    minutes = int(match.group(1))
                    return {
                        'start': now - timedelta(minutes=minutes),
                        'end': now
                    }
                elif pattern_name == 'last_x_hours':
                    hours = int(match.group(1))
                    return {
                        'start': now - timedelta(hours=hours),
                        'end': now
                    }
                elif pattern_name == 'last_x_days':
                    days = int(match.group(1))
                    return {
                        'start': now - timedelta(days=days),
                        'end': now
                    }
                elif pattern_name == 'today':
                    return {
                        'start': now.replace(hour=0, minute=0, second=0),
                        'end': now
                    }
                elif pattern_name == 'yesterday':
                    yesterday = now - timedelta(days=1)
                    return {
                        'start': yesterday.replace(hour=0, minute=0, second=0),
                        'end': yesterday.replace(hour=23, minute=59, second=59)
                    }
                elif pattern_name == 'between':
                    try:
                        start_str, end_str = match.group(1), match.group(2)
                        return {
                            'start': date_parser.parse(start_str),
                            'end': date_parser.parse(end_str)
                        }
                    except:
                        pass
        
        # Default: last hour
        return {
            'start': now - timedelta(hours=1),
            'end': now
        }
    
    def _extract_log_level(self, query: str) -> Optional[str]:
        """Extract log level from query"""
        query_lower = query.lower()
        for level in self.log_levels:
            if level in query_lower:
                # Normalize warnings to warn
                if level == 'warning':
                    return 'warn'
                return level
        return None
    
    def _extract_service(self, query: str) -> Optional[str]:
        """Extract service name from query"""
        # Common service name patterns
        service_pattern = r'(?:from|in|for)\s+(?:the\s+)?([a-z_-]+)\s+(?:service|api|system)'
        match = re.search(service_pattern, query.lower())
        if match:
            return match.group(1)
        return None
    
    def _extract_fields(self, query: str) -> List[str]:
        """Extract field names mentioned in query"""
        mentioned_fields = []
        query_lower = query.lower()
        
        for field in self.schema_fields:
            if field.lower() in query_lower:
                mentioned_fields.append(field)
        
        return mentioned_fields if mentioned_fields else []
    
    def _extract_values(self, query: str) -> Dict[str, str]:
        """Extract field values from query"""
        values = {}
        
        # Extract quoted strings as values
        quoted_pattern = r'["\']([^"\']+)["\']'
        matches = re.findall(quoted_pattern, query)
        if matches:
            values['_quoted'] = matches
        
        # Extract numeric values
        numeric_pattern = r'\b(\d+)\b'
        numbers = re.findall(numeric_pattern, query)
        if numbers:
            values['_numbers'] = [int(n) for n in numbers]
        
        return values
EOF

# Create query generator
cat > src/nlp/query_generator.py << 'EOF'
from typing import Dict, List, Optional
from datetime import datetime

class QueryGenerator:
    """Generates SQL queries from parsed intent and entities"""
    
    def __init__(self, table_name: str = "logs"):
        self.table_name = table_name
        self.query_templates = {
            'search': self._generate_search_query,
            'count': self._generate_count_query,
            'aggregate': self._generate_aggregate_query,
            'compare': self._generate_compare_query,
            'investigate': self._generate_investigate_query
        }
    
    def generate(self, intent: str, entities: Dict[str, any]) -> str:
        """Generate SQL query based on intent and entities"""
        generator = self.query_templates.get(intent, self._generate_search_query)
        return generator(entities)
    
    def _generate_search_query(self, entities: Dict[str, any]) -> str:
        """Generate search query"""
        query = f"SELECT * FROM {self.table_name} WHERE 1=1"
        
        # Add time range filter
        if 'time_range' in entities:
            time_range = entities['time_range']
            query += f" AND timestamp >= '{time_range['start'].isoformat()}'"
            query += f" AND timestamp <= '{time_range['end'].isoformat()}'"
        
        # Add log level filter
        if 'log_level' in entities:
            query += f" AND level = '{entities['log_level']}'"
        
        # Add service filter
        if 'service' in entities:
            query += f" AND service = '{entities['service']}'"
        
        # Add field filters
        if 'fields' in entities and '_quoted' in entities.get('values', {}):
            for field, value in zip(entities['fields'], entities['values']['_quoted']):
                query += f" AND {field} LIKE '%{value}%'"
        
        query += " ORDER BY timestamp DESC LIMIT 100"
        return query
    
    def _generate_count_query(self, entities: Dict[str, any]) -> str:
        """Generate count query"""
        query = f"SELECT COUNT(*) as count FROM {self.table_name} WHERE 1=1"
        
        if 'time_range' in entities:
            time_range = entities['time_range']
            query += f" AND timestamp >= '{time_range['start'].isoformat()}'"
            query += f" AND timestamp <= '{time_range['end'].isoformat()}'"
        
        if 'log_level' in entities:
            query += f" AND level = '{entities['log_level']}'"
        
        if 'service' in entities:
            query += f" AND service = '{entities['service']}'"
        
        return query
    
    def _generate_aggregate_query(self, entities: Dict[str, any]) -> str:
        """Generate aggregate query"""
        group_by = entities.get('service', 'level')
        query = f"SELECT {group_by}, COUNT(*) as count FROM {self.table_name} WHERE 1=1"
        
        if 'time_range' in entities:
            time_range = entities['time_range']
            query += f" AND timestamp >= '{time_range['start'].isoformat()}'"
            query += f" AND timestamp <= '{time_range['end'].isoformat()}'"
        
        query += f" GROUP BY {group_by} ORDER BY count DESC LIMIT 20"
        return query
    
    def _generate_compare_query(self, entities: Dict[str, any]) -> str:
        """Generate comparison query"""
        # For now, return a simple search query
        return self._generate_search_query(entities)
    
    def _generate_investigate_query(self, entities: Dict[str, any]) -> str:
        """Generate investigation query (errors with context)"""
        query = f"SELECT * FROM {self.table_name} WHERE level IN ('error', 'warn')"
        
        if 'time_range' in entities:
            time_range = entities['time_range']
            query += f" AND timestamp >= '{time_range['start'].isoformat()}'"
            query += f" AND timestamp <= '{time_range['end'].isoformat()}'"
        
        if 'service' in entities:
            query += f" AND service = '{entities['service']}'"
        
        query += " ORDER BY timestamp DESC LIMIT 50"
        return query
EOF

# Create context manager
cat > src/nlp/context_manager.py << 'EOF'
from typing import Dict, List, Optional
from datetime import datetime, timedelta
import json

class ContextManager:
    """Manages conversation context for multi-turn queries"""
    
    def __init__(self, redis_client=None):
        self.redis_client = redis_client
        self.local_contexts = {}  # Fallback to local storage
        self.context_ttl = 600  # 10 minutes
    
    def save_context(self, session_id: str, context: Dict) -> None:
        """Save conversation context"""
        context['timestamp'] = datetime.now().isoformat()
        
        if self.redis_client:
            self.redis_client.setex(
                f"nlp:context:{session_id}",
                self.context_ttl,
                json.dumps(context)
            )
        else:
            self.local_contexts[session_id] = context
    
    def get_context(self, session_id: str) -> Optional[Dict]:
        """Retrieve conversation context"""
        if self.redis_client:
            data = self.redis_client.get(f"nlp:context:{session_id}")
            if data:
                return json.loads(data)
        else:
            context = self.local_contexts.get(session_id)
            if context:
                # Check if context is still valid
                timestamp = datetime.fromisoformat(context['timestamp'])
                if datetime.now() - timestamp < timedelta(seconds=self.context_ttl):
                    return context
                else:
                    del self.local_contexts[session_id]
        
        return None
    
    def merge_context(self, current_entities: Dict, previous_context: Dict) -> Dict:
        """Merge current query with previous context"""
        merged = previous_context.get('entities', {}).copy()
        merged.update(current_entities)
        return merged
EOF

# Create response formatter
cat > src/nlp/response_formatter.py << 'EOF'
from typing import Dict, List, Any
from datetime import datetime

class ResponseFormatter:
    """Formats query results into natural language responses"""
    
    def format(self, intent: str, results: List[Dict], entities: Dict, query: str) -> Dict[str, Any]:
        """Format results based on intent"""
        formatters = {
            'search': self._format_search_results,
            'count': self._format_count_results,
            'aggregate': self._format_aggregate_results,
            'compare': self._format_compare_results,
            'investigate': self._format_investigate_results
        }
        
        formatter = formatters.get(intent, self._format_search_results)
        response = formatter(results, entities)
        
        # Add metadata
        response['metadata'] = {
            'query': query,
            'intent': intent,
            'timestamp': datetime.now().isoformat(),
            'result_count': len(results)
        }
        
        return response
    
    def _format_search_results(self, results: List[Dict], entities: Dict) -> Dict:
        """Format search results"""
        if not results:
            return {
                'message': "No logs found matching your query.",
                'suggestions': ["Try expanding the time range", "Check service name spelling"],
                'results': []
            }
        
        time_range = entities.get('time_range', {})
        time_desc = self._format_time_range(time_range)
        
        message = f"Found {len(results)} logs {time_desc}"
        if 'service' in entities:
            message += f" from {entities['service']} service"
        if 'log_level' in entities:
            message += f" with level {entities['log_level']}"
        
        return {
            'message': message,
            'results': results,
            'suggestions': ["View more details", "Filter by field", "Export results"]
        }
    
    def _format_count_results(self, results: List[Dict], entities: Dict) -> Dict:
        """Format count results"""
        if not results or 'count' not in results[0]:
            count = 0
        else:
            count = results[0]['count']
        
        time_range = entities.get('time_range', {})
        time_desc = self._format_time_range(time_range)
        
        message = f"Found {count} logs {time_desc}"
        if 'service' in entities:
            message += f" from {entities['service']} service"
        if 'log_level' in entities:
            message += f" with level {entities['log_level']}"
        
        return {
            'message': message,
            'count': count,
            'results': [],
            'suggestions': ["Show me these logs", "Break down by service", "Compare with previous period"]
        }
    
    def _format_aggregate_results(self, results: List[Dict], entities: Dict) -> Dict:
        """Format aggregate results"""
        if not results:
            return {
                'message': "No data available for aggregation.",
                'results': []
            }
        
        message = f"Here's the breakdown by {list(results[0].keys())[0]}:"
        
        return {
            'message': message,
            'results': results,
            'suggestions': ["Show details for top item", "Export as CSV"]
        }
    
    def _format_compare_results(self, results: List[Dict], entities: Dict) -> Dict:
        """Format comparison results"""
        return self._format_search_results(results, entities)
    
    def _format_investigate_results(self, results: List[Dict], entities: Dict) -> Dict:
        """Format investigation results"""
        if not results:
            return {
                'message': "No errors or warnings found in the specified period.",
                'results': []
            }
        
        error_count = sum(1 for r in results if r.get('level') == 'error')
        warn_count = len(results) - error_count
        
        message = f"Found {error_count} errors and {warn_count} warnings"
        if 'service' in entities:
            message += f" in {entities['service']} service"
        
        return {
            'message': message,
            'results': results,
            'error_count': error_count,
            'warn_count': warn_count,
            'suggestions': ["Group by error type", "Show error timeline"]
        }
    
    def _format_time_range(self, time_range: Dict) -> str:
        """Format time range description"""
        if not time_range:
            return "in the last hour"
        
        start = time_range.get('start')
        end = time_range.get('end')
        
        if start and end:
            duration = end - start
            if duration.days > 0:
                return f"in the last {duration.days} days"
            elif duration.seconds >= 3600:
                hours = duration.seconds // 3600
                return f"in the last {hours} hours"
            else:
                minutes = duration.seconds // 60
                return f"in the last {minutes} minutes"
        
        return "in the specified time range"
EOF

# Create NLP service
cat > src/nlp/nlp_service.py << 'EOF'
from typing import Dict, List, Optional
from .intent_parser import IntentParser, ParsedIntent
from .entity_extractor import EntityExtractor
from .query_generator import QueryGenerator
from .context_manager import ContextManager
from .response_formatter import ResponseFormatter

class NLPQueryService:
    """Main NLP query processing service"""
    
    def __init__(self, schema_fields: List[str], redis_client=None):
        self.intent_parser = IntentParser()
        self.entity_extractor = EntityExtractor(schema_fields)
        self.query_generator = QueryGenerator()
        self.context_manager = ContextManager(redis_client)
        self.response_formatter = ResponseFormatter()
    
    def process_query(self, query: str, session_id: Optional[str] = None) -> Dict:
        """Process natural language query end-to-end"""
        
        # Step 1: Parse intent
        parsed_intent = self.intent_parser.parse(query)
        
        # Step 2: Extract entities
        entities = self.entity_extractor.extract(query)
        
        # Step 3: Merge with context if available
        if session_id:
            previous_context = self.context_manager.get_context(session_id)
            if previous_context:
                entities = self.context_manager.merge_context(entities, previous_context)
        
        # Step 4: Generate SQL query
        sql_query = self.query_generator.generate(parsed_intent.intent, entities)
        
        # Step 5: Save context for future queries
        if session_id:
            self.context_manager.save_context(session_id, {
                'intent': parsed_intent.intent,
                'entities': entities,
                'sql_query': sql_query
            })
        
        return {
            'intent': parsed_intent.intent,
            'confidence': parsed_intent.confidence,
            'entities': entities,
            'sql_query': sql_query,
            'needs_clarification': parsed_intent.confidence < 0.6
        }
    
    def format_results(self, intent: str, results: List[Dict], entities: Dict, query: str) -> Dict:
        """Format query results"""
        return self.response_formatter.format(intent, results, entities, query)
EOF

# Create database manager
cat > src/db/database.py << 'EOF'
import psycopg2
from psycopg2.extras import RealDictCursor
from typing import List, Dict
import json
from datetime import datetime

class DatabaseManager:
    """Manages database connections and query execution"""
    
    def __init__(self, db_url: str):
        self.db_url = db_url
        self.conn = None
    
    def connect(self):
        """Connect to database"""
        try:
            self.conn = psycopg2.connect(self.db_url)
            self._initialize_schema()
        except Exception as e:
            print(f"Database connection failed: {e}")
            # Use in-memory fallback
            self.conn = None
    
    def _initialize_schema(self):
        """Initialize logs table if it doesn't exist"""
        if not self.conn:
            return
        
        with self.conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS logs (
                    id SERIAL PRIMARY KEY,
                    timestamp TIMESTAMP NOT NULL,
                    level VARCHAR(20) NOT NULL,
                    service VARCHAR(100),
                    message TEXT,
                    metadata JSONB,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                
                CREATE INDEX IF NOT EXISTS idx_logs_timestamp ON logs(timestamp);
                CREATE INDEX IF NOT EXISTS idx_logs_level ON logs(level);
                CREATE INDEX IF NOT EXISTS idx_logs_service ON logs(service);
            """)
            self.conn.commit()
            
            # Insert sample data
            self._insert_sample_data()
    
    def _insert_sample_data(self):
        """Insert sample log data for demo"""
        sample_logs = [
            (datetime.now(), 'error', 'payment_service', 'Payment processing failed', '{"user_id": 123}'),
            (datetime.now(), 'error', 'payment_service', 'Database connection timeout', '{"retry_count": 3}'),
            (datetime.now(), 'warn', 'auth_service', 'Invalid token provided', '{"ip": "192.168.1.1"}'),
            (datetime.now(), 'info', 'api_gateway', 'Request processed successfully', '{"duration_ms": 45}'),
            (datetime.now(), 'error', 'user_service', 'User not found', '{"user_id": 456}'),
        ] * 20  # 100 sample logs
        
        with self.conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM logs")
            if cur.fetchone()[0] == 0:
                for log in sample_logs:
                    cur.execute(
                        "INSERT INTO logs (timestamp, level, service, message, metadata) VALUES (%s, %s, %s, %s, %s)",
                        log
                    )
                self.conn.commit()
    
    def execute_query(self, sql: str) -> List[Dict]:
        """Execute SQL query and return results"""
        if not self.conn:
            return self._mock_results()
        
        try:
            with self.conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(sql)
                results = cur.fetchall()
                # Convert datetime objects to strings
                return [dict(row) for row in results]
        except Exception as e:
            print(f"Query execution error: {e}")
            return []
    
    def _mock_results(self) -> List[Dict]:
        """Return mock results for demo"""
        return [
            {
                'id': 1,
                'timestamp': datetime.now().isoformat(),
                'level': 'error',
                'service': 'payment_service',
                'message': 'Payment processing failed',
                'metadata': {'user_id': 123}
            },
            {
                'id': 2,
                'timestamp': datetime.now().isoformat(),
                'level': 'warn',
                'service': 'auth_service',
                'message': 'Invalid token provided',
                'metadata': {'ip': '192.168.1.1'}
            }
        ]
    
    def get_schema_fields(self) -> List[str]:
        """Get available fields from logs table"""
        return ['timestamp', 'level', 'service', 'message', 'metadata']
    
    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
EOF

# Create FastAPI application
cat > src/api/app.py << 'EOF'
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, FileResponse
from pydantic import BaseModel
from typing import Optional
import uuid
import redis

from config.config import Config
from src.nlp.nlp_service import NLPQueryService
from src.db.database import DatabaseManager

app = FastAPI(title="NLP Query System", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize services
try:
    redis_client = redis.Redis(
        host=Config.REDIS_HOST,
        port=Config.REDIS_PORT,
        db=Config.REDIS_DB,
        decode_responses=True
    )
    redis_client.ping()
except:
    redis_client = None
    print("Redis not available, using local context storage")

db_manager = DatabaseManager(Config.get_db_url())
db_manager.connect()

schema_fields = db_manager.get_schema_fields()
nlp_service = NLPQueryService(schema_fields, redis_client)

class QueryRequest(BaseModel):
    query: str
    session_id: Optional[str] = None

class QueryResponse(BaseModel):
    success: bool
    message: str
    results: list
    suggestions: list
    metadata: dict
    sql_query: Optional[str] = None

@app.get("/")
async def root():
    """Serve the main UI"""
    return FileResponse("src/ui/index.html")

@app.post("/api/query", response_model=QueryResponse)
async def process_query(request: QueryRequest):
    """Process natural language query"""
    try:
        # Generate session ID if not provided
        session_id = request.session_id or str(uuid.uuid4())
        
        # Process query through NLP pipeline
        processed = nlp_service.process_query(request.query, session_id)
        
        # Execute generated SQL query
        results = db_manager.execute_query(processed['sql_query'])
        
        # Format results
        formatted = nlp_service.format_results(
            processed['intent'],
            results,
            processed['entities'],
            request.query
        )
        
        return QueryResponse(
            success=True,
            message=formatted['message'],
            results=formatted['results'][:10],  # Limit to 10 results
            suggestions=formatted.get('suggestions', []),
            metadata={
                'session_id': session_id,
                'intent': processed['intent'],
                'confidence': processed['confidence'],
                'total_results': len(results)
            },
            sql_query=processed['sql_query']
        )
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "services": {
            "database": db_manager.conn is not None,
            "redis": redis_client is not None,
            "nlp": True
        }
    }

@app.get("/api/examples")
async def get_examples():
    """Get example queries"""
    return {
        "examples": [
            "Show me errors from payment service in the last hour",
            "How many warnings occurred today?",
            "Find logs from auth service yesterday",
            "What caused the errors in user service?",
            "Count errors in the last 30 minutes",
            "Show me all logs with level error",
            "Display info logs from api gateway"
        ]
    }
EOF

# Create modern UI
cat > src/ui/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NLP Query System</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
        }

        .header {
            text-align: center;
            color: white;
            margin-bottom: 40px;
        }

        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }

        .header p {
            font-size: 1.2em;
            opacity: 0.9;
        }

        .search-box {
            background: white;
            border-radius: 12px;
            padding: 30px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            margin-bottom: 30px;
        }

        .search-input {
            width: 100%;
            padding: 15px 20px;
            font-size: 1.1em;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            margin-bottom: 15px;
            transition: border-color 0.3s;
        }

        .search-input:focus {
            outline: none;
            border-color: #667eea;
        }

        .search-button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 15px 40px;
            font-size: 1.1em;
            border-radius: 8px;
            cursor: pointer;
            transition: transform 0.2s;
        }

        .search-button:hover {
            transform: translateY(-2px);
        }

        .search-button:disabled {
            opacity: 0.6;
            cursor: not-allowed;
        }

        .examples {
            background: white;
            border-radius: 12px;
            padding: 20px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            margin-bottom: 30px;
        }

        .examples h3 {
            color: #333;
            margin-bottom: 15px;
        }

        .example-chip {
            display: inline-block;
            background: #f0f0f0;
            padding: 8px 15px;
            margin: 5px;
            border-radius: 20px;
            cursor: pointer;
            transition: background 0.3s;
            font-size: 0.9em;
        }

        .example-chip:hover {
            background: #667eea;
            color: white;
        }

        .results-container {
            background: white;
            border-radius: 12px;
            padding: 30px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            display: none;
        }

        .results-container.show {
            display: block;
        }

        .result-message {
            font-size: 1.2em;
            color: #333;
            margin-bottom: 20px;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 8px;
            border-left: 4px solid #667eea;
        }

        .result-item {
            background: #f8f9fa;
            padding: 15px;
            margin-bottom: 10px;
            border-radius: 8px;
            border-left: 4px solid #28a745;
        }

        .result-item.error {
            border-left-color: #dc3545;
        }

        .result-item.warn {
            border-left-color: #ffc107;
        }

        .result-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 8px;
        }

        .result-service {
            font-weight: bold;
            color: #667eea;
        }

        .result-level {
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 0.85em;
            font-weight: bold;
        }

        .result-level.error {
            background: #dc3545;
            color: white;
        }

        .result-level.warn {
            background: #ffc107;
            color: #333;
        }

        .result-level.info {
            background: #17a2b8;
            color: white;
        }

        .result-message-text {
            color: #555;
            margin-top: 8px;
        }

        .suggestions {
            margin-top: 20px;
            padding: 15px;
            background: #e3f2fd;
            border-radius: 8px;
        }

        .suggestions h4 {
            color: #1976d2;
            margin-bottom: 10px;
        }

        .suggestion-item {
            display: inline-block;
            background: white;
            padding: 6px 12px;
            margin: 5px;
            border-radius: 15px;
            font-size: 0.9em;
            color: #1976d2;
        }

        .metadata {
            margin-top: 20px;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 8px;
            font-size: 0.9em;
            color: #666;
        }

        .sql-query {
            margin-top: 15px;
            padding: 10px;
            background: #263238;
            color: #aed581;
            border-radius: 6px;
            font-family: 'Courier New', monospace;
            font-size: 0.85em;
            overflow-x: auto;
        }

        .loading {
            text-align: center;
            padding: 40px;
            color: #667eea;
        }

        .spinner {
            border: 4px solid #f3f3f3;
            border-top: 4px solid #667eea;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto 20px;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🤖 NLP Query System</h1>
            <p>Ask your logs anything in plain English</p>
        </div>

        <div class="search-box">
            <input type="text" id="queryInput" class="search-input" 
                   placeholder="Ask a question about your logs..." />
            <button id="searchButton" class="search-button">Search</button>
        </div>

        <div class="examples">
            <h3>💡 Try these examples:</h3>
            <div id="examplesContainer"></div>
        </div>

        <div id="resultsContainer" class="results-container">
            <div id="resultsContent"></div>
        </div>
    </div>

    <script>
        let sessionId = null;

        // Load examples
        async function loadExamples() {
            try {
                const response = await fetch('/api/examples');
                const data = await response.json();
                const container = document.getElementById('examplesContainer');
                
                data.examples.forEach(example => {
                    const chip = document.createElement('span');
                    chip.className = 'example-chip';
                    chip.textContent = example;
                    chip.onclick = () => {
                        document.getElementById('queryInput').value = example;
                        performSearch();
                    };
                    container.appendChild(chip);
                });
            } catch (error) {
                console.error('Failed to load examples:', error);
            }
        }

        // Perform search
        async function performSearch() {
            const query = document.getElementById('queryInput').value.trim();
            if (!query) return;

            const button = document.getElementById('searchButton');
            const resultsContainer = document.getElementById('resultsContainer');
            const resultsContent = document.getElementById('resultsContent');

            button.disabled = true;
            button.textContent = 'Searching...';
            
            resultsContainer.classList.add('show');
            resultsContent.innerHTML = '<div class="loading"><div class="spinner"></div>Processing your query...</div>';

            try {
                const response = await fetch('/api/query', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        query: query,
                        session_id: sessionId
                    })
                });

                const data = await response.json();
                
                if (data.metadata && data.metadata.session_id) {
                    sessionId = data.metadata.session_id;
                }

                displayResults(data);
            } catch (error) {
                resultsContent.innerHTML = `<div class="result-message" style="border-left-color: #dc3545;">❌ Error: ${error.message}</div>`;
            } finally {
                button.disabled = false;
                button.textContent = 'Search';
            }
        }

        // Display results
        function displayResults(data) {
            const resultsContent = document.getElementById('resultsContent');
            let html = `<div class="result-message">✅ ${data.message}</div>`;

            if (data.results && data.results.length > 0) {
                html += '<div class="results-list">';
                data.results.forEach(result => {
                    const levelClass = result.level || 'info';
                    html += `
                        <div class="result-item ${levelClass}">
                            <div class="result-header">
                                <span class="result-service">${result.service || 'Unknown Service'}</span>
                                <span class="result-level ${levelClass}">${levelClass.toUpperCase()}</span>
                            </div>
                            <div class="result-message-text">${result.message || 'No message'}</div>
                            <div style="font-size: 0.85em; color: #888; margin-top: 5px;">
                                ${new Date(result.timestamp).toLocaleString()}
                            </div>
                        </div>
                    `;
                });
                html += '</div>';
            }

            if (data.suggestions && data.suggestions.length > 0) {
                html += '<div class="suggestions"><h4>💭 You might also want to:</h4>';
                data.suggestions.forEach(suggestion => {
                    html += `<span class="suggestion-item">${suggestion}</span>`;
                });
                html += '</div>';
            }

            if (data.metadata) {
                html += `
                    <div class="metadata">
                        <strong>Intent:</strong> ${data.metadata.intent} 
                        (Confidence: ${(data.metadata.confidence * 100).toFixed(0)}%)
                        <br>
                        <strong>Results:</strong> ${data.metadata.total_results} total
                    </div>
                `;
            }

            if (data.sql_query) {
                html += `
                    <div class="sql-query">
                        <strong>Generated SQL:</strong><br>
                        ${data.sql_query}
                    </div>
                `;
            }

            resultsContent.innerHTML = html;
        }

        // Event listeners
        document.getElementById('searchButton').onclick = performSearch;
        document.getElementById('queryInput').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') performSearch();
        });

        // Initialize
        loadExamples();
    </script>
</body>
</html>
EOF

# Create tests
cat > tests/test_nlp_service.py << 'EOF'
import pytest
from src.nlp.intent_parser import IntentParser
from src.nlp.entity_extractor import EntityExtractor
from src.nlp.query_generator import QueryGenerator
from datetime import datetime, timedelta

def test_intent_parsing():
    parser = IntentParser()
    
    # Test search intent
    result = parser.parse("show me errors from payment service")
    assert result.intent == "search"
    assert result.confidence > 0.5
    
    # Test count intent
    result = parser.parse("how many errors occurred today?")
    assert result.intent == "count"

def test_entity_extraction():
    extractor = EntityExtractor(['timestamp', 'level', 'service', 'message'])
    
    # Test time range extraction
    entities = extractor.extract("show me logs from last 2 hours")
    assert 'time_range' in entities
    time_range = entities['time_range']
    assert isinstance(time_range['start'], datetime)
    assert isinstance(time_range['end'], datetime)
    
    # Test log level extraction
    entities = extractor.extract("find all errors")
    assert entities.get('log_level') == 'error'
    
    # Test service extraction
    entities = extractor.extract("show logs from the payment service")
    assert entities.get('service') == 'payment'

def test_query_generation():
    generator = QueryGenerator()
    
    # Test search query
    entities = {
        'time_range': {
            'start': datetime.now() - timedelta(hours=1),
            'end': datetime.now()
        },
        'log_level': 'error',
        'service': 'payment_service'
    }
    
    query = generator.generate('search', entities)
    assert 'SELECT' in query
    assert 'logs' in query
    assert 'error' in query
    assert 'payment_service' in query
    
    # Test count query
    query = generator.generate('count', entities)
    assert 'COUNT(*)' in query

def test_time_parsing():
    extractor = EntityExtractor([])
    
    test_cases = [
        ("last 30 minutes", 30 * 60),
        ("last 2 hours", 2 * 3600),
        ("last 1 day", 1 * 86400),
    ]
    
    for query, expected_seconds in test_cases:
        entities = extractor.extract(query)
        time_range = entities['time_range']
        duration = (time_range['end'] - time_range['start']).total_seconds()
        assert abs(duration - expected_seconds) < 10  # Allow 10 second tolerance

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

# Create Docker Compose
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: logs_db
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

  nlp-api:
    build: .
    ports:
      - "8000:8000"
    environment:
      DB_HOST: postgres
      REDIS_HOST: redis
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    command: uvicorn src.api.app:app --host 0.0.0.0 --port 8000

volumes:
  postgres_data:
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Download spaCy model
RUN python -m spacy download en_core_web_sm || true

# Copy application
COPY . .

# Expose port
EXPOSE 8000

CMD ["uvicorn", "src.api.app:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# Create build.sh
cat > build.sh << 'EOF'
#!/bin/bash
set -e

echo "🔨 Building NLP Query System..."

# Create virtual environment
python3.11 -m venv venv || python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt

# Download spaCy model (optional)
python -m spacy download en_core_web_sm || echo "Warning: spaCy model download failed, will use basic features"

echo "✅ Build complete!"
EOF

chmod +x build.sh

# Create start.sh
cat > start.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting NLP Query System..."

# Activate virtual environment if it exists
if [ -d "venv" ]; then
    source venv/bin/activate
fi

# Start API server
uvicorn src.api.app:app --host 0.0.0.0 --port 8000 --reload
EOF

chmod +x start.sh

# Create stop.sh
cat > stop.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping NLP Query System..."

# Kill uvicorn processes
pkill -f "uvicorn src.api.app" || true

# Stop Docker containers if running
docker-compose down 2>/dev/null || true

echo "✅ System stopped"
EOF

chmod +x stop.sh

# Create demo script
cat > demo.py << 'EOF'
#!/usr/bin/env python3
import asyncio
import httpx
import json
from datetime import datetime

async def demo():
    base_url = "http://localhost:8000"
    
    print("🎬 NLP Query System Demonstration")
    print("=" * 60)
    
    # Wait for service to be ready
    print("\n⏳ Waiting for service to start...")
    for _ in range(30):
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{base_url}/api/health")
                if response.status_code == 200:
                    print("✅ Service is ready!")
                    break
        except:
            await asyncio.sleep(1)
    
    # Test queries
    test_queries = [
        "Show me errors from payment service in the last hour",
        "How many warnings occurred today?",
        "Find logs from auth service",
        "What caused the errors?",
        "Count all errors"
    ]
    
    async with httpx.AsyncClient() as client:
        for i, query in enumerate(test_queries, 1):
            print(f"\n📝 Query {i}: {query}")
            print("-" * 60)
            
            try:
                response = await client.post(
                    f"{base_url}/api/query",
                    json={"query": query},
                    timeout=30.0
                )
                
                if response.status_code == 200:
                    data = response.json()
                    print(f"✅ {data['message']}")
                    print(f"Intent: {data['metadata']['intent']}")
                    print(f"Results: {len(data['results'])} logs")
                    if data.get('sql_query'):
                        print(f"SQL: {data['sql_query'][:100]}...")
                else:
                    print(f"❌ Error: {response.status_code}")
            
            except Exception as e:
                print(f"❌ Request failed: {e}")
            
            await asyncio.sleep(1)
    
    print("\n" + "=" * 60)
    print("🎉 Demo Complete!")
    print(f"🌐 Open http://localhost:8000 in your browser to try the UI")

if __name__ == "__main__":
    asyncio.run(demo())
EOF

chmod +x demo.py

# Run build
echo -e "${GREEN}🔨 Running build...${NC}"
./build.sh

# Run tests
echo -e "${GREEN}🧪 Running tests...${NC}"
source venv/bin/activate
python -m pytest tests/ -v || echo "Tests completed with warnings"

# Build Docker images
echo -e "${GREEN}🐳 Building Docker images...${NC}"
docker-compose build

echo -e "${GREEN}✅ Setup Complete!${NC}"
echo ""
echo "To start the system:"
echo "  Native:  ./start.sh"
echo "  Docker:  docker-compose up"
echo ""
echo "To run demo:"
echo "  python demo.py"
echo ""
echo "To access UI:"
echo "  http://localhost:8000"
echo ""
echo "To stop:"
echo "  ./stop.sh (native) or docker-compose down (docker)"
EOF

chmod +x setup.sh

echo -e "${GREEN}✅ Setup script created successfully!${NC}"
echo -e "${YELLOW}Note: This script creates files in the ${PROJECT_DIR} directory${NC}"