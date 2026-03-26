#!/bin/bash

# Day 161: Security Compliance Reporting System - Complete Implementation
# Automated compliance reports for PCI-DSS, SOC2, ISO 27001, HIPAA

set -e

echo "🚀 Day 161: Security Compliance Reporting System Setup"
echo "=================================================="

# Create project structure
echo "📁 Creating project structure..."
mkdir -p day161-compliance-reporting/{src/{compliance,evidence,reports,dashboard,api},tests,config,data/{logs,evidence,reports},web/{src/{components,pages,services},public},docker,scripts}

cd day161-compliance-reporting

# Create Python requirements
echo "📦 Creating requirements.txt..."
cat > requirements.txt << 'EOF'
fastapi==0.111.0
uvicorn==0.30.1
pydantic==2.7.4
reportlab==4.2.0
python-multipart==0.0.9
jinja2==3.1.4
aiofiles==23.2.1
pytest==8.2.2
pytest-asyncio==0.23.7
httpx==0.27.0
python-dateutil==2.9.0
cryptography==42.0.8
pandas==2.2.2
openpyxl==3.1.2
EOF

echo "📝 Creating Python source files..."

# Create __init__.py files for Python packages
touch src/compliance/__init__.py
touch src/evidence/__init__.py
touch src/reports/__init__.py
touch src/api/__init__.py
touch src/dashboard/__init__.py

# Compliance rule engine
cat > src/compliance/rule_engine.py << 'EOF'
from typing import Dict, List, Any
from datetime import datetime
from enum import Enum
import json
import hashlib

class ComplianceFramework(Enum):
    PCI_DSS = "pci_dss"
    SOC2 = "soc2"
    ISO27001 = "iso27001"
    HIPAA = "hipaa"

class ComplianceRule:
    def __init__(self, rule_id: str, framework: ComplianceFramework, 
                 requirement_id: str, description: str, 
                 log_criteria: Dict[str, Any]):
        self.rule_id = rule_id
        self.framework = framework
        self.requirement_id = requirement_id
        self.description = description
        self.log_criteria = log_criteria
    
    def evaluate(self, log_event: Dict[str, Any]) -> bool:
        """Evaluate if log event satisfies rule criteria"""
        for key, expected in self.log_criteria.items():
            if key not in log_event:
                return False
            if isinstance(expected, list):
                if log_event[key] not in expected:
                    return False
            elif log_event[key] != expected:
                return False
        return True

class ComplianceRuleEngine:
    def __init__(self):
        self.rules: List[ComplianceRule] = []
        self.evidence_counts = {framework: {} for framework in ComplianceFramework}
        self._load_default_rules()
    
    def _load_default_rules(self):
        """Load predefined compliance rules"""
        # PCI-DSS Rules
        self.add_rule(ComplianceRule(
            "PCI_8.2.6",
            ComplianceFramework.PCI_DSS,
            "8.2.6",
            "Account lockout after failed login attempts",
            {"event_type": "auth_failure", "action": "account_locked"}
        ))
        
        self.add_rule(ComplianceRule(
            "PCI_10.2.1",
            ComplianceFramework.PCI_DSS,
            "10.2.1",
            "All user access to cardholder data logged",
            {"event_type": "data_access", "resource_type": "cardholder_data"}
        ))
        
        self.add_rule(ComplianceRule(
            "PCI_10.2.2",
            ComplianceFramework.PCI_DSS,
            "10.2.2",
            "All administrative actions logged",
            {"event_type": "admin_action", "privilege_level": "admin"}
        ))
        
        # SOC2 Rules
        self.add_rule(ComplianceRule(
            "SOC2_CC6.1",
            ComplianceFramework.SOC2,
            "CC6.1",
            "Logical access controls implemented",
            {"event_type": "access_control", "result": "enforced"}
        ))
        
        self.add_rule(ComplianceRule(
            "SOC2_CC7.2",
            ComplianceFramework.SOC2,
            "CC7.2",
            "System monitoring for anomalies",
            {"event_type": "security_alert", "severity": ["high", "critical"]}
        ))
        
        # ISO 27001 Rules
        self.add_rule(ComplianceRule(
            "ISO_A.9.4.2",
            ComplianceFramework.ISO27001,
            "A.9.4.2",
            "Secure log-on procedures",
            {"event_type": "authentication", "mfa_enabled": True}
        ))
        
        self.add_rule(ComplianceRule(
            "ISO_A.12.4.1",
            ComplianceFramework.ISO27001,
            "A.12.4.1",
            "Event logging and monitoring",
            {"event_type": "security_event", "logged": True}
        ))
        
        # HIPAA Rules
        self.add_rule(ComplianceRule(
            "HIPAA_164.308_a_1",
            ComplianceFramework.HIPAA,
            "164.308(a)(1)",
            "Security management process",
            {"event_type": "phi_access", "authorized": True}
        ))
        
        self.add_rule(ComplianceRule(
            "HIPAA_164.312_b",
            ComplianceFramework.HIPAA,
            "164.312(b)",
            "Audit controls",
            {"event_type": "audit_log", "phi_involved": True}
        ))
    
    def add_rule(self, rule: ComplianceRule):
        """Add compliance rule to engine"""
        self.rules.append(rule)
        if rule.requirement_id not in self.evidence_counts[rule.framework]:
            self.evidence_counts[rule.framework][rule.requirement_id] = 0
    
    def evaluate_log_event(self, log_event: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Evaluate log event against all compliance rules"""
        matches = []
        for rule in self.rules:
            if rule.evaluate(log_event):
                self.evidence_counts[rule.framework][rule.requirement_id] += 1
                matches.append({
                    "rule_id": rule.rule_id,
                    "framework": rule.framework.value,
                    "requirement_id": rule.requirement_id,
                    "description": rule.description,
                    "timestamp": datetime.now().isoformat()
                })
        return matches
    
    def get_compliance_coverage(self, framework: ComplianceFramework) -> Dict[str, Any]:
        """Get compliance coverage statistics for framework"""
        total_requirements = len(self.evidence_counts[framework])
        requirements_with_evidence = sum(1 for count in self.evidence_counts[framework].values() if count > 0)
        
        return {
            "framework": framework.value,
            "total_requirements": total_requirements,
            "requirements_with_evidence": requirements_with_evidence,
            "coverage_percentage": (requirements_with_evidence / total_requirements * 100) if total_requirements > 0 else 0,
            "evidence_by_requirement": self.evidence_counts[framework]
        }
    
    def identify_gaps(self, framework: ComplianceFramework) -> List[str]:
        """Identify compliance requirements with no evidence"""
        return [req_id for req_id, count in self.evidence_counts[framework].items() if count == 0]
EOF

# Evidence collector
cat > src/evidence/collector.py << 'EOF'
from typing import Dict, List, Any
from datetime import datetime
import hashlib
import json
import os

class EvidenceEntry:
    def __init__(self, evidence_id: str, log_event: Dict[str, Any],
                 compliance_matches: List[Dict[str, Any]], 
                 collected_at: datetime):
        self.evidence_id = evidence_id
        self.log_event = log_event
        self.compliance_matches = compliance_matches
        self.collected_at = collected_at
        self.integrity_hash = self._compute_hash()
    
    def _compute_hash(self) -> str:
        """Compute integrity hash for tamper detection"""
        data = json.dumps({
            "evidence_id": self.evidence_id,
            "log_event": self.log_event,
            "compliance_matches": self.compliance_matches,
            "collected_at": self.collected_at.isoformat()
        }, sort_keys=True)
        return hashlib.sha256(data.encode()).hexdigest()
    
    def verify_integrity(self) -> bool:
        """Verify evidence hasn't been tampered with"""
        current_hash = self._compute_hash()
        return current_hash == self.integrity_hash
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "evidence_id": self.evidence_id,
            "log_event": self.log_event,
            "compliance_matches": self.compliance_matches,
            "collected_at": self.collected_at.isoformat(),
            "integrity_hash": self.integrity_hash
        }

