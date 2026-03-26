#!/bin/bash

# Day 164: Change Impact Analysis System - Complete Setup Script
# This script creates project structure, generates all source files, builds, tests, and demos the system

set -e  # Exit on any error

PROJECT_NAME="day164-change-impact-analysis"
PYTHON_VERSION="python3.11"

echo "🚀 Day 164: Change Impact Analysis System Setup"
echo "=============================================="

# Create project structure
echo "📁 Creating project structure..."
mkdir -p ${PROJECT_NAME}/{src,tests,web/{src,public},config,docker}
cd ${PROJECT_NAME}

# Create Python source files
echo "📝 Creating source files..."

# 1. Impact Analyzer Core
cat > src/impact_analyzer.py << 'EOF'
"""
Core impact analysis engine using graph traversal algorithms
"""
import networkx as nx
from typing import Dict, List, Set, Tuple
from dataclasses import dataclass
from datetime import datetime

@dataclass
class ChangeProposal:
    change_type: str  # 'api_modification', 'infrastructure', 'schema_change'
    target_service: str
    change_description: str
    proposed_by: str = "system"
    timestamp: datetime = None
    
    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = datetime.now()

@dataclass
class ImpactResult:
    risk_score: float
    blast_radius: int
    affected_services: List[str]
    critical_path: bool
    recommendations: List[str]
    dependency_depth: Dict[str, int]
    
class ImpactAnalyzer:
    def __init__(self, dependency_graph: nx.DiGraph, service_metadata: Dict):
        """
        Initialize impact analyzer with dependency graph
        
        Args:
            dependency_graph: NetworkX directed graph of service dependencies
            service_metadata: Dict of service criticality and SLA requirements
        """
        self.graph = dependency_graph
        self.metadata = service_metadata
        self.analysis_cache = {}
        
    def analyze_change(self, proposal: ChangeProposal) -> ImpactResult:
        """
        Perform comprehensive impact analysis for proposed change
        """
        target = proposal.target_service
        
        # Check cache
        cache_key = f"{proposal.change_type}:{target}"
        if cache_key in self.analysis_cache:
            print(f"📋 Using cached analysis for {target}")
            return self.analysis_cache[cache_key]
        
        # Find all affected services through BFS traversal
        affected_services, depth_map = self._traverse_dependencies(target)
        
        # Calculate blast radius
        blast_radius = len(affected_services)
        
        # Determine if critical path is affected
        critical_path = self._check_critical_path(affected_services)
        
        # Calculate risk score
        risk_score = self._calculate_risk_score(
            proposal, affected_services, depth_map
        )
        
        # Generate recommendations
        recommendations = self._generate_recommendations(
            proposal, risk_score, affected_services, critical_path
        )
        
        result = ImpactResult(
            risk_score=risk_score,
            blast_radius=blast_radius,
            affected_services=sorted(affected_services),
            critical_path=critical_path,
            recommendations=recommendations,
            dependency_depth=depth_map
        )
        
        # Cache result
        self.analysis_cache[cache_key] = result
        
        return result
    
    def _traverse_dependencies(self, start_service: str) -> Tuple[Set[str], Dict[str, int]]:
        """
        BFS traversal to find all downstream dependencies
        Returns: (set of affected services, dict of service -> depth)
        """
        if start_service not in self.graph:
            return set(), {}
        
        affected = set()
        depth_map = {start_service: 0}
        queue = [(start_service, 0)]
        visited = set()
        
        while queue:
            service, depth = queue.pop(0)
            
            if service in visited:
                continue
            visited.add(service)
            affected.add(service)
            
            # Get all services that depend on current service
            for successor in self.graph.successors(service):
                if successor not in visited:
                    new_depth = depth + 1
                    depth_map[successor] = new_depth
                    queue.append((successor, new_depth))
        
        return affected, depth_map
    
    def _check_critical_path(self, affected_services: Set[str]) -> bool:
        """
        Check if any critical services are affected
        """
        for service in affected_services:
            metadata = self.metadata.get(service, {})
            if metadata.get('critical', False):
                return True
        return False
    
    def _calculate_risk_score(self, proposal: ChangeProposal, 
                              affected_services: Set[str],
                              depth_map: Dict[str, int]) -> float:
        """
        Calculate risk score (0-100) based on multiple factors
        """
        # Base score from blast radius (40% weight)
        blast_radius_score = min(len(affected_services) * 3, 40)
        
        # Criticality score (40% weight)
        max_criticality = 0
        for service in affected_services:
            criticality = self.metadata.get(service, {}).get('criticality', 1)
            depth_weight = 1.0 / (depth_map.get(service, 1) + 1)
            weighted_criticality = criticality * depth_weight
            max_criticality = max(max_criticality, weighted_criticality)
        
        criticality_score = min(max_criticality * 40, 40)
        
        # Change type risk multiplier (20% weight)
        type_multipliers = {
            'api_modification': 0.6,
            'schema_change': 0.9,
            'infrastructure': 0.8,
            'configuration': 0.4
        }
        type_score = type_multipliers.get(proposal.change_type, 0.5) * 20
        
        total_score = blast_radius_score + criticality_score + type_score
        return round(min(total_score, 100), 2)
    
    def _generate_recommendations(self, proposal: ChangeProposal,
                                 risk_score: float,
                                 affected_services: Set[str],
                                 critical_path: bool) -> List[str]:
        """
        Generate specific, actionable recommendations
        """
        recommendations = []
        
        # Risk-based recommendations
        if risk_score >= 70:
            recommendations.append(
                "Schedule during maintenance window with full team availability"
            )
            recommendations.append(
                "Prepare detailed rollback plan and test rollback procedure"
            )
        elif risk_score >= 40:
            recommendations.append(
                "Deploy with feature flag for gradual rollout"
            )
            recommendations.append(
                "Monitor key metrics for 24 hours post-deployment"
            )
        
        # Critical path recommendations
        if critical_path:
            recommendations.append(
                "Alert on-call team before deployment of critical path change"
            )
        
        # Change type specific recommendations
        if proposal.change_type == 'schema_change':
            recommendations.append(
                f"Update {len(affected_services)} downstream service schemas before deployment"
            )
            recommendations.append(
                "Implement backward compatibility for 2 release cycles"
            )
        elif proposal.change_type == 'api_modification':
            recommendations.append(
                "Maintain API versioning with deprecation notice period"
            )
        elif proposal.change_type == 'infrastructure':
            recommendations.append(
                "Test in staging environment with production traffic patterns"
            )
        
        # Always add monitoring recommendation
        if len(affected_services) > 5:
            recommendations.append(
                f"Set up enhanced monitoring for {len(affected_services)} affected services"
            )
        
        return recommendations

