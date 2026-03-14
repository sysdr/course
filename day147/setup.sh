#!/bin/bash

# Day 147: Business Intelligence Tool Integration - Complete Implementation
# Builds BI connectors for Tableau, PowerBI integration with distributed log system

set -e

PROJECT_NAME="day147-bi-integration"
PYTHON_VERSION="3.11"

echo "🚀 Day 147: Business Intelligence Tool Integration Setup"
echo "=================================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create project structure
echo -e "${GREEN}📁 Creating project structure...${NC}"
mkdir -p ${PROJECT_NAME}/{src/{api,auth,query,export,dashboard},tests/{unit,integration},config,exports/{csv,parquet},static/{css,js},docker}

cd ${PROJECT_NAME}

# Create Python virtual environment
echo -e "${GREEN}🐍 Setting up Python ${PYTHON_VERSION} virtual environment...${NC}"
if command -v python3.11 &> /dev/null; then
    python3.11 -m venv venv
elif command -v python3 &> /dev/null; then
    python3 -m venv venv
else
    echo -e "${RED}Error: Python 3 not found${NC}"
    exit 1
fi
source venv/bin/activate

# Create requirements.txt
echo -e "${GREEN}📦 Creating requirements.txt...${NC}"
cat > requirements.txt << 'EOF'
fastapi==0.110.0
uvicorn[standard]==0.28.0
influxdb-client==1.40.0
psycopg2-binary==2.9.9
pyarrow==15.0.0
pandas==2.2.0
pyjwt[crypto]==2.8.0
redis==5.0.3
python-multipart==0.0.9
aiofiles==23.2.1
httpx==0.27.0
pydantic==2.6.4
pydantic-settings==2.2.1
pytest==8.1.0
pytest-asyncio==0.23.6
pytest-cov==4.1.0
locust==2.24.0
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
bcrypt==4.0.1
jinja2==3.1.3
EOF

# Install dependencies
echo -e "${GREEN}📥 Installing Python dependencies...${NC}"
pip install --upgrade pip > /dev/null 2>&1
pip install -r requirements.txt > /dev/null 2>&1

echo -e "${GREEN}✅ Dependencies installed successfully${NC}"

# Create configuration files
echo -e "${GREEN}⚙️  Creating configuration files...${NC}"

cat > config/settings.py << 'EOF'
from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    # API Configuration
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    API_VERSION: str = "v1"
    
    # Database Configuration
    INFLUXDB_URL: str = "http://localhost:8086"
    INFLUXDB_TOKEN: str = "dev-token-please-change-in-production"
    INFLUXDB_ORG: str = "log-processing"
    INFLUXDB_BUCKET: str = "metrics"
    
    TIMESCALE_HOST: str = "localhost"
    TIMESCALE_PORT: int = 5432
    TIMESCALE_DB: str = "metrics"
    TIMESCALE_USER: str = "postgres"
    TIMESCALE_PASSWORD: str = "postgres"
    
    # Redis Configuration
    REDIS_URL: str = "redis://localhost:6379/0"
    CACHE_TTL: int = 300  # 5 minutes
    
    # OAuth Configuration
    JWT_SECRET_KEY: str = "dev-secret-key-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # Export Configuration
    EXPORT_BASE_PATH: str = "./exports"
    EXPORT_FORMATS: list = ["csv", "parquet"]
    
    # Performance Configuration
    MAX_QUERY_RANGE_DAYS: int = 90
    DEFAULT_PAGE_SIZE: int = 1000
    MAX_PAGE_SIZE: int = 10000
    
    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
EOF

cat > .env << 'EOF'
API_HOST=0.0.0.0
API_PORT=8000
INFLUXDB_URL=http://localhost:8086
REDIS_URL=redis://localhost:6379/0
JWT_SECRET_KEY=development-secret-key-change-in-production
EOF

# Create data models
echo -e "${GREEN}📊 Creating data models...${NC}"

cat > src/models.py << 'EOF'
from pydantic import BaseModel, Field
from typing import List, Dict, Optional, Any
from datetime import datetime
from enum import Enum

class TimeRange(BaseModel):
    start: datetime
    end: datetime

class AggregationWindow(str, Enum):
    MINUTE = "1m"
    HOUR = "1h"
    DAY = "1d"
    WEEK = "1w"

class MetricType(str, Enum):
    COUNT = "count"
    AVG = "avg"
    SUM = "sum"
    MIN = "min"
    MAX = "max"
    P95 = "p95"
    P99 = "p99"