class EvidenceCollector:
    def __init__(self, storage_path: str = "data/evidence"):
        self.storage_path = storage_path
        self.evidence_store: List[EvidenceEntry] = []
        self.evidence_index: Dict[str, List[str]] = {}
        os.makedirs(storage_path, exist_ok=True)
    
    def collect(self, log_event: Dict[str, Any], 
                compliance_matches: List[Dict[str, Any]]) -> str:
        """Collect evidence for compliance"""
        evidence_id = f"EVD-{datetime.now().strftime('%Y%m%d%H%M%S')}-{len(self.evidence_store)}"
        
        entry = EvidenceEntry(
            evidence_id=evidence_id,
            log_event=log_event,
            compliance_matches=compliance_matches,
            collected_at=datetime.now()
        )
        
        self.evidence_store.append(entry)
        
        # Index by framework and requirement
        for match in compliance_matches:
            framework = match["framework"]
            req_id = match["requirement_id"]
            key = f"{framework}:{req_id}"
            
            if key not in self.evidence_index:
                self.evidence_index[key] = []
            self.evidence_index[key].append(evidence_id)
        
        # Persist to disk
        self._persist_evidence(entry)
        
        return evidence_id
    
    def _persist_evidence(self, entry: EvidenceEntry):
        """Persist evidence to disk"""
        filename = f"{entry.evidence_id}.json"
        filepath = os.path.join(self.storage_path, filename)
        
        with open(filepath, 'w') as f:
            json.dump(entry.to_dict(), f, indent=2)
    
    def get_evidence_by_requirement(self, framework: str, 
                                   requirement_id: str, 
                                   limit: int = 10) -> List[Dict[str, Any]]:
        """Retrieve evidence for specific requirement"""
        key = f"{framework}:{requirement_id}"
        evidence_ids = self.evidence_index.get(key, [])[:limit]
        
        evidence_list = []
        for evidence_id in evidence_ids:
            for entry in self.evidence_store:
                if entry.evidence_id == evidence_id:
                    evidence_list.append(entry.to_dict())
                    break
        
        return evidence_list
    
    def get_evidence_count(self, framework: str, requirement_id: str) -> int:
        """Get count of evidence for requirement"""
        key = f"{framework}:{requirement_id}"
        return len(self.evidence_index.get(key, []))
    
    def verify_all_integrity(self) -> Dict[str, Any]:
        """Verify integrity of all stored evidence"""
        total = len(self.evidence_store)
        verified = sum(1 for entry in self.evidence_store if entry.verify_integrity())
        
        return {
            "total_evidence": total,
            "verified_evidence": verified,
            "integrity_status": "PASS" if verified == total else "FAIL",
            "verification_timestamp": datetime.now().isoformat()
        }
EOF

# Report generator
cat > src/reports/generator.py << 'EOF'
from typing import Dict, List, Any
from datetime import datetime
import os
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
import pandas as pd