def create_sample_dependency_graph() -> Tuple[nx.DiGraph, Dict]:
    """
    Create sample distributed log processing system dependency graph
    """
    G = nx.DiGraph()
    
    # Add services as nodes
    services = [
        'log-collector',
        'log-enrichment',
        'rabbitmq-cluster',
        'log-processor',
        'analytics-pipeline',
        'real-time-dashboard',
        'alert-processor',
        'data-warehouse-sync',
        'ml-feature-extractor',
        'compliance-auditor',
        'reporting-service',
        'elasticsearch-cluster',
        'redis-cache',
        'metrics-collector',
        'api-gateway'
    ]
    
    G.add_nodes_from(services)
    
    # Add dependency edges (A -> B means B depends on A)
    dependencies = [
        ('log-collector', 'log-enrichment'),
        ('log-enrichment', 'rabbitmq-cluster'),
        ('rabbitmq-cluster', 'log-processor'),
        ('log-processor', 'analytics-pipeline'),
        ('log-processor', 'real-time-dashboard'),
        ('log-processor', 'alert-processor'),
        ('log-processor', 'elasticsearch-cluster'),
        ('analytics-pipeline', 'data-warehouse-sync'),
        ('analytics-pipeline', 'ml-feature-extractor'),
        ('log-enrichment', 'compliance-auditor'),
        ('elasticsearch-cluster', 'reporting-service'),
        ('redis-cache', 'real-time-dashboard'),
        ('api-gateway', 'log-collector'),
        ('metrics-collector', 'analytics-pipeline')
    ]
    
    G.add_edges_from(dependencies)
    
    # Service metadata with criticality
    metadata = {
        'log-collector': {'critical': True, 'criticality': 10, 'sla': '99.9%'},
        'log-enrichment': {'critical': True, 'criticality': 9, 'sla': '99.5%'},
        'rabbitmq-cluster': {'critical': True, 'criticality': 10, 'sla': '99.99%'},
        'log-processor': {'critical': True, 'criticality': 9, 'sla': '99.5%'},
        'analytics-pipeline': {'critical': False, 'criticality': 6, 'sla': '99.0%'},
        'real-time-dashboard': {'critical': True, 'criticality': 8, 'sla': '99.5%'},
        'alert-processor': {'critical': True, 'criticality': 10, 'sla': '99.9%'},
        'data-warehouse-sync': {'critical': False, 'criticality': 4, 'sla': '95.0%'},
        'ml-feature-extractor': {'critical': False, 'criticality': 5, 'sla': '95.0%'},
        'compliance-auditor': {'critical': True, 'criticality': 9, 'sla': '99.5%'},
        'reporting-service': {'critical': False, 'criticality': 6, 'sla': '99.0%'},
        'elasticsearch-cluster': {'critical': True, 'criticality': 9, 'sla': '99.5%'},
        'redis-cache': {'critical': False, 'criticality': 7, 'sla': '99.0%'},
        'metrics-collector': {'critical': False, 'criticality': 5, 'sla': '95.0%'},
        'api-gateway': {'critical': True, 'criticality': 10, 'sla': '99.99%'}
    }
    
    return G, metadata