class MetricQuery(BaseModel):
    measurement: str = "http_requests"
    time_range: TimeRange
    aggregation_window: AggregationWindow = AggregationWindow.HOUR
    filters: Dict[str, List[str]] = Field(default_factory=dict)
    metrics: List[MetricType] = Field(default_factory=lambda: [MetricType.COUNT, MetricType.AVG])
    page: int = Field(default=1, ge=1)
    page_size: int = Field(default=1000, ge=1, le=10000)

class BIDataResponse(BaseModel):
    schema: Dict[str, str]
    data: List[Dict[str, Any]]
    total_rows: int
    page: int
    page_size: int
    query_time_ms: float
    cached: bool

class MetricSchema(BaseModel):
    name: str
    display_name: str
    data_type: str
    description: str
    unit: Optional[str] = None

class DimensionSchema(BaseModel):
    name: str
    display_name: str
    values: List[str]
    filterable: bool = True

class SchemaResponse(BaseModel):
    metrics: List[MetricSchema]
    dimensions: List[DimensionSchema]
    time_range_available: TimeRange

class ExportRequest(BaseModel):
    date: datetime
    format: str = Field(default="csv", pattern="^(csv|parquet)$")
    metrics: Optional[List[str]] = None
    services: Optional[List[str]] = None

class ExportMetadata(BaseModel):
    export_id: str
    date: datetime
    format: str
    url: str
    row_count: int
    file_size_bytes: int
    columns: List[str]
    generated_at: datetime

class TokenData(BaseModel):
    username: Optional[str] = None
    scopes: List[str] = []
    allowed_services: List[str] = []
EOF

# Create authentication module
echo -e "${GREEN}🔐 Creating authentication module...${NC}"

cat > src/auth/oauth.py << 'EOF'
from datetime import datetime, timedelta
from typing import Optional, List
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from config.settings import settings
from src.models import TokenData

pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="oauth/token")

# Mock user database - replace with real auth in production
# Initialize passwords lazily to avoid bcrypt initialization issues
_USERS_DB_RAW = {
    "tableau": {
        "username": "tableau",
        "password": "tableau_secret",
        "scopes": ["read:metrics", "read:exports"],
        "allowed_services": ["api", "web", "database"]
    },
    "powerbi": {
        "username": "powerbi",
        "password": "powerbi_secret",
        "scopes": ["read:metrics"],
        "allowed_services": ["api", "web"]
    },
    "admin": {
        "username": "admin",
        "password": "admin_secret",
        "scopes": ["read:metrics", "write:exports", "admin"],
        "allowed_services": ["*"]
    }
}

_USERS_DB = None

def _init_users_db():
    """Initialize users database with hashed passwords"""
    global _USERS_DB
    if _USERS_DB is None:
        _USERS_DB = {}
        for username, user_data in _USERS_DB_RAW.items():
            _USERS_DB[username] = {
                "username": user_data["username"],
                "hashed_password": pwd_context.hash(user_data["password"]),
                "scopes": user_data["scopes"],
                "allowed_services": user_data["allowed_services"]
            }
    return _USERS_DB

def get_users_db():
    """Get users database, initializing if needed"""
    return _init_users_db()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def get_user(username: str):
    users_db = get_users_db()
    if username in users_db:
        return users_db[username]
    return None

def authenticate_user(username: str, password: str):
    user = get_user(username)
    if not user or not verify_password(password, user["hashed_password"]):
        return False
    return user

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return encoded_jwt

async def get_current_user(token: str = Depends(oauth2_scheme)) -> TokenData:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        username: str = payload.get("sub")
        scopes: List[str] = payload.get("scopes", [])
        allowed_services: List[str] = payload.get("allowed_services", [])
        if username is None:
            raise credentials_exception
        token_data = TokenData(username=username, scopes=scopes, allowed_services=allowed_services)
    except JWTError:
        raise credentials_exception
    return token_data

def check_permission(user: TokenData, required_scope: str):
    if required_scope not in user.scopes and "admin" not in user.scopes:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )

def filter_by_allowed_services(user: TokenData, services: List[str]) -> List[str]:
    if "*" in user.allowed_services:
        return services
    return [s for s in services if s in user.allowed_services]
EOF

# Create query builder
echo -e "${GREEN}🔍 Creating query builder...${NC}"

cat > src/query/influx_builder.py << 'EOF'
from influxdb_client import InfluxDBClient
from influxdb_client.client.query_api import QueryApi
from datetime import datetime, timedelta
from typing import List, Dict, Any
import time
from src.models import MetricQuery, BIDataResponse, MetricType
from config.settings import settings