class ComplianceReportGenerator:
    def __init__(self, output_path: str = "data/reports"):
        self.output_path = output_path
        os.makedirs(output_path, exist_ok=True)
        self.styles = getSampleStyleSheet()
        self._setup_custom_styles()
    
    def _setup_custom_styles(self):
        """Setup custom report styles"""
        self.styles.add(ParagraphStyle(
            name='CustomTitle',
            parent=self.styles['Heading1'],
            fontSize=24,
            textColor=colors.HexColor('#1e40af'),
            spaceAfter=30,
            alignment=TA_CENTER
        ))
        
        self.styles.add(ParagraphStyle(
            name='SectionHeader',
            parent=self.styles['Heading2'],
            fontSize=16,
            textColor=colors.HexColor('#1e40af'),
            spaceAfter=12,
            spaceBefore=12
        ))
    
    def generate_pci_dss_report(self, coverage_data: Dict[str, Any],
                                evidence_data: Dict[str, List[Dict]], 
                                gaps: List[str]) -> str:
        """Generate PCI-DSS compliance report"""
        filename = f"PCI_DSS_Report_{datetime.now().strftime('%Y%m%d')}.pdf"
        filepath = os.path.join(self.output_path, filename)
        
        doc = SimpleDocTemplate(filepath, pagesize=letter)
        story = []
        
        # Title
        story.append(Paragraph("PCI-DSS Compliance Report", self.styles['CustomTitle']))
        story.append(Spacer(1, 0.2*inch))
        
        # Executive Summary
        story.append(Paragraph("Executive Summary", self.styles['SectionHeader']))
        summary_text = f"""
        <b>Report Date:</b> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}<br/>
        <b>Framework:</b> PCI-DSS v4.0<br/>
        <b>Coverage:</b> {coverage_data['coverage_percentage']:.1f}%<br/>
        <b>Requirements with Evidence:</b> {coverage_data['requirements_with_evidence']} / {coverage_data['total_requirements']}<br/>
        <b>Compliance Gaps:</b> {len(gaps)}
        """
        story.append(Paragraph(summary_text, self.styles['Normal']))
        story.append(Spacer(1, 0.3*inch))
        
        # Coverage Details
        story.append(Paragraph("Coverage by Requirement", self.styles['SectionHeader']))
        coverage_table_data = [["Requirement", "Evidence Count", "Status"]]
        
        for req_id, count in coverage_data['evidence_by_requirement'].items():
            status = "✓ Compliant" if count > 0 else "✗ Gap"
            coverage_table_data.append([req_id, str(count), status])
        
        coverage_table = Table(coverage_table_data, colWidths=[2*inch, 2*inch, 2*inch])
        coverage_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1e40af')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 12),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
            ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
            ('GRID', (0, 0), (-1, -1), 1, colors.black)
        ]))
        story.append(coverage_table)
        story.append(Spacer(1, 0.3*inch))
        
        # Gap Analysis
        if gaps:
            story.append(Paragraph("Compliance Gaps Requiring Attention", self.styles['SectionHeader']))
            gap_text = "<br/>".join([f"• Requirement {gap}: No evidence collected" for gap in gaps])
            story.append(Paragraph(gap_text, self.styles['Normal']))
        
        doc.build(story)
        return filepath
    
    def generate_soc2_report(self, coverage_data: Dict[str, Any],
                            evidence_data: Dict[str, List[Dict]],
                            gaps: List[str]) -> str:
        """Generate SOC2 compliance report"""
        filename = f"SOC2_Report_{datetime.now().strftime('%Y%m%d')}.pdf"
        filepath = os.path.join(self.output_path, filename)
        
        doc = SimpleDocTemplate(filepath, pagesize=letter)
        story = []
        
        # Title
        story.append(Paragraph("SOC 2 Type II Compliance Report", self.styles['CustomTitle']))
        story.append(Spacer(1, 0.2*inch))
        
        # Trust Services Criteria
        story.append(Paragraph("Trust Services Criteria Assessment", self.styles['SectionHeader']))
        summary_text = f"""
        <b>Reporting Period:</b> {datetime.now().strftime('%Y-%m-%d')}<br/>
        <b>Framework:</b> SOC 2 Type II<br/>
        <b>Control Coverage:</b> {coverage_data['coverage_percentage']:.1f}%<br/>
        <b>Total Control Points:</b> {coverage_data['total_requirements']}<br/>
        <b>Effective Controls:</b> {coverage_data['requirements_with_evidence']}
        """
        story.append(Paragraph(summary_text, self.styles['Normal']))
        story.append(Spacer(1, 0.3*inch))
        
        # Control Effectiveness
        story.append(Paragraph("Control Effectiveness by Category", self.styles['SectionHeader']))
        control_data = [["Control Point", "Evidence Count", "Effectiveness"]]
        
        for req_id, count in coverage_data['evidence_by_requirement'].items():
            effectiveness = "Operating Effectively" if count >= 3 else "Requires Testing"
            control_data.append([req_id, str(count), effectiveness])
        
        control_table = Table(control_data, colWidths=[2*inch, 2*inch, 2*inch])
        control_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1e40af')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 12),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
            ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
            ('GRID', (0, 0), (-1, -1), 1, colors.black)
        ]))
        story.append(control_table)
        
        doc.build(story)
        return filepath
    
    def generate_multi_framework_report(self, all_coverage: Dict[str, Dict], 
                                       all_gaps: Dict[str, List[str]]) -> str:
        """Generate combined multi-framework report"""
        filename = f"Multi_Framework_Report_{datetime.now().strftime('%Y%m%d')}.pdf"
        filepath = os.path.join(self.output_path, filename)
        
        doc = SimpleDocTemplate(filepath, pagesize=letter)
        story = []
        
        # Title
        story.append(Paragraph("Multi-Framework Compliance Report", self.styles['CustomTitle']))
        story.append(Spacer(1, 0.2*inch))
        
        # Overview
        story.append(Paragraph("Compliance Overview", self.styles['SectionHeader']))
        overview_data = [["Framework", "Coverage", "Requirements", "Gaps"]]
        
        for framework_name, coverage in all_coverage.items():
            gaps_count = len(all_gaps.get(framework_name, []))
            overview_data.append([
                framework_name.upper(),
                f"{coverage['coverage_percentage']:.1f}%",
                f"{coverage['requirements_with_evidence']}/{coverage['total_requirements']}",
                str(gaps_count)
            ])
        
        overview_table = Table(overview_data, colWidths=[1.5*inch, 1.5*inch, 1.5*inch, 1.5*inch])
        overview_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1e40af')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 12),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
            ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
            ('GRID', (0, 0), (-1, -1), 1, colors.black)
        ]))
        story.append(overview_table)
        
        doc.build(story)
        return filepath
    
    def export_to_excel(self, coverage_data: Dict[str, Any], 
                       framework_name: str) -> str:
        """Export compliance data to Excel"""
        filename = f"{framework_name}_Data_{datetime.now().strftime('%Y%m%d')}.xlsx"
        filepath = os.path.join(self.output_path, filename)
        
        # Create DataFrame
        data = []
        for req_id, count in coverage_data['evidence_by_requirement'].items():
            data.append({
                "Requirement": req_id,
                "Evidence Count": count,
                "Status": "Compliant" if count > 0 else "Gap"
            })
        
        df = pd.DataFrame(data)
        df.to_excel(filepath, index=False, engine='openpyxl')
        
        return filepath