if __name__ == "__main__":
    # Demo execution
    print("🔍 Initializing Change Impact Analyzer...")
    
    graph, metadata = create_sample_dependency_graph()
    analyzer = ImpactAnalyzer(graph, metadata)
    
    print(f"✅ Loaded dependency graph: {len(graph.nodes)} services, {len(graph.edges)} dependencies")
    
    # Test analysis
    proposal = ChangeProposal(
        change_type='schema_change',
        target_service='log-enrichment',
        change_description='Add new field: user_segment'
    )
    
    print(f"\n📊 Analyzing change: {proposal.change_description}")
    result = analyzer.analyze_change(proposal)
    
    print(f"\n📈 Impact Analysis Results:")
    print(f"  Risk Score: {result.risk_score}/100")
    print(f"  Blast Radius: {result.blast_radius} services")
    print(f"  Critical Path: {'YES' if result.critical_path else 'NO'}")
    print(f"  Affected Services: {', '.join(result.affected_services[:5])}...")
    print(f"\n💡 Recommendations:")
    for i, rec in enumerate(result.recommendations, 1):
        print(f"  {i}. {rec}")
EOF

# 2. Risk Calculator
cat > src/risk_calculator.py << 'EOF'
"""
Advanced risk calculation with historical data analysis
"""
from typing import Dict, List
from dataclasses import dataclass
from datetime import datetime, timedelta

@dataclass
class HistoricalChange:
    service: str
    change_type: str
    predicted_risk: float
    actual_outcome: str  # 'success', 'minor_issue', 'major_incident'
    timestamp: datetime

class RiskCalculator:
    def __init__(self):
        self.historical_changes: List[HistoricalChange] = []
        self.risk_adjustments = {}
        
    def add_historical_data(self, change: HistoricalChange):
        """Track historical changes for learning"""
        self.historical_changes.append(change)
        self._update_risk_adjustments()
    
    def _update_risk_adjustments(self):
        """Learn from historical outcomes to adjust risk calculations"""
        if len(self.historical_changes) < 5:
            return
        
        # Analyze last 30 days
        cutoff = datetime.now() - timedelta(days=30)
        recent_changes = [c for c in self.historical_changes if c.timestamp > cutoff]
        
        # Calculate adjustment factors by change type
        for change_type in ['api_modification', 'schema_change', 'infrastructure']:
            relevant = [c for c in recent_changes if c.change_type == change_type]
            if not relevant:
                continue
            
            # Count actual incidents
            incidents = sum(1 for c in relevant if c.actual_outcome != 'success')
            incident_rate = incidents / len(relevant)
            
            # Adjust risk multiplier
            base_multiplier = 1.0
            if incident_rate > 0.3:  # More than 30% incident rate
                self.risk_adjustments[change_type] = base_multiplier * 1.3
            elif incident_rate < 0.1:  # Less than 10% incident rate
                self.risk_adjustments[change_type] = base_multiplier * 0.8
            else:
                self.risk_adjustments[change_type] = base_multiplier
    
    def get_adjusted_risk(self, base_risk: float, change_type: str) -> float:
        """Apply historical learning to risk score"""
        multiplier = self.risk_adjustments.get(change_type, 1.0)
        adjusted = base_risk * multiplier
        return round(min(adjusted, 100), 2)
    
    def get_risk_trend(self, service: str, days: int = 30) -> Dict:
        """Analyze risk trends for a specific service"""
        cutoff = datetime.now() - timedelta(days=days)
        service_changes = [
            c for c in self.historical_changes 
            if c.service == service and c.timestamp > cutoff
        ]
        
        if not service_changes:
            return {'trend': 'insufficient_data', 'changes': 0}
        
        incident_rate = sum(
            1 for c in service_changes if c.actual_outcome != 'success'
        ) / len(service_changes)
        
        return {
            'trend': 'increasing' if incident_rate > 0.2 else 'stable',
            'changes': len(service_changes),
            'incident_rate': round(incident_rate, 2),
            'recommendation': 'Increase review rigor' if incident_rate > 0.2 else 'Standard review process'
        }