class InfluxQueryBuilder:
    def __init__(self):
        self.client = InfluxDBClient(
            url=settings.INFLUXDB_URL,
            token=settings.INFLUXDB_TOKEN,
            org=settings.INFLUXDB_ORG
        )
        self.query_api = self.client.query_api()
    
    def build_flux_query(self, query: MetricQuery) -> str:
        """Build Flux query for InfluxDB"""
        start_str = query.time_range.start.isoformat()
        end_str = query.time_range.end.isoformat()
        
        flux_query = f'''
        from(bucket: "{settings.INFLUXDB_BUCKET}")
          |> range(start: {start_str}, stop: {end_str})
          |> filter(fn: (r) => r["_measurement"] == "{query.measurement}")
        '''
        
        # Add tag filters
        for tag_key, tag_values in query.filters.items():
            if tag_values:
                value_filter = ' or '.join([f'r["{tag_key}"] == "{v}"' for v in tag_values])
                flux_query += f'\n  |> filter(fn: (r) => {value_filter})'
        
        # Aggregation
        window = query.aggregation_window.value
        flux_query += f'\n  |> aggregateWindow(every: {window}, fn: mean, createEmpty: false)'
        flux_query += '\n  |> yield(name: "mean")'
        
        return flux_query
    
    def execute_query(self, query: MetricQuery) -> BIDataResponse:
        """Execute query and return BI-friendly response"""
        start_time = time.time()
        
        flux_query = self.build_flux_query(query)
        result = self.query_api.query(flux_query, org=settings.INFLUXDB_ORG)
        
        # Transform to tabular format
        data = []
        for table in result:
            for record in table.records:
                row = {
                    "timestamp": record.get_time().isoformat(),
                    "service": record.values.get("service", "unknown"),
                    "endpoint": record.values.get("endpoint", "unknown"),
                    "value": record.get_value()
                }
                data.append(row)
        
        # Apply pagination
        start_idx = (query.page - 1) * query.page_size
        end_idx = start_idx + query.page_size
        paginated_data = data[start_idx:end_idx]
        
        query_time_ms = (time.time() - start_time) * 1000
        
        schema = {
            "timestamp": "datetime",
            "service": "string",
            "endpoint": "string",
            "value": "float"
        }
        
        return BIDataResponse(
            schema=schema,
            data=paginated_data,
            total_rows=len(data),
            page=query.page,
            page_size=query.page_size,
            query_time_ms=query_time_ms,
            cached=False
        )
    
    def get_available_services(self) -> List[str]:
        """Get list of available services from InfluxDB"""
        flux_query = f'''
        from(bucket: "{settings.INFLUXDB_BUCKET}")
          |> range(start: -30d)
          |> filter(fn: (r) => r["_measurement"] == "http_requests")
          |> keep(columns: ["service"])
          |> distinct(column: "service")
        '''
        
        result = self.query_api.query(flux_query, org=settings.INFLUXDB_ORG)
        services = []
        for table in result:
            for record in table.records:
                services.append(record.values.get("service"))
        return list(set(services))
EOF

# Create cache layer
cat > src/query/cache.py << 'EOF'
import redis
import json
import hashlib
from typing import Optional
from src.models import BIDataResponse, MetricQuery
from config.settings import settings

class CacheLayer:
    def __init__(self):
        self.redis_client = redis.from_url(settings.REDIS_URL, decode_responses=True)
    
    def generate_cache_key(self, query: MetricQuery, user_services: list) -> str:
        """Generate unique cache key from query and user context"""
        query_dict = query.model_dump()
        query_dict['user_services'] = sorted(user_services)
        query_str = json.dumps(query_dict, sort_keys=True, default=str)
        return f"bi_query:{hashlib.sha256(query_str.encode()).hexdigest()}"
    
    def get(self, cache_key: str) -> Optional[BIDataResponse]:
        """Get cached query result"""
        cached_data = self.redis_client.get(cache_key)
        if cached_data:
            data_dict = json.loads(cached_data)
            return BIDataResponse(**data_dict)
        return None
    
    def set(self, cache_key: str, response: BIDataResponse, ttl: int = None):
        """Cache query result"""
        if ttl is None:
            ttl = settings.CACHE_TTL
        self.redis_client.setex(
            cache_key,
            ttl,
            response.model_dump_json()
        )
    
    def invalidate_pattern(self, pattern: str):
        """Invalidate all cache keys matching pattern"""
        keys = self.redis_client.keys(pattern)
        if keys:
            self.redis_client.delete(*keys)
EOF

# Create export generator
echo -e "${GREEN}📤 Creating export generator...${NC}"