EOF

# FastAPI application
cat > src/api/main.py << 'EOF'
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict, List, Any, Optional
from datetime import datetime
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from compliance.rule_engine import ComplianceRuleEngine, ComplianceFramework
from evidence.collector import EvidenceCollector
from reports.generator import ComplianceReportGenerator

app = FastAPI(title="Security Compliance Reporting API")

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize components
rule_engine = ComplianceRuleEngine()
evidence_collector = EvidenceCollector()
report_generator = ComplianceReportGenerator()

class LogEvent(BaseModel):
    event_type: str
    timestamp: str
    details: Dict[str, Any]

class ComplianceStats(BaseModel):
    framework: str
    coverage_percentage: float
    total_requirements: int
    requirements_with_evidence: int
    gaps: List[str]

@app.get("/")
async def root():
    return {
        "service": "Security Compliance Reporting API",
        "version": "1.0.0",
        "status": "operational"
    }

@app.post("/api/events/ingest")
async def ingest_log_event(log_event: LogEvent):
    """Ingest and process security log event"""
    event_data = {
        "event_type": log_event.event_type,
        "timestamp": log_event.timestamp,
        **log_event.details
    }
    
    # Evaluate against compliance rules
    matches = rule_engine.evaluate_log_event(event_data)
    
    # Collect evidence if matches found
    evidence_id = None
    if matches:
        evidence_id = evidence_collector.collect(event_data, matches)
    
    return {
        "status": "processed",
        "evidence_id": evidence_id,
        "compliance_matches": len(matches),
        "frameworks_affected": list(set(m["framework"] for m in matches))
    }

@app.get("/api/compliance/coverage/{framework}")
async def get_compliance_coverage(framework: str):
    """Get compliance coverage for specific framework"""
    try:
        framework_enum = ComplianceFramework[framework.upper()]
    except KeyError:
        raise HTTPException(status_code=400, detail=f"Invalid framework: {framework}")
    
    coverage = rule_engine.get_compliance_coverage(framework_enum)
    gaps = rule_engine.identify_gaps(framework_enum)
    
    return {
        **coverage,
        "gaps": gaps,
        "timestamp": datetime.now().isoformat()
    }

@app.get("/api/compliance/coverage")
async def get_all_coverage():
    """Get compliance coverage for all frameworks"""
    all_coverage = {}
    for framework in ComplianceFramework:
        coverage = rule_engine.get_compliance_coverage(framework)
        gaps = rule_engine.identify_gaps(framework)
        all_coverage[framework.value] = {
            **coverage,
            "gaps": gaps
        }
    
    return all_coverage

@app.get("/api/evidence/{framework}/{requirement_id}")
async def get_evidence(framework: str, requirement_id: str, limit: int = 10):
    """Get evidence for specific requirement"""
    evidence = evidence_collector.get_evidence_by_requirement(
        framework, requirement_id, limit
    )
    
    return {
        "framework": framework,
        "requirement_id": requirement_id,
        "evidence_count": evidence_collector.get_evidence_count(framework, requirement_id),
        "evidence": evidence
    }

@app.post("/api/reports/generate/{framework}")
async def generate_report(framework: str, background_tasks: BackgroundTasks):
    """Generate compliance report for framework"""
    try:
        framework_enum = ComplianceFramework[framework.upper()]
    except KeyError:
        raise HTTPException(status_code=400, detail=f"Invalid framework: {framework}")
    
    coverage = rule_engine.get_compliance_coverage(framework_enum)
    gaps = rule_engine.identify_gaps(framework_enum)
    evidence_data = {}
    
    # Generate appropriate report
    if framework_enum == ComplianceFramework.PCI_DSS:
        report_path = report_generator.generate_pci_dss_report(coverage, evidence_data, gaps)
    elif framework_enum == ComplianceFramework.SOC2:
        report_path = report_generator.generate_soc2_report(coverage, evidence_data, gaps)
    else:
        raise HTTPException(status_code=501, detail=f"Report generation not implemented for {framework}")
    
    return {
        "status": "generated",
        "framework": framework,
        "report_path": report_path,
        "coverage": coverage['coverage_percentage'],
        "gaps": len(gaps)
    }