EOF

# 3. API Server
cat > src/api_server.py << 'EOF'
"""
FastAPI server exposing impact analysis endpoints
"""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
import uvicorn
from datetime import datetime

from impact_analyzer import ImpactAnalyzer, ChangeProposal, create_sample_dependency_graph
from risk_calculator import RiskCalculator

app = FastAPI(title="Change Impact Analysis API", version="1.0.0")

# Enable CORS for React frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize analyzer
graph, metadata = create_sample_dependency_graph()
analyzer = ImpactAnalyzer(graph, metadata)
risk_calc = RiskCalculator()

class ChangeRequest(BaseModel):
    change_type: str
    target_service: str
    change_description: str
    proposed_by: Optional[str] = "api_user"

class AnalysisResponse(BaseModel):
    risk_score: float
    blast_radius: int
    affected_services: List[str]
    critical_path: bool
    recommendations: List[str]
    dependency_depth: dict
    timestamp: str

@app.get("/")
async def root():
    return {
        "service": "Change Impact Analysis API",
        "version": "1.0.0",
        "status": "operational"
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "services_monitored": len(graph.nodes),
        "dependencies_tracked": len(graph.edges),
        "timestamp": datetime.now().isoformat()
    }

@app.post("/analyze", response_model=AnalysisResponse)
async def analyze_change(request: ChangeRequest):
    """Analyze impact of proposed change"""
    try:
        proposal = ChangeProposal(
            change_type=request.change_type,
            target_service=request.target_service,
            change_description=request.change_description,
            proposed_by=request.proposed_by
        )
        
        result = analyzer.analyze_change(proposal)
        
        # Apply historical risk adjustment
        adjusted_risk = risk_calc.get_adjusted_risk(
            result.risk_score, 
            proposal.change_type
        )
        
        return AnalysisResponse(
            risk_score=adjusted_risk,
            blast_radius=result.blast_radius,
            affected_services=result.affected_services,
            critical_path=result.critical_path,
            recommendations=result.recommendations,
            dependency_depth=result.dependency_depth,
            timestamp=datetime.now().isoformat()
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/services")
async def list_services():
    """List all monitored services"""
    services_info = []
    for service in graph.nodes:
        meta = metadata.get(service, {})
        services_info.append({
            "name": service,
            "critical": meta.get('critical', False),
            "criticality": meta.get('criticality', 1),
            "sla": meta.get('sla', 'N/A'),
            "dependencies": list(graph.successors(service))
        })
    return {"services": services_info, "total": len(services_info)}

@app.get("/service/{service_name}/dependencies")
async def get_service_dependencies(service_name: str):
    """Get dependency tree for specific service"""
    if service_name not in graph:
        raise HTTPException(status_code=404, detail="Service not found")
    
    # Get all downstream dependencies
    affected, depth_map = analyzer._traverse_dependencies(service_name)
    
    return {
        "service": service_name,
        "total_dependencies": len(affected) - 1,  # Exclude self
        "dependency_tree": depth_map,
        "affected_services": sorted(affected)
    }

if __name__ == "__main__":
    print("🚀 Starting Change Impact Analysis API Server...")
    print("📊 Loaded services:", len(graph.nodes))
    print("🔗 Tracked dependencies:", len(graph.edges))
    print("\n🌐 Server running at http://localhost:8000")
    print("📖 API docs available at http://localhost:8000/docs")
    
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
EOF

# 4. Test Suite
cat > tests/test_impact_analyzer.py << 'EOF'
"""
Comprehensive test suite for impact analyzer
"""
import pytest
import networkx as nx
from src.impact_analyzer import ImpactAnalyzer, ChangeProposal, create_sample_dependency_graph

@pytest.fixture
def analyzer():
    graph, metadata = create_sample_dependency_graph()
    return ImpactAnalyzer(graph, metadata)

def test_analyzer_initialization(analyzer):
    """Test analyzer initializes correctly"""
    assert analyzer is not None
    assert len(analyzer.graph.nodes) > 0
    assert len(analyzer.metadata) > 0

def test_direct_impact_calculation(analyzer):
    """Test direct impact on immediate dependencies"""
    proposal = ChangeProposal(
        change_type='api_modification',
        target_service='log-enrichment',
        change_description='Add new API endpoint'
    )
    
    result = analyzer.analyze_change(proposal)
    
    assert result.blast_radius > 0
    assert 'log-enrichment' in result.affected_services
    assert result.risk_score >= 0 and result.risk_score <= 100

def test_transitive_dependencies(analyzer):
    """Test transitive dependency traversal"""
    proposal = ChangeProposal(
        change_type='infrastructure',
        target_service='rabbitmq-cluster',
        change_description='Upgrade RabbitMQ version'
    )
    
    result = analyzer.analyze_change(proposal)
    
    # RabbitMQ should affect multiple downstream services
    assert result.blast_radius >= 3
    assert 'rabbitmq-cluster' in result.affected_services

def test_critical_path_detection(analyzer):
    """Test critical path identification"""
    proposal = ChangeProposal(
        change_type='schema_change',
        target_service='log-collector',
        change_description='Change log format'
    )
    
    result = analyzer.analyze_change(proposal)
    
    # log-collector is critical
    assert result.critical_path == True

def test_risk_score_calculation(analyzer):
    """Test risk score is calculated properly"""
    # High risk change
    high_risk = ChangeProposal(
        change_type='schema_change',
        target_service='rabbitmq-cluster',
        change_description='Breaking schema change'
    )
    
    high_result = analyzer.analyze_change(high_risk)
    
    # Low risk change
    low_risk = ChangeProposal(
        change_type='configuration',
        target_service='reporting-service',
        change_description='Update config parameter'
    )
    
    low_result = analyzer.analyze_change(low_risk)
    
    assert high_result.risk_score > low_result.risk_score

def test_recommendations_generation(analyzer):
    """Test that recommendations are generated"""
    proposal = ChangeProposal(
        change_type='infrastructure',
        target_service='elasticsearch-cluster',
        change_description='Scale cluster'
    )
    
    result = analyzer.analyze_change(proposal)
    
    assert len(result.recommendations) > 0
    assert isinstance(result.recommendations[0], str)

def test_blast_radius_accuracy(analyzer):
    """Test blast radius calculation accuracy"""
    # Service with many dependencies
    proposal = ChangeProposal(
        change_type='api_modification',
        target_service='log-processor',
        change_description='Update API'
    )
    
    result = analyzer.analyze_change(proposal)
    
    # Verify all affected services are actually in dependency tree
    for service in result.affected_services:
        assert service in analyzer.graph.nodes

def test_caching_mechanism(analyzer):
    """Test that analysis results are cached"""
    proposal = ChangeProposal(
        change_type='api_modification',
        target_service='log-enrichment',
        change_description='Test caching'
    )
    
    # First analysis
    result1 = analyzer.analyze_change(proposal)
    cache_size_before = len(analyzer.analysis_cache)
    
    # Second analysis (should use cache)
    result2 = analyzer.analyze_change(proposal)
    cache_size_after = len(analyzer.analysis_cache)
    
    assert result1.risk_score == result2.risk_score
    assert cache_size_before == cache_size_after

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

# 5. React Frontend
cat > web/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Change Impact Analysis Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        
        .header {
            background: white;
            border-radius: 12px;
            padding: 30px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
            margin-bottom: 30px;
        }
        
        .header h1 {
            color: #2d3748;
            font-size: 32px;
            margin-bottom: 10px;
        }
        
        .header p {
            color: #718096;
            font-size: 16px;
        }
        
        .panel {
            background: white;
            border-radius: 12px;
            padding: 30px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
            margin-bottom: 30px;
        }
        
        .panel h2 {
            color: #2d3748;
            font-size: 24px;
            margin-bottom: 20px;
            border-bottom: 3px solid #667eea;
            padding-bottom: 10px;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        .form-group label {
            display: block;
            color: #4a5568;
            font-weight: 600;
            margin-bottom: 8px;
        }
        
        .form-group select,
        .form-group input,
        .form-group textarea {
            width: 100%;
            padding: 12px;
            border: 2px solid #e2e8f0;
            border-radius: 8px;
            font-size: 14px;
            transition: border-color 0.3s;
        }
        
        .form-group select:focus,
        .form-group input:focus,
        .form-group textarea:focus {
            outline: none;
            border-color: #667eea;
        }
        
        .btn {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 14px 28px;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 25px rgba(102, 126, 234, 0.4);
        }
        
        .btn:active {
            transform: translateY(0);
        }
        
        .results {
            display: none;
        }
        
        .results.show {
            display: block;
        }
        
        .metric-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .metric-card {
            background: linear-gradient(135deg, #f6f8fb 0%, #e9ecef 100%);
            padding: 20px;
            border-radius: 10px;
            border-left: 4px solid #667eea;
        }
        
        .metric-card h3 {
            color: #4a5568;
            font-size: 14px;
            margin-bottom: 10px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .metric-card .value {
            color: #2d3748;
            font-size: 32px;
            font-weight: 700;
        }
        
        .risk-badge {
            display: inline-block;
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            margin-left: 10px;
        }
        
        .risk-low {
            background: #c6f6d5;
            color: #22543d;
        }
        
        .risk-medium {
            background: #feebc8;
            color: #7c2d12;
        }
        
        .risk-high {
            background: #fed7d7;
            color: #742a2a;
        }
        
        .services-list {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            margin-top: 15px;
        }
        
        .service-tag {
            background: #667eea;
            color: white;
            padding: 8px 16px;
            border-radius: 20px;
            font-size: 13px;
        }
        
        .recommendations {
            background: #f7fafc;
            padding: 20px;
            border-radius: 8px;
            border-left: 4px solid #48bb78;
        }
        
        .recommendations h3 {
            color: #2d3748;
            margin-bottom: 15px;
        }
        
        .recommendations ul {
            list-style: none;
        }
        
        .recommendations li {
            padding: 10px 0;
            color: #4a5568;
            border-bottom: 1px solid #e2e8f0;
        }
        
        .recommendations li:last-child {
            border-bottom: none;
        }
        
        .recommendations li:before {
            content: "✓ ";
            color: #48bb78;
            font-weight: bold;
            margin-right: 10px;
        }
        
        .loading {
            display: none;
            text-align: center;
            padding: 40px;
        }
        
        .loading.show {
            display: block;
        }
        
        .spinner {
            border: 4px solid #f3f4f6;
            border-top: 4px solid #667eea;
            border-radius: 50%;
            width: 50px;
            height: 50px;
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
            <h1>🔍 Change Impact Analysis</h1>
            <p>Predict the blast radius and risk of proposed changes to your distributed system</p>
        </div>
        
        <div class="panel">
            <h2>Propose a Change</h2>
            <form id="analysisForm">
                <div class="form-group">
                    <label for="changeType">Change Type</label>
                    <select id="changeType" required>
                        <option value="">Select change type...</option>
                        <option value="api_modification">API Modification</option>
                        <option value="schema_change">Schema Change</option>
                        <option value="infrastructure">Infrastructure Update</option>
                        <option value="configuration">Configuration Change</option>
                    </select>
                </div>
                
                <div class="form-group">
                    <label for="targetService">Target Service</label>
                    <select id="targetService" required>
                        <option value="">Select service...</option>
                    </select>
                </div>
                
                <div class="form-group">
                    <label for="changeDescription">Change Description</label>
                    <textarea id="changeDescription" rows="3" placeholder="Describe the proposed change..." required></textarea>
                </div>
                
                <button type="submit" class="btn">Analyze Impact</button>
            </form>
        </div>
        
        <div class="loading" id="loading">
            <div class="spinner"></div>
            <p>Analyzing impact across dependency graph...</p>
        </div>
        
        <div class="results" id="results">
            <div class="panel">
                <h2>Impact Analysis Results</h2>
                
                <div class="metric-grid">
                    <div class="metric-card">
                        <h3>Risk Score</h3>
                        <div class="value" id="riskScore">-</div>
                    </div>
                    
                    <div class="metric-card">
                        <h3>Blast Radius</h3>
                        <div class="value" id="blastRadius">-</div>
                    </div>
                    
                    <div class="metric-card">
                        <h3>Critical Path</h3>
                        <div class="value" id="criticalPath">-</div>
                    </div>
                </div>
                
                <h3>Affected Services</h3>
                <div class="services-list" id="servicesList"></div>
                
                <div class="recommendations" style="margin-top: 30px;">
                    <h3>📋 Recommended Actions</h3>
                    <ul id="recommendationsList"></ul>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        const API_URL = 'http://localhost:8000';
        
        // Load services on page load
        async function loadServices() {
            try {
                const response = await fetch(`${API_URL}/services`);
                const data = await response.json();
                
                const select = document.getElementById('targetService');
                data.services.forEach(service => {
                    const option = document.createElement('option');
                    option.value = service.name;
                    option.textContent = `${service.name} ${service.critical ? '⚠️' : ''}`;
                    select.appendChild(option);
                });
            } catch (error) {
                console.error('Failed to load services:', error);
            }
        }
        
        // Handle form submission
        document.getElementById('analysisForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const formData = {
                change_type: document.getElementById('changeType').value,
                target_service: document.getElementById('targetService').value,
                change_description: document.getElementById('changeDescription').value
            };
            
            // Show loading, hide results
            document.getElementById('loading').classList.add('show');
            document.getElementById('results').classList.remove('show');
            
            try {
                const response = await fetch(`${API_URL}/analyze`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(formData)
                });
                
                const result = await response.json();
                displayResults(result);
                
                // Hide loading, show results
                document.getElementById('loading').classList.remove('show');
                document.getElementById('results').classList.add('show');
                
            } catch (error) {
                console.error('Analysis failed:', error);
                alert('Failed to analyze change. Please check if the API server is running.');
                document.getElementById('loading').classList.remove('show');
            }
        });
        
        function displayResults(result) {
            // Risk score with badge
            const riskScore = result.risk_score;
            let riskClass = 'risk-low';
            if (riskScore >= 70) riskClass = 'risk-high';
            else if (riskScore >= 40) riskClass = 'risk-medium';
            
            document.getElementById('riskScore').innerHTML = 
                `${riskScore.toFixed(1)}<span class="risk-badge ${riskClass}">${riskClass.replace('risk-', '').toUpperCase()}</span>`;
            
            // Blast radius
            document.getElementById('blastRadius').textContent = 
                `${result.blast_radius} services`;
            
            // Critical path
            document.getElementById('criticalPath').textContent = 
                result.critical_path ? 'YES ⚠️' : 'NO ✓';
            
            // Affected services
            const servicesList = document.getElementById('servicesList');
            servicesList.innerHTML = '';
            result.affected_services.forEach(service => {
                const tag = document.createElement('div');
                tag.className = 'service-tag';
                tag.textContent = service;
                servicesList.appendChild(tag);
            });
            
            // Recommendations
            const recommendationsList = document.getElementById('recommendationsList');
            recommendationsList.innerHTML = '';
            result.recommendations.forEach(rec => {
                const li = document.createElement('li');
                li.textContent = rec;
                recommendationsList.appendChild(li);
            });
        }
        
        // Initialize
        loadServices();
    </script>
</body>
</html>
EOF

# 6. Configuration
cat > config/services.yaml << 'EOF'
# Service configuration for impact analysis
services:
  log-collector:
    critical: true
    criticality: 10
    sla: 99.9%
    
  log-enrichment:
    critical: true
    criticality: 9
    sla: 99.5%
    
  rabbitmq-cluster:
    critical: true
    criticality: 10
    sla: 99.99%
    
  alert-processor:
    critical: true
    criticality: 10
    sla: 99.9%

risk_thresholds:
  low: 0-39
  medium: 40-69
  high: 70-100

recommendations:
  high_risk:
    - Schedule during maintenance window
    - Prepare detailed rollback plan
    - Alert on-call team
  medium_risk:
    - Deploy with feature flag
    - Monitor for 24 hours
  low_risk:
    - Standard deployment process
EOF

# 7. Docker configuration
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY src/ ./src/
COPY config/ ./config/

# Expose port
EXPOSE 8000

# Run application
CMD ["python", "src/api_server.py"]
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  api:
    build: .
    ports:
      - "8000:8000"
    environment:
      - PYTHONUNBUFFERED=1
    volumes:
      - ./src:/app/src
      - ./config:/app/config
    restart: unless-stopped
    
  web:
    image: python:3.11-slim
    working_dir: /app
    command: python -m http.server 3000
    ports:
      - "3000:3000"
    volumes:
      - ./web/public:/app
    restart: unless-stopped
EOF

cat > .dockerignore << 'EOF'
__pycache__
*.pyc
*.pyo
*.pyd
.Python
venv/
*.log
.pytest_cache
.coverage
htmlcov/
EOF

# 8. Requirements
cat > requirements.txt << 'EOF'
fastapi==0.110.0
uvicorn==0.27.1
pydantic==2.6.3
networkx==3.2.1
pytest==8.0.2
pytest-asyncio==0.23.5
EOF

# 9. Start script
cat > start.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting Day 164: Change Impact Analysis System"
echo "=================================================="

# Check Python version
if ! command -v python3.11 &> /dev/null; then
    echo "❌ Python 3.11 not found. Please install Python 3.11"
    exit 1
fi

# Create virtual environment
echo "📦 Creating virtual environment..."
python3.11 -m venv venv
source venv/bin/activate

# Install dependencies
echo "📥 Installing dependencies..."
pip install --upgrade pip > /dev/null 2>&1
pip install -r requirements.txt > /dev/null 2>&1

# Run tests
echo ""
echo "🧪 Running tests..."
python -m pytest tests/ -v

# Start API server in background
echo ""
echo "🌐 Starting API server..."
python src/api_server.py &
API_PID=$!
echo "API PID: $API_PID"

# Wait for API to be ready
sleep 3

# Start web server
echo "🖥️  Starting web dashboard..."
cd web/public && python -m http.server 3000 &
WEB_PID=$!
cd ../..

echo ""
echo "✅ System started successfully!"
echo ""
echo "📍 Access points:"
echo "   API Server: http://localhost:8000"
echo "   API Docs: http://localhost:8000/docs"
echo "   Web Dashboard: http://localhost:3000"
echo ""
echo "💡 Test the system:"
echo "   curl http://localhost:8000/health"
echo ""
echo "🛑 To stop: ./stop.sh"

# Save PIDs
echo $API_PID > .api.pid
echo $WEB_PID > .web.pid
EOF

chmod +x start.sh

# 10. Stop script
cat > stop.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping Change Impact Analysis System..."

if [ -f .api.pid ]; then
    API_PID=$(cat .api.pid)
    kill $API_PID 2>/dev/null
    rm .api.pid
    echo "✅ API server stopped"
fi

if [ -f .web.pid ]; then
    WEB_PID=$(cat .web.pid)
    kill $WEB_PID 2>/dev/null
    rm .web.pid
    echo "✅ Web server stopped"
fi

# Cleanup any remaining Python processes on ports
lsof -ti:8000 | xargs kill -9 2>/dev/null
lsof -ti:3000 | xargs kill -9 2>/dev/null

echo "✅ All services stopped"
EOF

chmod +x stop.sh

# 11. Demo script
cat > demo.sh << 'EOF'
#!/bin/bash

echo "🎬 Running Change Impact Analysis Demo"
echo "======================================"

# Ensure API is running
if ! curl -s http://localhost:8000/health > /dev/null; then
    echo "❌ API server not running. Start with ./start.sh first"
    exit 1
fi

echo ""
echo "Test 1: Low Risk Change (Configuration Update)"
echo "----------------------------------------------"
curl -s -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "change_type": "configuration",
    "target_service": "reporting-service",
    "change_description": "Update report refresh interval"
  }' | python -m json.tool

echo ""
echo ""
echo "Test 2: Medium Risk Change (API Modification)"
echo "---------------------------------------------"
curl -s -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "change_type": "api_modification",
    "target_service": "log-enrichment",
    "change_description": "Add new enrichment field"
  }' | python -m json.tool