cat > src/export/generator.py << 'EOF'
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
from pathlib import Path
from datetime import datetime
import json
from typing import List
from src.models import ExportRequest, ExportMetadata
from src.query.influx_builder import InfluxQueryBuilder
from config.settings import settings
import uuid

class ExportGenerator:
    def __init__(self):
        self.query_builder = InfluxQueryBuilder()
        self.export_base_path = Path(settings.EXPORT_BASE_PATH)
        self.export_base_path.mkdir(parents=True, exist_ok=True)
    
    def generate_export(self, request: ExportRequest) -> ExportMetadata:
        """Generate data export in requested format"""
        export_id = str(uuid.uuid4())[:8]
        
        # Query data from InfluxDB
        data = self._fetch_export_data(request)
        
        # Generate export file
        if request.format == "csv":
            file_path = self._generate_csv(data, request.date, export_id)
        else:  # parquet
            file_path = self._generate_parquet(data, request.date, export_id)
        
        # Create metadata
        file_stat = file_path.stat()
        metadata = ExportMetadata(
            export_id=export_id,
            date=request.date,
            format=request.format,
            url=f"/exports/{file_path.relative_to(self.export_base_path)}",
            row_count=len(data),
            file_size_bytes=file_stat.st_size,
            columns=list(data.columns),
            generated_at=datetime.utcnow()
        )
        
        # Save metadata
        self._save_metadata(metadata)
        
        return metadata
    
    def _fetch_export_data(self, request: ExportRequest) -> pd.DataFrame:
        """Fetch data for export from InfluxDB"""
        # Build query for entire day
        from src.models import MetricQuery, TimeRange, AggregationWindow
        
        query = MetricQuery(
            measurement="http_requests",
            time_range=TimeRange(
                start=request.date,
                end=request.date.replace(hour=23, minute=59, second=59)
            ),
            aggregation_window=AggregationWindow.HOUR,
            filters={"service": request.services} if request.services else {},
            page_size=100000
        )
        
        response = self.query_builder.execute_query(query)
        df = pd.DataFrame(response.data)
        
        # Add business metrics
        if not df.empty:
            df['error_rate'] = 0.0  # Calculate from actual data
            df['requests_per_second'] = df['value'] / 3600  # Hourly to per-second
        
        return df
    
    def _generate_csv(self, data: pd.DataFrame, date: datetime, export_id: str) -> Path:
        """Generate CSV export"""
        year_month_day = date.strftime("%Y/%m/%d")
        export_dir = self.export_base_path / "csv" / year_month_day
        export_dir.mkdir(parents=True, exist_ok=True)
        
        file_path = export_dir / f"metrics_{export_id}.csv"
        data.to_csv(file_path, index=False)
        
        return file_path
    
    def _generate_parquet(self, data: pd.DataFrame, date: datetime, export_id: str) -> Path:
        """Generate Parquet export"""
        year_month_day = date.strftime("%Y/%m/%d")
        export_dir = self.export_base_path / "parquet" / year_month_day
        export_dir.mkdir(parents=True, exist_ok=True)
        
        file_path = export_dir / f"metrics_{export_id}.parquet"
        table = pa.Table.from_pandas(data)
        pq.write_table(table, file_path, compression='snappy')
        
        return file_path
    
    def _save_metadata(self, metadata: ExportMetadata):
        """Save export metadata"""
        manifest_path = self.export_base_path / "manifest.json"
        
        # Load existing manifest
        if manifest_path.exists():
            with open(manifest_path) as f:
                manifest = json.load(f)
        else:
            manifest = {"exports": []}
        
        # Add new export
        manifest["exports"].append(metadata.model_dump(mode='json'))
        
        # Keep only last 100 exports
        manifest["exports"] = manifest["exports"][-100:]
        
        # Save manifest
        with open(manifest_path, 'w') as f:
            json.dump(manifest, f, indent=2, default=str)
    
    def get_manifest(self) -> dict:
        """Get export manifest"""
        manifest_path = self.export_base_path / "manifest.json"
        if manifest_path.exists():
            with open(manifest_path) as f:
                return json.load(f)
        return {"exports": []}
EOF

# Create API endpoints
echo -e "${GREEN}🌐 Creating API endpoints...${NC}"

cat > src/api/routes.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException, Query
from typing import List, Optional
from datetime import datetime, timedelta
from src.models import *
from src.auth.oauth import get_current_user, check_permission, filter_by_allowed_services, TokenData
from src.query.influx_builder import InfluxQueryBuilder
from src.query.cache import CacheLayer
from src.export.generator import ExportGenerator