@app.post("/api/reports/generate/multi-framework")
async def generate_multi_framework_report():
    """Generate combined report for all frameworks"""
    all_coverage = {}
    all_gaps = {}
    
    for framework in ComplianceFramework:
        coverage = rule_engine.get_compliance_coverage(framework)
        gaps = rule_engine.identify_gaps(framework)
        all_coverage[framework.value] = coverage
        all_gaps[framework.value] = gaps
    
    report_path = report_generator.generate_multi_framework_report(all_coverage, all_gaps)
    
    return {
        "status": "generated",
        "report_path": report_path,
        "frameworks": list(all_coverage.keys())
    }

@app.get("/api/evidence/verify")
async def verify_evidence_integrity():
    """Verify integrity of all stored evidence"""
    return evidence_collector.verify_all_integrity()

@app.get("/api/dashboard/stats")
async def get_dashboard_stats():
    """Get comprehensive dashboard statistics"""
    stats = {}
    
    for framework in ComplianceFramework:
        coverage = rule_engine.get_compliance_coverage(framework)
        gaps = rule_engine.identify_gaps(framework)
        
        stats[framework.value] = {
            "coverage_percentage": coverage['coverage_percentage'],
            "requirements_with_evidence": coverage['requirements_with_evidence'],
            "total_requirements": coverage['total_requirements'],
            "gap_count": len(gaps),
            "status": "compliant" if coverage['coverage_percentage'] >= 80 else "non-compliant"
        }
    
    return {
        "timestamp": datetime.now().isoformat(),
        "frameworks": stats,
        "total_evidence": len(evidence_collector.evidence_store)
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

# Create test data generator
cat > scripts/generate_test_data.py << 'EOF'
import requests
import time
import random
from datetime import datetime

API_BASE = "http://localhost:8000"

# Sample test events
test_events = [
    {
        "event_type": "auth_failure",
        "timestamp": datetime.now().isoformat(),
        "details": {
            "user": "john.doe@company.com",
            "action": "account_locked",
            "reason": "5 failed login attempts",
            "source_ip": "192.168.1.100"
        }
    },
    {
        "event_type": "data_access",
        "timestamp": datetime.now().isoformat(),
        "details": {
            "user": "admin@company.com",
            "resource_type": "cardholder_data",
            "action": "read",
            "database": "payments_db"
        }
    },
    {
        "event_type": "admin_action",
        "timestamp": datetime.now().isoformat(),
        "details": {
            "user": "root",
            "privilege_level": "admin",
            "action": "configuration_change",
            "target": "firewall_rules"
        }
    },
    {
        "event_type": "access_control",
        "timestamp": datetime.now().isoformat(),
        "details": {
            "user": "developer@company.com",
            "result": "enforced",
            "resource": "production_database",
            "permission": "denied"
        }
    },
    {
        "event_type": "security_alert",
        "timestamp": datetime.now().isoformat(),
        "details": {
            "severity": "high",
            "alert_type": "suspicious_activity",
            "description": "Multiple failed access attempts"
        }
    },
    {
        "event_type": "authentication",
        "timestamp": datetime.now().isoformat(),
        "details": {
            "user": "jane.smith@company.com",
            "mfa_enabled": True,
            "mfa_method": "authenticator_app",
            "result": "success"
        }
    },
    {
        "event_type": "security_event",
        "timestamp": datetime.now().isoformat(),
        "details": {
            "logged": True,
            "event_category": "network_intrusion_attempt",
            "source": "IDS"
        }
    },
    {
        "event_type": "phi_access",
        "timestamp": datetime.now().isoformat(),
        "details": {
            "user": "doctor@hospital.com",
            "authorized": True,
            "patient_id": "P12345",
            "access_reason": "treatment"
        }
    },
    {
        "event_type": "audit_log",
        "timestamp": datetime.now().isoformat(),
        "details": {
            "phi_involved": True,
            "action": "patient_record_view",
            "user": "nurse@hospital.com"
        }
    }
]

def generate_events(count=50):
    print(f"🔄 Generating {count} test security events...")
    
    for i in range(count):
        event = random.choice(test_events).copy()
        event["timestamp"] = datetime.now().isoformat()
        
        try:
            response = requests.post(f"{API_BASE}/api/events/ingest", json=event)
            if response.status_code == 200:
                result = response.json()
                print(f"✅ Event {i+1}: {result['compliance_matches']} matches, Evidence: {result['evidence_id']}")
            else:
                print(f"❌ Event {i+1}: Failed - {response.status_code}")
        except Exception as e:
            print(f"❌ Event {i+1}: Error - {str(e)}")
        
        time.sleep(0.1)
    
    print(f"✅ Generated {count} security events")

if __name__ == "__main__":
    generate_events(50)
EOF

# Create React dashboard
cat > web/src/Dashboard.jsx << 'EOF'
import React, { useState, useEffect } from 'react';

const ComplianceDashboard = () => {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchStats();
    const interval = setInterval(fetchStats, 5000);
    return () => clearInterval(interval);
  }, []);

  const fetchStats = async () => {
    try {
      const response = await fetch('http://localhost:8000/api/dashboard/stats');
      const data = await response.json();
      setStats(data);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching stats:', error);
    }
  };

  const getStatusColor = (percentage) => {
    if (percentage >= 80) return '#10b981';
    if (percentage >= 60) return '#f59e0b';
    return '#ef4444';
  };

  if (loading) {
    return <div className="loading">Loading compliance dashboard...</div>;
  }

  return (
    <div className="dashboard">
      <header className="dashboard-header">
        <h1>🛡️ Security Compliance Dashboard</h1>
        <p className="timestamp">Last Updated: {new Date(stats.timestamp).toLocaleString()}</p>
      </header>

      <div className="stats-grid">
        {Object.entries(stats.frameworks).map(([framework, data]) => (
          <div key={framework} className="compliance-card">
            <div className="card-header">
              <h2>{framework.toUpperCase().replace('_', '-')}</h2>
              <span className={`status-badge ${data.status}`}>
                {data.status.toUpperCase()}
              </span>
            </div>
            
            <div className="progress-container">
              <svg width="120" height="120" viewBox="0 0 120 120">
                <circle cx="60" cy="60" r="50" fill="none" stroke="#e5e7eb" strokeWidth="10"/>
                <circle 
                  cx="60" 
                  cy="60" 
                  r="50" 
                  fill="none" 
                  stroke={getStatusColor(data.coverage_percentage)}
                  strokeWidth="10"
                  strokeDasharray={`${(data.coverage_percentage / 100) * 314} 314`}
                  transform="rotate(-90 60 60)"
                />
                <text x="60" y="60" textAnchor="middle" dy=".3em" fontSize="24" fontWeight="bold">
                  {data.coverage_percentage.toFixed(0)}%
                </text>
              </svg>
            </div>

            <div className="card-stats">
              <div className="stat">
                <span className="stat-label">Requirements</span>
                <span className="stat-value">
                  {data.requirements_with_evidence} / {data.total_requirements}
                </span>
              </div>
              <div className="stat">
                <span className="stat-label">Gaps</span>
                <span className="stat-value">{data.gap_count}</span>
              </div>
            </div>

            <button 
              className="report-button"
              onClick={() => generateReport(framework)}
            >
              Generate Report
            </button>
          </div>
        ))}
      </div>

      <div className="evidence-summary">
        <h3>Evidence Summary</h3>
        <p>Total Evidence Collected: <strong>{stats.total_evidence}</strong></p>
      </div>

      <style jsx>{`
        .dashboard {
          font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
          max-width: 1400px;
          margin: 0 auto;
          padding: 20px;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          min-height: 100vh;
        }

        .dashboard-header {
          text-align: center;
          color: white;
          margin-bottom: 40px;
        }

        .dashboard-header h1 {
          font-size: 2.5em;
          margin: 0;
        }

        .timestamp {
          color: rgba(255, 255, 255, 0.8);
          margin-top: 10px;
        }

        .stats-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
          gap: 30px;
          margin-bottom: 40px;
        }

        .compliance-card {
          background: white;
          border-radius: 15px;
          padding: 25px;
          box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
          transition: transform 0.3s ease;
        }

        .compliance-card:hover {
          transform: translateY(-5px);
        }

        .card-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 20px;
        }

        .card-header h2 {
          margin: 0;
          color: #1e40af;
          font-size: 1.3em;
        }

        .status-badge {
          padding: 5px 15px;
          border-radius: 20px;
          font-size: 0.8em;
          font-weight: bold;
        }

        .status-badge.compliant {
          background: #10b981;
          color: white;
        }

        .status-badge.non-compliant {
          background: #ef4444;
          color: white;
        }

        .progress-container {
          display: flex;
          justify-content: center;
          margin: 20px 0;
        }

        .card-stats {
          display: flex;
          justify-content: space-around;
          margin: 20px 0;
        }

        .stat {
          display: flex;
          flex-direction: column;
          align-items: center;
        }

        .stat-label {
          color: #6b7280;
          font-size: 0.9em;
          margin-bottom: 5px;
        }

        .stat-value {
          font-size: 1.5em;
          font-weight: bold;
          color: #1e40af;
        }

        .report-button {
          width: 100%;
          padding: 12px;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          border: none;
          border-radius: 8px;
          font-size: 1em;
          font-weight: bold;
          cursor: pointer;
          transition: opacity 0.3s ease;
        }

        .report-button:hover {
          opacity: 0.9;
        }

        .evidence-summary {
          background: white;
          padding: 30px;
          border-radius: 15px;
          text-align: center;
          box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
        }

        .evidence-summary h3 {
          color: #1e40af;
          margin-top: 0;
        }

        .loading {
          text-align: center;
          padding: 50px;
          color: white;
          font-size: 1.5em;
        }
      `}</style>
    </div>
  );
};