echo ""
echo ""
echo "Test 3: High Risk Change (Infrastructure)"
echo "-----------------------------------------"
curl -s -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "change_type": "infrastructure",
    "target_service": "rabbitmq-cluster",
    "change_description": "Upgrade RabbitMQ to new major version"
  }' | python -m json.tool

echo ""
echo ""
echo "✅ Demo completed!"
echo "🌐 View results in dashboard: http://localhost:3000"
EOF

chmod +x demo.sh

# Create README
cat > README.md << 'EOF'
# Day 164: Change Impact Analysis System

Predict the impact of changes across your distributed log processing system.

## Quick Start

```bash
./start.sh    # Start all services
./demo.sh     # Run demonstration
./stop.sh     # Stop all services
```

## Docker Deployment

```bash
docker-compose up --build
```

## Manual Setup

```bash
python3.11 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python -m pytest tests/ -v
python src/api_server.py
```

## Access

- API: http://localhost:8000
- Docs: http://localhost:8000/docs
- Dashboard: http://localhost:3000

## Testing

```bash
# Run tests
python -m pytest tests/ -v

# Test API
curl http://localhost:8000/health
curl http://localhost:8000/services

# Analyze change
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{"change_type": "api_modification", "target_service": "log-enrichment", "change_description": "Add field"}'
```
EOF

echo ""
echo "✅ Project structure created successfully!"
echo ""
echo "📁 Project: ${PROJECT_NAME}"
echo ""
echo "🚀 Quick Start:"
echo "   cd ${PROJECT_NAME}"
echo "   ./start.sh"
echo ""
echo "📖 Full Documentation: README.md"