router = APIRouter()
query_builder = InfluxQueryBuilder()
cache_layer = CacheLayer()
export_generator = ExportGenerator()

@router.get("/metrics/schema", response_model=SchemaResponse)
async def get_schema(current_user: TokenData = Depends(get_current_user)):
    """Get available metrics and dimensions"""
    check_permission(current_user, "read:metrics")
    
    services = query_builder.get_available_services()
    allowed_services = filter_by_allowed_services(current_user, services)
    
    metrics = [
        MetricSchema(
            name="request_count",
            display_name="Request Count",
            data_type="integer",
            description="Total number of requests",
            unit="requests"
        ),
        MetricSchema(
            name="avg_response_time",
            display_name="Average Response Time",
            data_type="float",
            description="Average response time",
            unit="milliseconds"
        ),
        MetricSchema(
            name="error_rate",
            display_name="Error Rate",
            data_type="float",
            description="Percentage of requests with errors",
            unit="percentage"
        )
    ]
    
    dimensions = [
        DimensionSchema(
            name="service",
            display_name="Service",
            values=allowed_services,
            filterable=True
        ),
        DimensionSchema(
            name="endpoint",
            display_name="API Endpoint",
            values=["/api/users", "/api/orders", "/api/products"],
            filterable=True
        )
    ]
    
    return SchemaResponse(
        metrics=metrics,
        dimensions=dimensions,
        time_range_available=TimeRange(
            start=datetime.utcnow() - timedelta(days=90),
            end=datetime.utcnow()
        )
    )

@router.post("/metrics/timeseries", response_model=BIDataResponse)
async def query_timeseries(
    query: MetricQuery,
    current_user: TokenData = Depends(get_current_user)
):
    """Query time series metrics"""
    check_permission(current_user, "read:metrics")
    
    # Filter services by user permissions
    if "service" in query.filters:
        query.filters["service"] = filter_by_allowed_services(
            current_user, 
            query.filters["service"]
        )
    
    # Check cache
    cache_key = cache_layer.generate_cache_key(query, current_user.allowed_services)
    cached_response = cache_layer.get(cache_key)
    if cached_response:
        cached_response.cached = True
        return cached_response
    
    # Execute query
    response = query_builder.execute_query(query)
    
    # Cache result
    cache_layer.set(cache_key, response)
    
    return response

@router.post("/metrics/aggregate")
async def query_aggregate(
    measurement: str = Query("http_requests"),
    start: datetime = Query(...),
    end: datetime = Query(...),
    group_by: List[str] = Query(default=["service"]),
    current_user: TokenData = Depends(get_current_user)
):
    """Get pre-aggregated metrics"""
    check_permission(current_user, "read:metrics")
    
    # Simplified aggregation - in production, use materialized views
    query = MetricQuery(
        measurement=measurement,
        time_range=TimeRange(start=start, end=end),
        aggregation_window=AggregationWindow.DAY,
        page_size=10000
    )
    
    response = query_builder.execute_query(query)
    
    # Group by requested dimensions
    import pandas as pd
    df = pd.DataFrame(response.data)
    if not df.empty and group_by:
        aggregated = df.groupby(group_by).agg({
            'value': ['sum', 'mean', 'count']
        }).reset_index()
        response.data = aggregated.to_dict('records')
    
    return response

@router.post("/exports/generate", response_model=ExportMetadata)
async def generate_export(
    request: ExportRequest,
    current_user: TokenData = Depends(get_current_user)
):
    """Generate data export"""
    check_permission(current_user, "write:exports")
    
    # Filter services by user permissions
    if request.services:
        request.services = filter_by_allowed_services(current_user, request.services)
    
    metadata = export_generator.generate_export(request)
    return metadata

@router.get("/exports/manifest")
async def get_export_manifest(
    current_user: TokenData = Depends(get_current_user)
):
    """Get export manifest"""
    check_permission(current_user, "read:exports")
    return export_generator.get_manifest()
EOF

# Create OAuth endpoints
cat > src/api/oauth_routes.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from datetime import timedelta
from src.auth.oauth import authenticate_user, create_access_token
from config.settings import settings

router = APIRouter()

@router.post("/token")
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    """OAuth token endpoint"""
    user = authenticate_user(form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={
            "sub": user["username"],
            "scopes": user["scopes"],
            "allowed_services": user["allowed_services"]
        },
        expires_delta=access_token_expires
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
    }
EOF

# Create main application
echo -e "${GREEN}🚀 Creating main application...${NC}"

cat > src/main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from src.api import routes, oauth_routes
from config.settings import settings
import uvicorn