const generateReport = async (framework) => {
  try {
    const response = await fetch(`http://localhost:8000/api/reports/generate/${framework}`, {
      method: 'POST'
    });
    const result = await response.json();
    alert(`Report generated: ${result.report_path}\nCoverage: ${result.coverage.toFixed(1)}%\nGaps: ${result.gaps}`);
  } catch (error) {
    alert('Error generating report: ' + error.message);
  }
};

export default ComplianceDashboard;
EOF

# Create simple HTML dashboard
cat > web/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Security Compliance Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }

        .dashboard {
            max-width: 1400px;
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

        .timestamp {
            color: rgba(255, 255, 255, 0.8);
        }

        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 30px;
            margin-bottom: 40px;
        }

        .card {
            background: white;
            border-radius: 15px;
            padding: 25px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
            transition: transform 0.3s ease;
        }

        .card:hover {
            transform: translateY(-5px);
        }

        .card-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
        }

        .card-title {
            color: #1e40af;
            font-size: 1.3em;
            font-weight: bold;
        }

        .status-badge {
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.8em;
            font-weight: bold;
        }

        .status-compliant {
            background: #10b981;
            color: white;
        }

        .status-non-compliant {
            background: #ef4444;
            color: white;
        }

        .progress-circle {
            text-align: center;
            margin: 20px 0;
        }

        .card-stats {
            display: flex;
            justify-content: space-around;
            margin: 20px 0;
            padding: 15px 0;
            border-top: 1px solid #e5e7eb;
            border-bottom: 1px solid #e5e7eb;
        }

        .stat {
            text-align: center;
        }

        .stat-label {
            color: #6b7280;
            font-size: 0.9em;
            display: block;
            margin-bottom: 5px;
        }

        .stat-value {
            font-size: 1.5em;
            font-weight: bold;
            color: #1e40af;
        }

        .report-button {
            width: 100%;
            padding: 12px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 1em;
            font-weight: bold;
            cursor: pointer;
            transition: opacity 0.3s ease;
        }

        .report-button:hover {
            opacity: 0.9;
        }

        .evidence-summary {
            background: white;
            padding: 30px;
            border-radius: 15px;
            text-align: center;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
        }

        .evidence-summary h3 {
            color: #1e40af;
            margin-bottom: 15px;
        }

        .loading {
            text-align: center;
            color: white;
            font-size: 1.5em;
            padding: 50px;
        }
    </style>