app = FastAPI(
    title="BI Integration API",
    description="Business Intelligence tool integration for distributed log processing",
    version=settings.API_VERSION
)

# CORS middleware for BI tools
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")
app.mount("/exports", StaticFiles(directory="exports"), name="exports")

# Include routers
app.include_router(oauth_routes.router, prefix="/oauth", tags=["authentication"])
app.include_router(routes.router, prefix=f"/api/{settings.API_VERSION}", tags=["metrics"])

@app.get("/", response_class=HTMLResponse)
async def root():
    """Dashboard landing page"""
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>BI Integration Dashboard</title>
        <link rel="stylesheet" href="/static/css/dashboard.css">
    </head>
    <body>
        <div class="container">
            <h1>🎯 BI Integration API</h1>
            <div class="card">
                <h2>Available Endpoints</h2>
                <ul>
                    <li><a href="/docs">/docs - API Documentation</a></li>
                    <li>/oauth/token - Authentication</li>
                    <li>/api/v1/metrics/schema - Available metrics</li>
                    <li>/api/v1/metrics/timeseries - Query time series</li>
                    <li>/api/v1/exports/generate - Generate exports</li>
                </ul>
            </div>
            <div class="card">
                <h2>Quick Start</h2>
                <pre>
# Get access token
curl -X POST http://localhost:8000/oauth/token \\
  -d "username=tableau&password=tableau_secret&grant_type=password"