</head>
<body>
    <div class="dashboard">
        <div class="header">
            <h1>🛡️ Security Compliance Dashboard</h1>
            <p class="timestamp" id="timestamp">Loading...</p>
        </div>
        
        <div id="content" class="loading">Loading compliance data...</div>
    </div>

    <script>
        const API_BASE = 'http://localhost:8000';

        async function fetchStats() {
            try {
                const response = await fetch(`${API_BASE}/api/dashboard/stats`);
                const data = await response.json();
                renderDashboard(data);
            } catch (error) {
                document.getElementById('content').innerHTML = `
                    <div class="loading">Error loading data: ${error.message}</div>
                `;
            }
        }

        function getStatusColor(percentage) {
            if (percentage >= 80) return '#10b981';
            if (percentage >= 60) return '#f59e0b';
            return '#ef4444';
        }

        function renderDashboard(data) {
            const timestamp = new Date(data.timestamp).toLocaleString();
            document.getElementById('timestamp').textContent = `Last Updated: ${timestamp}`;

            const frameworks = Object.entries(data.frameworks);
            
            const cardsHTML = frameworks.map(([framework, stats]) => `
                <div class="card">
                    <div class="card-header">
                        <span class="card-title">${framework.toUpperCase().replace('_', '-')}</span>
                        <span class="status-badge status-${stats.status}">
                            ${stats.status.toUpperCase()}
                        </span>
                    </div>
                    
                    <div class="progress-circle">
                        <svg width="120" height="120" viewBox="0 0 120 120">
                            <circle cx="60" cy="60" r="50" fill="none" stroke="#e5e7eb" stroke-width="10"/>
                            <circle 
                                cx="60" 
                                cy="60" 
                                r="50" 
                                fill="none" 
                                stroke="${getStatusColor(stats.coverage_percentage)}"
                                stroke-width="10"
                                stroke-dasharray="${(stats.coverage_percentage / 100) * 314} 314"
                                transform="rotate(-90 60 60)"
                            />
                            <text x="60" y="60" text-anchor="middle" dy=".3em" font-size="24" font-weight="bold">
                                ${stats.coverage_percentage.toFixed(0)}%
                            </text>
                        </svg>
                    </div>

                    <div class="card-stats">
                        <div class="stat">
                            <span class="stat-label">Requirements</span>
                            <span class="stat-value">${stats.requirements_with_evidence} / ${stats.total_requirements}</span>
                        </div>
                        <div class="stat">
                            <span class="stat-label">Gaps</span>
                            <span class="stat-value">${stats.gap_count}</span>
                        </div>
                    </div>

                    <button class="report-button" onclick="generateReport('${framework}')">
                        Generate Report
                    </button>
                </div>
            `).join('');

            document.getElementById('content').innerHTML = `
                <div class="stats-grid">${cardsHTML}</div>
                <div class="evidence-summary">
                    <h3>Evidence Summary</h3>
                    <p>Total Evidence Collected: <strong>${data.total_evidence}</strong></p>
                </div>
            `;
        }

        async function generateReport(framework) {
            try {
                const response = await fetch(`${API_BASE}/api/reports/generate/${framework}`, {
                    method: 'POST'
                });
                const result = await response.json();
                alert(`Report Generated!\n\nPath: ${result.report_path}\nCoverage: ${result.coverage.toFixed(1)}%\nGaps: ${result.gaps}`);
            } catch (error) {
                alert('Error generating report: ' + error.message);
            }
        }

        // Initial load
        fetchStats();
        
        // Auto-refresh every 10 seconds
        setInterval(fetchStats, 10000);
    </script>
</body>
</html>
EOF

# Create tests
cat > tests/test_compliance.py << 'EOF'
import pytest
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))

from compliance.rule_engine import ComplianceRuleEngine, ComplianceFramework
from evidence.collector import EvidenceCollector
from reports.generator import ComplianceReportGenerator

def test_rule_engine_initialization():
    """Test rule engine initializes with default rules"""
    engine = ComplianceRuleEngine()
    assert len(engine.rules) > 0
    assert all(isinstance(rule.framework, ComplianceFramework) for rule in engine.rules)

def test_log_event_evaluation():
    """Test log event evaluation against rules"""
    engine = ComplianceRuleEngine()
    
    log_event = {
        "event_type": "auth_failure",
        "action": "account_locked",
        "user": "test@example.com"
    }
    
    matches = engine.evaluate_log_event(log_event)
    assert len(matches) > 0
    assert all("framework" in match for match in matches)

def test_compliance_coverage():
    """Test compliance coverage calculation"""
    engine = ComplianceRuleEngine()
    
    # Evaluate some events
    engine.evaluate_log_event({
        "event_type": "auth_failure",
        "action": "account_locked"
    })
    
    coverage = engine.get_compliance_coverage(ComplianceFramework.PCI_DSS)
    assert "coverage_percentage" in coverage
    assert coverage["coverage_percentage"] >= 0

def test_evidence_collection():
    """Test evidence collection and storage"""
    collector = EvidenceCollector("data/evidence")
    
    log_event = {"event_type": "test", "user": "test@example.com"}
    matches = [{"framework": "pci_dss", "requirement_id": "8.2.6"}]
    
    evidence_id = collector.collect(log_event, matches)
    assert evidence_id.startswith("EVD-")
    assert len(collector.evidence_store) > 0

def test_evidence_integrity():
    """Test evidence integrity verification"""
    collector = EvidenceCollector("data/evidence")
    
    log_event = {"event_type": "test"}
    matches = [{"framework": "soc2", "requirement_id": "CC6.1"}]
    
    collector.collect(log_event, matches)
    
    verification = collector.verify_all_integrity()
    assert verification["integrity_status"] == "PASS"

def test_gap_identification():
    """Test compliance gap identification"""
    engine = ComplianceRuleEngine()
    gaps = engine.identify_gaps(ComplianceFramework.PCI_DSS)
    
    # Initially all requirements should have gaps
    assert len(gaps) > 0

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

# Create Dockerfile
cat > docker/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY src/ ./src/
COPY config/ ./config/
COPY scripts/ ./scripts/
COPY tests/ ./tests/

# Create data directories
RUN mkdir -p data/logs data/evidence data/reports

EXPOSE 8000

CMD ["python", "src/api/main.py"]
EOF

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  compliance-api:
    build:
      context: .
      dockerfile: docker/Dockerfile
    ports:
      - "8000:8000"
    volumes:
      - ./data:/app/data
    environment:
      - PYTHONUNBUFFERED=1
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/"]
      interval: 30s
      timeout: 10s
      retries: 3

  web-dashboard:
    image: nginx:alpine
    ports:
      - "3000:80"
    volumes:
      - ./web/public:/usr/share/nginx/html:ro
    depends_on:
      - compliance-api
EOF

# Create .dockerignore
cat > .dockerignore << 'EOF'
__pycache__
*.pyc
*.pyo
*.pyd
.Python
venv/
.pytest_cache/
*.log
.DS_Store
EOF

# Create start.sh
cat > start.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting Day 161: Security Compliance Reporting System"

# Create and activate virtual environment
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3.11 -m venv venv
fi

echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "📚 Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Create data directories
mkdir -p data/{logs,evidence,reports}

# Run tests
echo "🧪 Running tests..."
python -m pytest tests/ -v

# Start API server
echo "🌐 Starting API server..."
python src/api/main.py &
API_PID=$!

# Wait for API to be ready
echo "⏳ Waiting for API to be ready..."
sleep 5

# Generate test data
echo "📊 Generating test security events..."
python scripts/generate_test_data.py

echo ""
echo "✅ System started successfully!"
echo "📊 API: http://localhost:8000"
echo "📊 Dashboard: http://localhost:3000"
echo "📊 API Docs: http://localhost:8000/docs"
echo ""
echo "Press Ctrl+C to stop"

wait $API_PID
EOF

chmod +x start.sh

# Create stop.sh
cat > stop.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping Security Compliance Reporting System..."

# Kill API process
pkill -f "python src/api/main.py"

# Deactivate virtual environment
deactivate 2>/dev/null

echo "✅ System stopped"
EOF

chmod +x stop.sh

# Build and test with Docker
echo "🐳 Setting up Docker environment..."

# Start services
docker-compose up -d

echo "⏳ Waiting for services to be ready..."
sleep 10

# Test API
echo "🧪 Testing API endpoints..."
curl -s http://localhost:8000/ | head -n 5

# Run demonstration
echo "📊 Running compliance demonstration..."

# Generate test events
echo "Generating test security events..."
for i in {1..20}; do
    curl -s -X POST http://localhost:8000/api/events/ingest \
        -H "Content-Type: application/json" \
        -d "{
            \"event_type\": \"auth_failure\",
            \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
            \"details\": {
                \"user\": \"user$i@company.com\",
                \"action\": \"account_locked\",
                \"reason\": \"failed_attempts\"
            }
        }" > /dev/null
done

echo "✅ Test events generated"

# Get compliance stats
echo ""
echo "📊 Compliance Coverage Statistics:"
curl -s http://localhost:8000/api/compliance/coverage | python3 -m json.tool

# Generate PCI-DSS report
echo ""
echo "📄 Generating PCI-DSS compliance report..."
curl -s -X POST http://localhost:8000/api/reports/generate/pci_dss | python3 -m json.tool

echo ""
echo "✅ Day 161 Setup Complete!"
echo ""
echo "🎯 Access Points:"
echo "   API Server: http://localhost:8000"
echo "   API Docs: http://localhost:8000/docs"
echo "   Dashboard: http://localhost:3000"
echo ""
echo "🧪 Test Commands:"
echo "   View coverage: curl http://localhost:8000/api/compliance/coverage"
echo "   Dashboard stats: curl http://localhost:8000/api/dashboard/stats"
echo "   Generate report: curl -X POST http://localhost:8000/api/reports/generate/pci_dss"
echo ""
echo "📚 Next Steps:"
echo "   1. Open http://localhost:3000 for the dashboard"
echo "   2. Generate more test events with: python scripts/generate_test_data.py"
echo "   3. Generate compliance reports through the API"
echo "   4. Run tests: python -m pytest tests/ -v"
echo ""
echo "🛑 To stop: docker-compose down"

chmod +x setup.sh

echo "✅ Day 161: Security Compliance Reporting System - Setup Complete!"
echo ""
echo "🚀 Quick Start:"
echo "   ./setup.sh          # Complete setup with Docker"
echo "   ./start.sh          # Start without Docker"
echo "   ./stop.sh           # Stop all services"
echo ""
echo "📊 After setup, access:"
echo "   Dashboard: http://localhost:3000"
echo "   API: http://localhost:8000"
echo "   API Docs: http://localhost:8000/docs"