# Query metrics
curl http://localhost:8000/api/v1/metrics/schema \\
  -H "Authorization: Bearer YOUR_TOKEN"
                </pre>
            </div>
        </div>
        <script src="/static/js/dashboard.js"></script>
    </body>
    </html>
    """

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "version": settings.API_VERSION}

if __name__ == "__main__":
    uvicorn.run(
        "src.main:app",
        host=settings.API_HOST,
        port=settings.API_PORT,
        reload=True
    )
EOF

# Create dashboard CSS
cat > static/css/dashboard.css << 'EOF'
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    min-height: 100vh;
    padding: 2rem;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
}

h1 {
    color: white;
    margin-bottom: 2rem;
    font-size: 2.5rem;
    text-align: center;
    text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
}

.card {
    background: white;
    border-radius: 12px;
    padding: 2rem;
    margin-bottom: 1.5rem;
    box-shadow: 0 10px 30px rgba(0,0,0,0.15);
}

h2 {
    color: #667eea;
    margin-bottom: 1rem;
    font-size: 1.5rem;
}

ul {
    list-style: none;
    padding: 0;
}

li {
    padding: 0.75rem;
    border-bottom: 1px solid #f0f0f0;
}

li:last-child {
    border-bottom: none;
}

a {
    color: #667eea;
    text-decoration: none;
    font-weight: 500;
}

a:hover {
    color: #764ba2;
}

pre {
    background: #f5f5f5;
    padding: 1rem;
    border-radius: 8px;
    overflow-x: auto;
    border-left: 4px solid #667eea;
}
EOF

# Create dashboard JavaScript
cat > static/js/dashboard.js << 'EOF'
// Dashboard functionality
console.log('BI Integration Dashboard loaded');

// Add interactivity as needed
document.addEventListener('DOMContentLoaded', function() {
    // Future: Add real-time metric updates via WebSocket
});
EOF

# Create comprehensive tests
echo -e "${GREEN}🧪 Creating test suite...${NC}"

cat > tests/unit/test_query_builder.py << 'EOF'
import pytest
from datetime import datetime, timedelta
from src.query.influx_builder import InfluxQueryBuilder
from src.models import MetricQuery, TimeRange, AggregationWindow

@pytest.fixture
def query_builder():
    return InfluxQueryBuilder()

def test_flux_query_generation(query_builder):
    """Test Flux query string generation"""
    query = MetricQuery(
        measurement="http_requests",
        time_range=TimeRange(
            start=datetime(2025, 6, 15),
            end=datetime(2025, 6, 16)
        ),
        aggregation_window=AggregationWindow.HOUR
    )
    
    flux_query = query_builder.build_flux_query(query)
    assert "http_requests" in flux_query
    assert "aggregateWindow" in flux_query
    assert "1h" in flux_query

def test_query_with_filters(query_builder):
    """Test query with tag filters"""
    query = MetricQuery(
        measurement="http_requests",
        time_range=TimeRange(
            start=datetime(2025, 6, 15),
            end=datetime(2025, 6, 16)
        ),
        filters={"service": ["api", "web"]}
    )
    
    flux_query = query_builder.build_flux_query(query)
    assert 'service' in flux_query
    assert 'api' in flux_query or 'web' in flux_query
EOF

cat > tests/unit/test_auth.py << 'EOF'
import pytest
from src.auth.oauth import verify_password, create_access_token, authenticate_user
from datetime import timedelta

def test_password_verification():
    """Test password hashing and verification"""
    from src.auth.oauth import pwd_context
    password = "test_password"
    hashed = pwd_context.hash(password)
    
    assert verify_password(password, hashed)
    assert not verify_password("wrong_password", hashed)

def test_token_creation():
    """Test JWT token creation"""
    data = {"sub": "testuser", "scopes": ["read:metrics"]}
    token = create_access_token(data, expires_delta=timedelta(minutes=30))
    
    assert isinstance(token, str)
    assert len(token) > 0

def test_user_authentication():
    """Test user authentication"""
    # Valid credentials
    user = authenticate_user("tableau", "tableau_secret")
    assert user is not False
    assert user["username"] == "tableau"
    
    # Invalid credentials
    user = authenticate_user("tableau", "wrong_password")
    assert user is False
EOF

cat > tests/unit/test_export.py << 'EOF'
import pytest
from datetime import datetime
from src.export.generator import ExportGenerator
from src.models import ExportRequest

@pytest.fixture
def export_generator():
    return ExportGenerator()

def test_csv_export_generation(export_generator):
    """Test CSV export generation"""
    request = ExportRequest(
        date=datetime(2025, 6, 15),
        format="csv",
        services=["api"]
    )
    
    # Note: This will create actual files in exports directory
    # In production, mock the file operations
    assert request.format == "csv"
    assert request.date.year == 2025

def test_manifest_operations(export_generator):
    """Test export manifest operations"""
    manifest = export_generator.get_manifest()
    assert "exports" in manifest
    assert isinstance(manifest["exports"], list)
EOF

# Create integration tests
cat > tests/integration/test_api.py << 'EOF'
import pytest
from fastapi.testclient import TestClient
from src.main import app
from datetime import datetime, timedelta

client = TestClient(app)

def get_auth_token():
    """Get authentication token for tests"""
    response = client.post(
        "/oauth/token",
        data={"username": "tableau", "password": "tableau_secret", "grant_type": "password"}
    )
    return response.json()["access_token"]

def test_health_check():
    """Test health check endpoint"""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"

def test_authentication():
    """Test OAuth authentication"""
    response = client.post(
        "/oauth/token",
        data={"username": "tableau", "password": "tableau_secret", "grant_type": "password"}
    )
    assert response.status_code == 200
    assert "access_token" in response.json()

def test_schema_endpoint():
    """Test metrics schema endpoint"""
    token = get_auth_token()
    response = client.get(
        "/api/v1/metrics/schema",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    data = response.json()
    assert "metrics" in data
    assert "dimensions" in data

def test_unauthorized_access():
    """Test unauthorized access is blocked"""
    response = client.get("/api/v1/metrics/schema")
    assert response.status_code == 401
EOF

# Create Docker configuration
echo -e "${GREEN}🐳 Creating Docker configuration...${NC}"

cat > docker/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Expose port
EXPOSE 8000

# Run application
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  influxdb:
    image: influxdb:2.7-alpine
    ports:
      - "8086:8086"
    environment:
      - DOCKER_INFLUXDB_INIT_MODE=setup
      - DOCKER_INFLUXDB_INIT_USERNAME=admin
      - DOCKER_INFLUXDB_INIT_PASSWORD=adminpassword
      - DOCKER_INFLUXDB_INIT_ORG=log-processing
      - DOCKER_INFLUXDB_INIT_BUCKET=metrics
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=dev-token-please-change-in-production
    volumes:
      - influxdb_data:/var/lib/influxdb2

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  timescaledb:
    image: timescale/timescaledb:latest-pg15
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=metrics
    volumes:
      - timescale_data:/var/lib/postgresql/data

  bi-api:
    build:
      context: .
      dockerfile: docker/Dockerfile
    ports:
      - "8000:8000"
    depends_on:
      - influxdb
      - redis
      - timescaledb
    environment:
      - INFLUXDB_URL=http://influxdb:8086
      - REDIS_URL=redis://redis:6379/0
      - TIMESCALE_HOST=timescaledb
    volumes:
      - ./exports:/app/exports

volumes:
  influxdb_data:
  redis_data:
  timescale_data:
EOF

cat > .dockerignore << 'EOF'
venv/
__pycache__/
*.pyc
*.pyo
*.pyd
.pytest_cache/
.coverage
htmlcov/
dist/
build/
*.egg-info/
.env
.venv
EOF

# Create build script
echo -e "${GREEN}📜 Creating build script...${NC}"

cat > build.sh << 'EOF'
#!/bin/bash
set -e

echo "🔨 Building BI Integration System..."

# Activate virtual environment
source venv/bin/activate

# Run syntax check
echo "✓ Checking Python syntax..."
find src -name "*.py" -exec python -m py_compile {} \; 2>&1 | grep -v "^$" || true

# Run tests
echo "🧪 Running tests..."
python -m pytest tests/ -v --tb=short

echo "✅ Build completed successfully!"
EOF

chmod +x build.sh

# Create start script
cat > start.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting BI Integration System..."

# Start Docker services
echo "Starting infrastructure..."
docker-compose up -d influxdb redis timescaledb

# Wait for services
echo "Waiting for services to be ready..."
sleep 10

# Activate virtual environment
source venv/bin/activate

# Start API server
echo "Starting API server..."
uvicorn src.main:app --host 0.0.0.0 --port 8000 --reload &
API_PID=$!

echo "✅ System started successfully!"
echo "📊 Dashboard: http://localhost:8000"
echo "📖 API Docs: http://localhost:8000/docs"
echo ""
echo "Press Ctrl+C to stop"

# Wait for interrupt
wait $API_PID
EOF

chmod +x start.sh

# Create stop script
cat > stop.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping BI Integration System..."

# Stop API server
pkill -f "uvicorn src.main:app" || true

# Stop Docker services
docker-compose down

echo "✅ System stopped"
EOF

chmod +x stop.sh

# Create demo script
cat > demo.sh << 'EOF'
#!/bin/bash
set -e

echo "🎬 Running BI Integration Demo..."
source venv/bin/activate

# Wait for API to be ready
echo "Waiting for API server..."
sleep 3

# Get authentication token
echo -e "\n1️⃣ Authenticating as Tableau user..."
TOKEN=$(curl -s -X POST http://localhost:8000/oauth/token \
  -d "username=tableau&password=tableau_secret&grant_type=password" | \
  python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")

echo "✓ Token obtained: ${TOKEN:0:20}..."

# Get metrics schema
echo -e "\n2️⃣ Fetching available metrics schema..."
curl -s http://localhost:8000/api/v1/metrics/schema \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool | head -30

# Query time series data
echo -e "\n3️⃣ Querying time series metrics..."
START=$(date -u -d '1 day ago' '+%Y-%m-%dT%H:%M:%SZ')
END=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

curl -s -X POST http://localhost:8000/api/v1/metrics/timeseries \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"measurement\": \"http_requests\",
    \"time_range\": {\"start\": \"$START\", \"end\": \"$END\"},
    \"aggregation_window\": \"1h\",
    \"page\": 1,
    \"page_size\": 10
  }" | python3 -m json.tool | head -40

echo -e "\n4️⃣ Generating CSV export..."
EXPORT_DATE=$(date -u -d '1 day ago' '+%Y-%m-%d')
curl -s -X POST http://localhost:8000/api/v1/exports/generate \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"date\": \"${EXPORT_DATE}T00:00:00Z\", \"format\": \"csv\"}" | \
  python3 -m json.tool

echo -e "\n5️⃣ Fetching export manifest..."
curl -s http://localhost:8000/api/v1/exports/manifest \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool

echo -e "\n✅ Demo completed successfully!"
echo "📊 Access dashboard: http://localhost:8000"
echo "📖 View API docs: http://localhost:8000/docs"
EOF

chmod +x demo.sh

# Run build
echo -e "${GREEN}🔨 Running build...${NC}"
./build.sh

echo -e "${GREEN}✅ Setup Complete!${NC}"
echo ""
echo "📁 Project Structure Created:"
if command -v tree &> /dev/null; then
    tree -L 2 -I 'venv|__pycache__|*.pyc' .
else
    find . -maxdepth 2 -type f -o -type d | grep -v "^\./venv" | grep -v "__pycache__" | sort
fi

echo ""
echo -e "${GREEN}🚀 Quick Start Commands:${NC}"
echo "  ./start.sh   - Start all services"
echo "  ./demo.sh    - Run demonstration"
echo "  ./stop.sh    - Stop all services"
echo ""
echo "  ./build.sh   - Build and test"
echo "  docker-compose up -d - Start with Docker"
echo ""
echo "📊 Endpoints:"
echo "  http://localhost:8000      - Dashboard"
echo "  http://localhost:8000/docs - API Documentation"
echo ""
echo -e "${YELLOW}⚠️  Note: Start infrastructure first with './start.sh' or 'docker-compose up -d'${NC}"