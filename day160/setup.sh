#!/bin/bash

# Day 160: Automated Incident Response Playbooks Implementation
# Complete setup script for security response orchestration system

set -e

echo "🚀 Day 160: Automated Incident Response Playbooks Setup"
echo "========================================================"

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_DIR="day160_incident_response"

# Create project structure
echo -e "${BLUE}📁 Creating project structure...${NC}"
mkdir -p ${PROJECT_DIR}/{src/{playbooks,actions,api,dashboard},tests,config,logs,docker,scripts}
mkdir -p ${PROJECT_DIR}/src/playbooks/{templates,engine}
mkdir -p ${PROJECT_DIR}/src/actions/{network,identity,alert,evidence}
mkdir -p ${PROJECT_DIR}/src/dashboard/{static,templates}
mkdir -p ${PROJECT_DIR}/tests/{unit,integration}

cd ${PROJECT_DIR}

# Create requirements.txt
echo -e "${BLUE}📦 Creating requirements.txt...${NC}"
cat > requirements.txt << 'EOF'
# Core Dependencies (May 2025 compatible)
fastapi==0.111.0
uvicorn[standard]==0.30.1
pydantic==2.7.4
pydantic-settings==2.3.3

# Async and messaging
aiohttp==3.9.5
redis==5.0.6
asyncio==3.4.3

# Database and storage
sqlalchemy==2.0.30
alembic==1.13.1

# Security and validation
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
pyyaml==6.0.1

# Testing
pytest==8.2.2
pytest-asyncio==0.23.7
pytest-cov==5.0.0
httpx==0.27.0

# Utilities
python-dotenv==1.0.1
structlog==24.2.0
colorama==0.4.6
EOF

# Create Python source files
echo -e "${BLUE}📝 Creating playbook engine...${NC}"

cat > src/playbooks/engine/playbook_engine.py << 'EOF'
"""Core playbook engine for executing incident response procedures"""
import asyncio
import yaml
import structlog
from datetime import datetime
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, field
from enum import Enum

logger = structlog.get_logger()


class PlaybookStatus(Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    PAUSED = "paused"


class ActionStatus(Enum):
    PENDING = "pending"
    EXECUTING = "executing"
    SUCCESS = "success"
    FAILED = "failed"
    SKIPPED = "skipped"


@dataclass
class Action:
    """Individual action in a playbook"""
    name: str
    action_type: str
    parameters: Dict[str, Any]
    conditions: List[Dict[str, Any]] = field(default_factory=list)
    timeout: int = 30
    retry_count: int = 0
    max_retries: int = 2
    status: ActionStatus = ActionStatus.PENDING
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    executed_at: Optional[datetime] = None


@dataclass
class Playbook:
    """Incident response playbook definition"""
    name: str
    description: str
    severity: str
    triggers: List[str]
    actions: List[Action]
    status: PlaybookStatus = PlaybookStatus.PENDING
    execution_id: Optional[str] = None
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    metadata: Dict[str, Any] = field(default_factory=dict)


class PlaybookEngine:
    """Engine for executing security response playbooks"""
    
    def __init__(self, action_registry: Dict):
        self.action_registry = action_registry
        self.active_playbooks: Dict[str, Playbook] = {}
        self.playbook_templates: Dict[str, Dict] = {}
        self.audit_log: List[Dict] = []
        
    def load_playbook_template(self, template_path: str) -> None:
        """Load playbook template from YAML"""
        with open(template_path, 'r') as f:
            template = yaml.safe_load(f)
            self.playbook_templates[template['name']] = template
            logger.info("playbook_template_loaded", name=template['name'])
    
    def create_playbook_from_template(self, template_name: str, 
                                     context: Dict[str, Any]) -> Playbook:
        """Create executable playbook from template"""
        if template_name not in self.playbook_templates:
            raise ValueError(f"Unknown playbook template: {template_name}")
        
        template = self.playbook_templates[template_name]
        
        # Create actions from template
        actions = []
        for action_def in template.get('actions', []):
            # Substitute context variables in parameters
            parameters = self._substitute_context(action_def.get('parameters', {}), context)
            
            action = Action(
                name=action_def['name'],
                action_type=action_def['type'],
                parameters=parameters,
                conditions=action_def.get('conditions', []),
                timeout=action_def.get('timeout', 30),
                max_retries=action_def.get('max_retries', 2)
            )
            actions.append(action)
        
        playbook = Playbook(
            name=template['name'],
            description=template['description'],
            severity=template.get('severity', 'medium'),
            triggers=template.get('triggers', []),
            actions=actions,
            metadata={'context': context, 'template': template_name}
        )
        
        return playbook
    
    def _substitute_context(self, params: Dict, context: Dict) -> Dict:
        """Substitute context variables in parameters"""
        result = {}
        for key, value in params.items():
            if isinstance(value, str) and value.startswith('${') and value.endswith('}'):
                var_name = value[2:-1]
                result[key] = context.get(var_name, value)
            else:
                result[key] = value
        return result
    
    async def execute_playbook(self, playbook: Playbook, 
                              execution_id: str) -> Dict[str, Any]:
        """Execute a complete playbook"""
        playbook.execution_id = execution_id
        playbook.status = PlaybookStatus.RUNNING
        playbook.started_at = datetime.now()
        self.active_playbooks[execution_id] = playbook
        
        logger.info("playbook_execution_started", 
                   execution_id=execution_id,
                   playbook=playbook.name)
        
        execution_results = {
            'execution_id': execution_id,
            'playbook': playbook.name,
            'started_at': playbook.started_at.isoformat(),
            'actions': []
        }
        
        try:
            for action in playbook.actions:
                # Check conditions
                if not self._evaluate_conditions(action.conditions, playbook.metadata['context']):
                    action.status = ActionStatus.SKIPPED
                    logger.info("action_skipped", action=action.name)
                    continue
                
                # Execute action with retry logic
                action_result = await self._execute_action_with_retry(
                    action, playbook.metadata['context']
                )
                
                execution_results['actions'].append({
                    'name': action.name,
                    'status': action.status.value,
                    'result': action.result,
                    'error': action.error
                })
                
                # Audit log entry
                self._log_action(execution_id, playbook.name, action)
                
                # Stop on critical failure
                if action.status == ActionStatus.FAILED and action.action_type in ['isolate_system', 'block_ip']:
                    logger.error("critical_action_failed", action=action.name)
                    playbook.status = PlaybookStatus.FAILED
                    break
            
            # Determine final status
            if playbook.status != PlaybookStatus.FAILED:
                failed_actions = [a for a in playbook.actions if a.status == ActionStatus.FAILED]
                if failed_actions:
                    playbook.status = PlaybookStatus.FAILED
                else:
                    playbook.status = PlaybookStatus.COMPLETED
            
        except Exception as e:
            logger.exception("playbook_execution_error", execution_id=execution_id)
            playbook.status = PlaybookStatus.FAILED
            execution_results['error'] = str(e)
        
        playbook.completed_at = datetime.now()
        execution_results['completed_at'] = playbook.completed_at.isoformat()
        execution_results['status'] = playbook.status.value
        execution_results['duration'] = (playbook.completed_at - playbook.started_at).total_seconds()
        
        logger.info("playbook_execution_completed",
                   execution_id=execution_id,
                   status=playbook.status.value,
                   duration=execution_results['duration'])
        
        return execution_results
    
    async def _execute_action_with_retry(self, action: Action, 
                                        context: Dict) -> Dict[str, Any]:
        """Execute action with retry logic"""
        action.status = ActionStatus.EXECUTING
        
        while action.retry_count <= action.max_retries:
            try:
                action.executed_at = datetime.now()
                
                # Get executor from registry
                executor = self.action_registry.get(action.action_type)
                if not executor:
                    raise ValueError(f"Unknown action type: {action.action_type}")
                
                # Execute with timeout
                result = await asyncio.wait_for(
                    executor.execute(action.parameters, context),
                    timeout=action.timeout
                )
                
                action.status = ActionStatus.SUCCESS
                action.result = result
                return result
                
            except asyncio.TimeoutError:
                error_msg = f"Action timeout after {action.timeout}s"
                action.error = error_msg
                logger.warning("action_timeout", action=action.name, retry=action.retry_count)
                
            except Exception as e:
                action.error = str(e)
                logger.warning("action_execution_failed", 
                             action=action.name,
                             error=str(e),
                             retry=action.retry_count)
            
            action.retry_count += 1
            if action.retry_count <= action.max_retries:
                await asyncio.sleep(2 ** action.retry_count)  # Exponential backoff
        
        # All retries exhausted
        action.status = ActionStatus.FAILED
        return {'error': action.error}
    
    def _evaluate_conditions(self, conditions: List[Dict], context: Dict) -> bool:
        """Evaluate action conditions"""
        if not conditions:
            return True
        
        for condition in conditions:
            field = condition.get('field')
            operator = condition.get('operator')
            value = condition.get('value')
            
            context_value = context.get(field)
            
            if operator == 'equals' and context_value != value:
                return False
            elif operator == 'not_equals' and context_value == value:
                return False
            elif operator == 'greater_than' and not (context_value > value):
                return False
            elif operator == 'less_than' and not (context_value < value):
                return False
            elif operator == 'contains' and value not in str(context_value):
                return False
        
        return True
    
    def _log_action(self, execution_id: str, playbook_name: str, action: Action):
        """Log action execution for audit trail"""
        log_entry = {
            'timestamp': datetime.now().isoformat(),
            'execution_id': execution_id,
            'playbook': playbook_name,
            'action': action.name,
            'action_type': action.action_type,
            'status': action.status.value,
            'parameters': action.parameters,
            'result': action.result,
            'error': action.error,
            'retry_count': action.retry_count
        }
        self.audit_log.append(log_entry)
    
    def get_execution_status(self, execution_id: str) -> Optional[Dict]:
        """Get status of a playbook execution"""
        playbook = self.active_playbooks.get(execution_id)
        if not playbook:
            return None
        
        return {
            'execution_id': execution_id,
            'playbook': playbook.name,
            'status': playbook.status.value,
            'started_at': playbook.started_at.isoformat() if playbook.started_at else None,
            'completed_at': playbook.completed_at.isoformat() if playbook.completed_at else None,
            'actions': [
                {
                    'name': a.name,
                    'status': a.status.value,
                    'error': a.error
                } for a in playbook.actions
            ]
        }
    
    def get_audit_log(self, execution_id: Optional[str] = None) -> List[Dict]:
        """Get audit log entries"""
        if execution_id:
            return [log for log in self.audit_log if log['execution_id'] == execution_id]
        return self.audit_log
EOF

echo -e "${BLUE}📝 Creating response coordinator...${NC}"

cat > src/playbooks/response_coordinator.py << 'EOF'
"""Coordinator for automated incident responses"""
import asyncio
import uuid
import structlog
from typing import Dict, List, Any, Optional
from datetime import datetime
from dataclasses import dataclass

from playbooks.engine.playbook_engine import PlaybookEngine, Playbook

logger = structlog.get_logger()


@dataclass
class SecurityEvent:
    """Security event that triggers incident response"""
    event_id: str
    event_type: str
    severity: str
    source: str
    timestamp: datetime
    details: Dict[str, Any]
    ioc_data: Optional[Dict[str, Any]] = None


class ResponseCoordinator:
    """Coordinates automated incident responses"""
    
    def __init__(self, playbook_engine: PlaybookEngine):
        self.playbook_engine = playbook_engine
        self.event_queue: asyncio.Queue = asyncio.Queue()
        self.active_responses: Dict[str, Dict] = {}
        self.response_history: List[Dict] = []
        self.running = False
        
    async def start(self):
        """Start the response coordinator"""
        self.running = True
        logger.info("response_coordinator_started")
        await self._process_events()
    
    async def stop(self):
        """Stop the response coordinator"""
        self.running = False
        logger.info("response_coordinator_stopped")
    
    async def handle_security_event(self, event: SecurityEvent) -> str:
        """Handle incoming security event"""
        await self.event_queue.put(event)
        logger.info("security_event_received",
                   event_id=event.event_id,
                   event_type=event.event_type,
                   severity=event.severity)
        return event.event_id
    
    async def _process_events(self):
        """Process security events from queue"""
        while self.running:
            try:
                event = await asyncio.wait_for(self.event_queue.get(), timeout=1.0)
                await self._respond_to_event(event)
            except asyncio.TimeoutError:
                continue
            except Exception as e:
                logger.exception("event_processing_error", error=str(e))
    
    async def _respond_to_event(self, event: SecurityEvent):
        """Determine and execute appropriate response"""
        # Select playbooks based on event type and severity
        applicable_playbooks = self._select_playbooks(event)
        
        if not applicable_playbooks:
            logger.warning("no_applicable_playbooks", event_type=event.event_type)
            return
        
        # Execute playbooks (can run multiple in parallel for different aspects)
        execution_id = str(uuid.uuid4())
        
        response_info = {
            'execution_id': execution_id,
            'event_id': event.event_id,
            'event_type': event.event_type,
            'started_at': datetime.now().isoformat(),
            'playbooks': []
        }
        
        tasks = []
        for playbook_template in applicable_playbooks:
            # Create context from event data
            context = {
                'event_id': event.event_id,
                'event_type': event.event_type,
                'severity': event.severity,
                'source': event.source,
                **event.details
            }
            
            if event.ioc_data:
                context.update(event.ioc_data)
            
            # Create playbook from template
            playbook = self.playbook_engine.create_playbook_from_template(
                playbook_template, context
            )
            
            # Execute playbook
            task = asyncio.create_task(
                self.playbook_engine.execute_playbook(playbook, f"{execution_id}_{playbook.name}")
            )
            tasks.append(task)
            response_info['playbooks'].append(playbook.name)
        
        self.active_responses[execution_id] = response_info
        
        # Wait for all playbooks to complete
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        response_info['completed_at'] = datetime.now().isoformat()
        response_info['results'] = [
            r if not isinstance(r, Exception) else {'error': str(r)} 
            for r in results
        ]
        
        self.response_history.append(response_info)
        
        logger.info("incident_response_completed",
                   execution_id=execution_id,
                   playbooks=response_info['playbooks'])
    
    def _select_playbooks(self, event: SecurityEvent) -> List[str]:
        """Select applicable playbooks based on event"""
        playbooks = []
        
        # Map event types to playbook templates
        event_playbook_mapping = {
            'brute_force_attack': ['brute_force_response'],
            'malware_detected': ['malware_response'],
            'data_exfiltration': ['data_exfiltration_response'],
            'c2_communication': ['c2_communication_response'],
            'credential_stuffing': ['credential_protection_response'],
            'port_scan': ['network_scan_response']
        }
        
        # Add severity-based playbooks
        if event.severity == 'critical':
            playbooks.extend(event_playbook_mapping.get(event.event_type, []))
            if 'critical_incident_notification' not in playbooks:
                playbooks.append('critical_incident_notification')
        elif event.severity in ['high', 'medium']:
            playbooks.extend(event_playbook_mapping.get(event.event_type, []))
        
        return playbooks
    
    def get_response_status(self, execution_id: str) -> Optional[Dict]:
        """Get status of incident response"""
        return self.active_responses.get(execution_id)
    
    def get_response_history(self, limit: int = 100) -> List[Dict]:
        """Get response history"""
        return self.response_history[-limit:]
EOF

echo -e "${BLUE}📝 Creating action executors...${NC}"

# Network actions
cat > src/actions/network/network_actions.py << 'EOF'
"""Network-related incident response actions"""
import asyncio
import structlog
from typing import Dict, Any

logger = structlog.get_logger()


class BlockIPAction:
    """Block an IP address at firewall level"""
    
    async def execute(self, parameters: Dict[str, Any], context: Dict) -> Dict[str, Any]:
        """Execute IP blocking action"""
        ip_address = parameters.get('ip_address')
        duration = parameters.get('duration', 3600)  # Default 1 hour
        
        logger.info("blocking_ip", ip=ip_address, duration=duration)
        
        # Simulate firewall rule addition
        await asyncio.sleep(0.5)
        
        # In production, this would interface with actual firewall (iptables, AWS Security Groups, etc.)
        rule_id = f"block_{ip_address.replace('.', '_')}"
        
        return {
            'success': True,
            'ip_address': ip_address,
            'rule_id': rule_id,
            'duration': duration,
            'message': f'Successfully blocked IP {ip_address}'
        }


class IsolateSystemAction:
    """Isolate a system from the network"""
    
    async def execute(self, parameters: Dict[str, Any], context: Dict) -> Dict[str, Any]:
        """Execute system isolation"""
        system_id = parameters.get('system_id')
        preserve_logging = parameters.get('preserve_logging', True)
        
        logger.info("isolating_system", system=system_id)
        
        # Simulate network isolation
        await asyncio.sleep(0.8)
        
        # In production: disable network interfaces, update SDN rules, etc.
        isolation_id = f"isolate_{system_id}"
        
        return {
            'success': True,
            'system_id': system_id,
            'isolation_id': isolation_id,
            'logging_preserved': preserve_logging,
            'message': f'Successfully isolated system {system_id}'
        }


class CaptureTrafficAction:
    """Capture network traffic for forensic analysis"""
    
    async def execute(self, parameters: Dict[str, Any], context: Dict) -> Dict[str, Any]:
        """Execute traffic capture"""
        system_id = parameters.get('system_id')
        duration = parameters.get('duration', 300)  # 5 minutes default
        
        logger.info("capturing_traffic", system=system_id, duration=duration)
        
        # Simulate packet capture initialization
        await asyncio.sleep(0.3)
        
        capture_file = f"/forensics/captures/{system_id}_{context.get('event_id')}.pcap"
        
        return {
            'success': True,
            'system_id': system_id,
            'capture_file': capture_file,
            'duration': duration,
            'message': f'Traffic capture started for {system_id}'
        }
EOF

# Identity actions
cat > src/actions/identity/identity_actions.py << 'EOF'
"""Identity and access management response actions"""
import asyncio
import structlog
from typing import Dict, Any

logger = structlog.get_logger()


class SuspendAccountAction:
    """Suspend a user account"""
    
    async def execute(self, parameters: Dict[str, Any], context: Dict) -> Dict[str, Any]:
        """Execute account suspension"""
        user_id = parameters.get('user_id')
        reason = parameters.get('reason', 'Security incident')
        
        logger.info("suspending_account", user=user_id, reason=reason)
        
        # Simulate account suspension in IAM system
        await asyncio.sleep(0.4)
        
        return {
            'success': True,
            'user_id': user_id,
            'action': 'suspended',
            'reason': reason,
            'message': f'Account {user_id} suspended due to: {reason}'
        }


class ForcePasswordResetAction:
    """Force password reset for affected accounts"""
    
    async def execute(self, parameters: Dict[str, Any], context: Dict) -> Dict[str, Any]:
        """Execute forced password reset"""
        user_ids = parameters.get('user_ids', [])
        
        logger.info("forcing_password_reset", users=user_ids)
        
        # Simulate password reset
        await asyncio.sleep(0.5)
        
        return {
            'success': True,
            'affected_users': user_ids,
            'reset_tokens_sent': len(user_ids),
            'message': f'Password reset initiated for {len(user_ids)} users'
        }


class RevokeSessionsAction:
    """Revoke all active sessions for a user"""
    
    async def execute(self, parameters: Dict[str, Any], context: Dict) -> Dict[str, Any]:
        """Execute session revocation"""
        user_id = parameters.get('user_id')
        
        logger.info("revoking_sessions", user=user_id)
        
        # Simulate session termination
        await asyncio.sleep(0.3)
        
        sessions_revoked = 3  # Simulated count
        
        return {
            'success': True,
            'user_id': user_id,
            'sessions_revoked': sessions_revoked,
            'message': f'Revoked {sessions_revoked} active sessions for {user_id}'
        }
EOF

# Alert actions
cat > src/actions/alert/alert_actions.py << 'EOF'
"""Alert and notification response actions"""
import asyncio
import structlog
from typing import Dict, Any
from datetime import datetime

logger = structlog.get_logger()


class SendEmailAlertAction:
    """Send email alert to security team"""
    
    async def execute(self, parameters: Dict[str, Any], context: Dict) -> Dict[str, Any]:
        """Execute email alert"""
        recipients = parameters.get('recipients', ['security@company.com'])
        subject = parameters.get('subject', 'Security Incident Alert')
        priority = parameters.get('priority', 'high')
        
        logger.info("sending_email_alert", recipients=recipients, priority=priority)
        
        # Simulate email sending
        await asyncio.sleep(0.2)
        
        message_body = self._format_incident_email(context, priority)
        
        return {
            'success': True,
            'recipients': recipients,
            'subject': subject,
            'priority': priority,
            'message': f'Email alert sent to {len(recipients)} recipients'
        }
    
    def _format_incident_email(self, context: Dict, priority: str) -> str:
        """Format incident details for email"""
        return f"""
        Security Incident Alert
        
        Priority: {priority.upper()}
        Event Type: {context.get('event_type')}
        Event ID: {context.get('event_id')}
        Timestamp: {datetime.now().isoformat()}
        
        Details:
        Severity: {context.get('severity')}
        Source: {context.get('source')}
        
        Automated response has been initiated.
        Please review the incident dashboard for full details.
        """


class SendSlackAlertAction:
    """Send alert to Slack channel"""
    
    async def execute(self, parameters: Dict[str, Any], context: Dict) -> Dict[str, Any]:
        """Execute Slack notification"""
        channel = parameters.get('channel', '#security-alerts')
        mention_team = parameters.get('mention_team', True)
        
        logger.info("sending_slack_alert", channel=channel)
        
        # Simulate Slack API call
        await asyncio.sleep(0.3)
        
        return {
            'success': True,
            'channel': channel,
            'message_id': f"slack_{context.get('event_id')}",
            'mention_team': mention_team,
            'message': f'Slack alert sent to {channel}'
        }


class CreatePagerDutyIncidentAction:
    """Create PagerDuty incident for critical issues"""
    
    async def execute(self, parameters: Dict[str, Any], context: Dict) -> Dict[str, Any]:
        """Execute PagerDuty incident creation"""
        service_id = parameters.get('service_id', 'security_team')
        urgency = parameters.get('urgency', 'high')
        
        logger.info("creating_pagerduty_incident", service=service_id, urgency=urgency)
        
        # Simulate PagerDuty API call
        await asyncio.sleep(0.4)
        
        incident_id = f"PD{context.get('event_id')[:8]}"
        
        return {
            'success': True,
            'incident_id': incident_id,
            'service_id': service_id,
            'urgency': urgency,
            'message': f'PagerDuty incident {incident_id} created'
        }
EOF

# Evidence actions
cat > src/actions/evidence/evidence_actions.py << 'EOF'
"""Evidence collection and preservation actions"""
import asyncio
import structlog
from typing import Dict, Any
from datetime import datetime

logger = structlog.get_logger()


class CreateSystemSnapshotAction:
    """Create forensic snapshot of system state"""
    
    async def execute(self, parameters: Dict[str, Any], context: Dict) -> Dict[str, Any]:
        """Execute system snapshot"""
        system_id = parameters.get('system_id')
        include_memory = parameters.get('include_memory', True)
        
        logger.info("creating_system_snapshot", system=system_id, memory=include_memory)
        
        # Simulate snapshot creation
        await asyncio.sleep(1.2)
        
        snapshot_id = f"snapshot_{system_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        snapshot_path = f"/forensics/snapshots/{snapshot_id}"
        
        return {
            'success': True,
            'system_id': system_id,
            'snapshot_id': snapshot_id,
            'snapshot_path': snapshot_path,
            'include_memory': include_memory,
            'size_gb': 45.3,  # Simulated size
            'message': f'System snapshot created: {snapshot_id}'
        }


class PreserveLogsAction:
    """Preserve logs for forensic analysis"""
    
    async def execute(self, parameters: Dict[str, Any], context: Dict) -> Dict[str, Any]:
        """Execute log preservation"""
        log_sources = parameters.get('log_sources', ['system', 'application', 'security'])
        time_range = parameters.get('time_range_hours', 24)
        
        logger.info("preserving_logs", sources=log_sources, hours=time_range)
        
        # Simulate log collection
        await asyncio.sleep(0.8)
        
        archive_id = f"logs_{context.get('event_id')}"
        archive_path = f"/forensics/logs/{archive_id}.tar.gz"
        
        return {
            'success': True,
            'archive_id': archive_id,
            'archive_path': archive_path,
            'log_sources': log_sources,
            'time_range_hours': time_range,
            'entries_preserved': 15847,  # Simulated count
            'message': f'Logs preserved in {archive_path}'
        }


class CollectArtifactsAction:
    """Collect forensic artifacts from system"""
    
    async def execute(self, parameters: Dict[str, Any], context: Dict) -> Dict[str, Any]:
        """Execute artifact collection"""
        system_id = parameters.get('system_id')
        artifact_types = parameters.get('artifact_types', ['processes', 'network', 'files'])
        
        logger.info("collecting_artifacts", system=system_id, types=artifact_types)
        
        # Simulate artifact collection
        await asyncio.sleep(0.9)
        
        artifacts = {
            'processes': f"/forensics/artifacts/processes_{system_id}.json",
            'network': f"/forensics/artifacts/network_{system_id}.json",
            'files': f"/forensics/artifacts/files_{system_id}.json"
        }
        
        return {
            'success': True,
            'system_id': system_id,
            'artifact_types': artifact_types,
            'artifacts': artifacts,
            'message': f'Artifacts collected from {system_id}'
        }
EOF

echo -e "${BLUE}📝 Creating playbook templates...${NC}"

cat > src/playbooks/templates/brute_force_response.yaml << 'EOF'
name: brute_force_response
description: Response to brute force authentication attacks
severity: high
triggers:
  - brute_force_attack
  - credential_stuffing

actions:
  - name: block_attacker_ip
    type: block_ip
    parameters:
      ip_address: ${source_ip}
      duration: 7200
    timeout: 10
    max_retries: 2
  
  - name: suspend_targeted_accounts
    type: suspend_account
    parameters:
      user_id: ${target_user}
      reason: Brute force attack detected
    conditions:
      - field: failed_attempts
        operator: greater_than
        value: 10
    timeout: 15
    max_retries: 1
  
  - name: alert_security_team
    type: send_email_alert
    parameters:
      recipients: ['security@company.com']
      subject: 'Brute Force Attack Detected'
      priority: high
    timeout: 10
  
  - name: preserve_attack_logs
    type: preserve_logs
    parameters:
      log_sources: ['authentication', 'security']
      time_range_hours: 2
    timeout: 30
EOF

cat > src/playbooks/templates/malware_response.yaml << 'EOF'
name: malware_response
description: Response to malware detection
severity: critical
triggers:
  - malware_detected

actions:
  - name: isolate_infected_system
    type: isolate_system
    parameters:
      system_id: ${system_id}
      preserve_logging: true
    timeout: 20
    max_retries: 2
  
  - name: capture_network_traffic
    type: capture_traffic
    parameters:
      system_id: ${system_id}
      duration: 600
    timeout: 15
  
  - name: create_forensic_snapshot
    type: create_snapshot
    parameters:
      system_id: ${system_id}
      include_memory: true
    timeout: 60
  
  - name: suspend_user_account
    type: suspend_account
    parameters:
      user_id: ${user_id}
      reason: Malware detected on user system
    timeout: 15
  
  - name: create_pagerduty_incident
    type: create_pagerduty
    parameters:
      service_id: security_team
      urgency: high
    timeout: 10
  
  - name: send_slack_notification
    type: send_slack_alert
    parameters:
      channel: '#security-critical'
      mention_team: true
    timeout: 10
EOF

cat > src/playbooks/templates/c2_communication_response.yaml << 'EOF'
name: c2_communication_response
description: Response to C2 (Command & Control) communication detection
severity: critical
triggers:
  - c2_communication

actions:
  - name: block_c2_server
    type: block_ip
    parameters:
      ip_address: ${c2_ip}
      duration: 86400
    timeout: 10
  
  - name: isolate_compromised_host
    type: isolate_system
    parameters:
      system_id: ${system_id}
      preserve_logging: true
    timeout: 20
  
  - name: capture_c2_traffic
    type: capture_traffic
    parameters:
      system_id: ${system_id}
      duration: 300
    timeout: 15
  
  - name: create_system_snapshot
    type: create_snapshot
    parameters:
      system_id: ${system_id}
      include_memory: true
    timeout: 60
  
  - name: collect_forensic_artifacts
    type: collect_artifacts
    parameters:
      system_id: ${system_id}
      artifact_types: ['processes', 'network', 'files']
    timeout: 45
  
  - name: alert_incident_response
    type: create_pagerduty
    parameters:
      service_id: incident_response
      urgency: high
    timeout: 10
  
  - name: notify_security_operations
    type: send_email_alert
    parameters:
      recipients: ['soc@company.com', 'ciso@company.com']
      subject: 'Critical: C2 Communication Detected'
      priority: critical
    timeout: 10
EOF

cat > src/playbooks/templates/data_exfiltration_response.yaml << 'EOF'
name: data_exfiltration_response
description: Response to data exfiltration detection
severity: critical
triggers:
  - data_exfiltration

actions:
  - name: block_external_ip
    type: block_ip
    parameters:
      ip_address: ${destination_ip}
      duration: 86400
    timeout: 10
  
  - name: isolate_affected_system
    type: isolate_system
    parameters:
      system_id: ${system_id}
      preserve_logging: true
    timeout: 20
  
  - name: suspend_user_account
    type: suspend_account
    parameters:
      user_id: ${user_id}
      reason: Data exfiltration detected
    timeout: 15
  
  - name: preserve_logs
    type: preserve_logs
    parameters:
      log_sources: ['network', 'application', 'security']
      time_range_hours: 24
    timeout: 30
  
  - name: create_forensic_snapshot
    type: create_snapshot
    parameters:
      system_id: ${system_id}
      include_memory: true
    timeout: 60
  
  - name: alert_security_team
    type: create_pagerduty
    parameters:
      service_id: security_team
      urgency: high
    timeout: 10
EOF

cat > src/playbooks/templates/credential_protection_response.yaml << 'EOF'
name: credential_protection_response
description: Response to credential stuffing attacks
severity: high
triggers:
  - credential_stuffing

actions:
  - name: block_attacker_ip
    type: block_ip
    parameters:
      ip_address: ${source_ip}
      duration: 7200
    timeout: 10
  
  - name: force_password_reset
    type: force_password_reset
    parameters:
      user_ids: ${affected_users}
    timeout: 15
  
  - name: revoke_user_sessions
    type: revoke_sessions
    parameters:
      user_id: ${target_user}
    timeout: 10
  
  - name: alert_security_team
    type: send_email_alert
    parameters:
      recipients: ['security@company.com']
      subject: 'Credential Stuffing Attack Detected'
      priority: high
    timeout: 10
  
  - name: preserve_authentication_logs
    type: preserve_logs
    parameters:
      log_sources: ['authentication', 'security']
      time_range_hours: 2
    timeout: 30
EOF

cat > src/playbooks/templates/network_scan_response.yaml << 'EOF'
name: network_scan_response
description: Response to network port scanning activity
severity: medium
triggers:
  - port_scan

actions:
  - name: block_scanning_ip
    type: block_ip
    parameters:
      ip_address: ${source_ip}
      duration: 3600
    timeout: 10
  
  - name: alert_security_team
    type: send_email_alert
    parameters:
      recipients: ['security@company.com']
      subject: 'Network Scan Detected'
      priority: medium
    timeout: 10
  
  - name: preserve_network_logs
    type: preserve_logs
    parameters:
      log_sources: ['network', 'firewall']
      time_range_hours: 1
    timeout: 30
EOF

cat > src/playbooks/templates/critical_incident_notification.yaml << 'EOF'
name: critical_incident_notification
description: Critical incident notification playbook
severity: critical
triggers:
  - critical_incident

actions:
  - name: create_pagerduty_incident
    type: create_pagerduty
    parameters:
      service_id: security_team
      urgency: high
    timeout: 10
  
  - name: send_slack_alert
    type: send_slack_alert
    parameters:
      channel: '#security-critical'
      mention_team: true
    timeout: 10
  
  - name: send_email_alert
    type: send_email_alert
    parameters:
      recipients: ['soc@company.com', 'ciso@company.com', 'oncall@company.com']
      subject: 'Critical Security Incident'
      priority: critical
    timeout: 10
EOF

echo -e "${BLUE}📝 Creating FastAPI application...${NC}"

cat > src/api/main.py << 'EOF'
"""FastAPI application for incident response system"""
import asyncio
import structlog
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime

from playbooks.engine.playbook_engine import PlaybookEngine
from playbooks.response_coordinator import ResponseCoordinator, SecurityEvent
from actions.network.network_actions import BlockIPAction, IsolateSystemAction, CaptureTrafficAction
from actions.identity.identity_actions import SuspendAccountAction, ForcePasswordResetAction, RevokeSessionsAction
from actions.alert.alert_actions import SendEmailAlertAction, SendSlackAlertAction, CreatePagerDutyIncidentAction
from actions.evidence.evidence_actions import CreateSystemSnapshotAction, PreserveLogsAction, CollectArtifactsAction

# Configure structured logging
structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer()
    ]
)

logger = structlog.get_logger()

# Initialize FastAPI
app = FastAPI(
    title="Automated Incident Response System",
    description="Security incident response orchestration platform",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files for dashboard
import os
static_path = os.path.join(os.path.dirname(__file__), '..', 'dashboard', 'static')
if os.path.exists(static_path):
    app.mount("/", StaticFiles(directory=static_path, html=True), name="static")

# Global instances
playbook_engine: Optional[PlaybookEngine] = None
response_coordinator: Optional[ResponseCoordinator] = None
coordinator_task: Optional[asyncio.Task] = None


# Pydantic models
class SecurityEventRequest(BaseModel):
    event_type: str
    severity: str
    source: str
    details: Dict[str, Any]
    ioc_data: Optional[Dict[str, Any]] = None


class PlaybookExecutionRequest(BaseModel):
    template_name: str
    context: Dict[str, Any]


@app.on_event("startup")
async def startup_event():
    """Initialize system on startup"""
    global playbook_engine, response_coordinator, coordinator_task
    
    logger.info("initializing_incident_response_system")
    
    # Create action registry
    action_registry = {
        'block_ip': BlockIPAction(),
        'isolate_system': IsolateSystemAction(),
        'capture_traffic': CaptureTrafficAction(),
        'suspend_account': SuspendAccountAction(),
        'force_password_reset': ForcePasswordResetAction(),
        'revoke_sessions': RevokeSessionsAction(),
        'send_email_alert': SendEmailAlertAction(),
        'send_slack_alert': SendSlackAlertAction(),
        'create_pagerduty': CreatePagerDutyIncidentAction(),
        'create_snapshot': CreateSystemSnapshotAction(),
        'preserve_logs': PreserveLogsAction(),
        'collect_artifacts': CollectArtifactsAction()
    }
    
    # Initialize playbook engine
    playbook_engine = PlaybookEngine(action_registry)
    
    # Load playbook templates
    import glob
    import os
    template_dir = os.path.join(os.path.dirname(__file__), '..', 'playbooks', 'templates')
    for template_path in glob.glob(os.path.join(template_dir, '*.yaml')):
        playbook_engine.load_playbook_template(template_path)
    
    # Initialize response coordinator
    response_coordinator = ResponseCoordinator(playbook_engine)
    
    # Start coordinator in background
    coordinator_task = asyncio.create_task(response_coordinator.start())
    
    logger.info("incident_response_system_ready")


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    global response_coordinator, coordinator_task
    
    logger.info("shutting_down_incident_response_system")
    
    if response_coordinator:
        await response_coordinator.stop()
    
    if coordinator_task:
        coordinator_task.cancel()


@app.post("/api/events", status_code=202)
async def submit_security_event(event_request: SecurityEventRequest):
    """Submit a security event for automated response"""
    event = SecurityEvent(
        event_id=f"evt_{datetime.now().strftime('%Y%m%d%H%M%S')}",
        event_type=event_request.event_type,
        severity=event_request.severity,
        source=event_request.source,
        timestamp=datetime.now(),
        details=event_request.details,
        ioc_data=event_request.ioc_data
    )
    
    event_id = await response_coordinator.handle_security_event(event)
    
    return {
        'event_id': event_id,
        'status': 'accepted',
        'message': 'Security event accepted for processing'
    }


@app.post("/api/playbooks/execute")
async def execute_playbook(request: PlaybookExecutionRequest):
    """Manually execute a playbook"""
    import uuid
    
    try:
        playbook = playbook_engine.create_playbook_from_template(
            request.template_name,
            request.context
        )
        
        execution_id = str(uuid.uuid4())
        result = await playbook_engine.execute_playbook(playbook, execution_id)
        
        return result
        
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/playbooks/templates")
async def list_playbook_templates():
    """List available playbook templates"""
    return {
        'templates': list(playbook_engine.playbook_templates.keys())
    }


@app.get("/api/responses/{execution_id}")
async def get_response_status(execution_id: str):
    """Get status of incident response"""
    status = response_coordinator.get_response_status(execution_id)
    
    if not status:
        raise HTTPException(status_code=404, detail="Response not found")
    
    return status


@app.get("/api/responses")
async def list_responses(limit: int = 50):
    """List recent incident responses"""
    history = response_coordinator.get_response_history(limit)
    return {'responses': history}


@app.get("/api/audit-log")
async def get_audit_log(execution_id: Optional[str] = None, limit: int = 100):
    """Get audit log entries"""
    log_entries = playbook_engine.get_audit_log(execution_id)
    return {'audit_log': log_entries[-limit:]}


@app.get("/api/metrics")
async def get_metrics():
    """Get system metrics"""
    return {
        'active_playbooks': len(playbook_engine.active_playbooks),
        'total_responses': len(response_coordinator.response_history),
        'audit_entries': len(playbook_engine.audit_log),
        'playbook_templates': len(playbook_engine.playbook_templates)
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        'status': 'healthy',
        'timestamp': datetime.now().isoformat()
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

echo -e "${BLUE}📝 Creating React dashboard...${NC}"

mkdir -p src/dashboard/static

cat > src/dashboard/static/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Incident Response Dashboard</title>
    <script crossorigin src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
    <script crossorigin src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
    <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .dashboard {
            max-width: 1400px;
            margin: 0 auto;
        }
        
        .header {
            background: white;
            padding: 30px;
            border-radius: 15px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
            margin-bottom: 30px;
        }
        
        .header h1 {
            color: #667eea;
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        
        .header p {
            color: #666;
            font-size: 1.1em;
        }
        
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .metric-card {
            background: white;
            padding: 25px;
            border-radius: 15px;
            box-shadow: 0 5px 20px rgba(0,0,0,0.08);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        
        .metric-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 30px rgba(0,0,0,0.15);
        }
        
        .metric-label {
            color: #888;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 10px;
        }
        
        .metric-value {
            font-size: 3em;
            font-weight: bold;
            color: #667eea;
        }
        
        .response-section {
            background: white;
            padding: 30px;
            border-radius: 15px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        
        .response-section h2 {
            color: #333;
            margin-bottom: 20px;
            font-size: 1.8em;
        }
        
        .response-item {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 15px;
            border-left: 4px solid #667eea;
            transition: all 0.3s ease;
        }
        
        .response-item:hover {
            background: #e9ecef;
            border-left-color: #764ba2;
        }
        
        .response-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
        }
        
        .response-id {
            font-weight: bold;
            color: #667eea;
            font-size: 1.1em;
        }
        
        .status-badge {
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: 600;
            text-transform: uppercase;
        }
        
        .status-completed {
            background: #d4edda;
            color: #155724;
        }
        
        .status-running {
            background: #fff3cd;
            color: #856404;
        }
        
        .status-failed {
            background: #f8d7da;
            color: #721c24;
        }
        
        .playbook-list {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            margin-top: 10px;
        }
        
        .playbook-tag {
            background: #667eea;
            color: white;
            padding: 5px 12px;
            border-radius: 15px;
            font-size: 0.85em;
        }
        
        .timestamp {
            color: #999;
            font-size: 0.9em;
        }
        
        .test-button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 15px 30px;
            border-radius: 10px;
            font-size: 1.1em;
            font-weight: 600;
            cursor: pointer;
            box-shadow: 0 5px 20px rgba(102, 126, 234, 0.4);
            transition: all 0.3s ease;
            margin-right: 10px;
        }
        
        .test-button:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(102, 126, 234, 0.5);
        }
        
        .test-controls {
            display: flex;
            gap: 15px;
            margin-bottom: 20px;
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
            margin: 0 auto;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .audit-log {
            max-height: 400px;
            overflow-y: auto;
            background: #f8f9fa;
            padding: 15px;
            border-radius: 10px;
        }
        
        .audit-entry {
            padding: 10px;
            border-bottom: 1px solid #dee2e6;
            font-size: 0.9em;
        }
        
        .audit-entry:last-child {
            border-bottom: none;
        }
    </style>
</head>
<body>
    <div id="root"></div>
    
    <script type="text/babel">
        const { useState, useEffect } = React;
        
        function Dashboard() {
            const [metrics, setMetrics] = useState({});
            const [responses, setResponses] = useState([]);
            const [auditLog, setAuditLog] = useState([]);
            const [loading, setLoading] = useState(true);
            
            useEffect(() => {
                loadData();
                const interval = setInterval(loadData, 3000);
                return () => clearInterval(interval);
            }, []);
            
            const loadData = async () => {
                try {
                    const [metricsRes, responsesRes, auditRes] = await Promise.all([
                        fetch('/api/metrics'),
                        fetch('/api/responses?limit=10'),
                        fetch('/api/audit-log?limit=20')
                    ]);
                    
                    setMetrics(await metricsRes.json());
                    setResponses((await responsesRes.json()).responses);
                    setAuditLog((await auditRes.json()).audit_log);
                    setLoading(false);
                } catch (error) {
                    console.error('Error loading data:', error);
                }
            };
            
            const testBruteForce = async () => {
                const response = await fetch('/api/events', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        event_type: 'brute_force_attack',
                        severity: 'high',
                        source: '192.168.1.100',
                        details: {
                            source_ip: '192.168.1.100',
                            target_user: 'admin',
                            failed_attempts: 15
                        }
                    })
                });
                loadData();
            };
            
            const testMalware = async () => {
                const response = await fetch('/api/events', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        event_type: 'malware_detected',
                        severity: 'critical',
                        source: 'workstation-42',
                        details: {
                            system_id: 'workstation-42',
                            user_id: 'jsmith',
                            malware_type: 'ransomware'
                        }
                    })
                });
                loadData();
            };
            
            const testC2 = async () => {
                const response = await fetch('/api/events', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        event_type: 'c2_communication',
                        severity: 'critical',
                        source: 'server-05',
                        details: {
                            system_id: 'server-05',
                            c2_ip: '203.0.113.10',
                            user_id: 'system'
                        }
                    })
                });
                loadData();
            };
            
            if (loading) {
                return (
                    <div className="dashboard">
                        <div className="loading">
                            <div className="spinner"></div>
                            <p>Loading incident response dashboard...</p>
                        </div>
                    </div>
                );
            }
            
            return (
                <div className="dashboard">
                    <div className="header">
                        <h1>🛡️ Incident Response Dashboard</h1>
                        <p>Automated Security Response Orchestration</p>
                    </div>
                    
                    <div className="metrics-grid">
                        <div className="metric-card">
                            <div className="metric-label">Active Playbooks</div>
                            <div className="metric-value">{metrics.active_playbooks || 0}</div>
                        </div>
                        <div className="metric-card">
                            <div className="metric-label">Total Responses</div>
                            <div className="metric-value">{metrics.total_responses || 0}</div>
                        </div>
                        <div className="metric-card">
                            <div className="metric-label">Audit Entries</div>
                            <div className="metric-value">{metrics.audit_entries || 0}</div>
                        </div>
                        <div className="metric-card">
                            <div className="metric-label">Playbook Templates</div>
                            <div className="metric-value">{metrics.playbook_templates || 0}</div>
                        </div>
                    </div>
                    
                    <div className="response-section">
                        <h2>🧪 Test Incident Scenarios</h2>
                        <div className="test-controls">
                            <button className="test-button" onClick={testBruteForce}>
                                Test Brute Force Attack
                            </button>
                            <button className="test-button" onClick={testMalware}>
                                Test Malware Detection
                            </button>
                            <button className="test-button" onClick={testC2}>
                                Test C2 Communication
                            </button>
                        </div>
                    </div>
                    
                    <div className="response-section">
                        <h2>📋 Recent Incident Responses</h2>
                        {responses.length === 0 ? (
                            <p style={{color: '#999'}}>No incident responses yet. Click the test buttons above to generate incidents.</p>
                        ) : (
                            responses.map((response, idx) => (
                                <div key={idx} className="response-item">
                                    <div className="response-header">
                                        <div>
                                            <div className="response-id">{response.event_type}</div>
                                            <div className="timestamp">{response.started_at}</div>
                                        </div>
                                        <span className={`status-badge status-${response.results?.[0]?.status || 'running'}`}>
                                            {response.results?.[0]?.status || 'running'}
                                        </span>
                                    </div>
                                    <div className="playbook-list">
                                        {response.playbooks.map((playbook, pidx) => (
                                            <span key={pidx} className="playbook-tag">{playbook}</span>
                                        ))}
                                    </div>
                                </div>
                            ))
                        )}
                    </div>
                    
                    <div className="response-section">
                        <h2>📜 Recent Audit Log</h2>
                        <div className="audit-log">
                            {auditLog.slice(-10).reverse().map((entry, idx) => (
                                <div key={idx} className="audit-entry">
                                    <strong>{entry.action}</strong> ({entry.action_type}) - {entry.status}
                                    <br/>
                                    <span style={{color: '#999', fontSize: '0.85em'}}>{entry.timestamp}</span>
                                </div>
                            ))}
                        </div>
                    </div>
                </div>
            );
        }
        
        ReactDOM.render(<Dashboard />, document.getElementById('root'));
    </script>
</body>
</html>
EOF

echo -e "${BLUE}📝 Creating tests...${NC}"

cat > tests/test_playbook_engine.py << 'EOF'
"""Tests for playbook engine"""
import pytest
import asyncio
from src.playbooks.engine.playbook_engine import PlaybookEngine, Action, Playbook, ActionStatus


class MockAction:
    async def execute(self, parameters, context):
        await asyncio.sleep(0.1)
        return {'success': True, 'message': 'Mock action executed'}


@pytest.mark.asyncio
async def test_playbook_execution():
    """Test basic playbook execution"""
    action_registry = {'mock_action': MockAction()}
    engine = PlaybookEngine(action_registry)
    
    action = Action(
        name='test_action',
        action_type='mock_action',
        parameters={'param1': 'value1'}
    )
    
    playbook = Playbook(
        name='test_playbook',
        description='Test playbook',
        severity='medium',
        triggers=['test'],
        actions=[action]
    )
    
    result = await engine.execute_playbook(playbook, 'test-exec-1')
    
    assert result['status'] == 'completed'
    assert len(result['actions']) == 1
    assert result['actions'][0]['status'] == 'success'


@pytest.mark.asyncio
async def test_action_retry():
    """Test action retry logic"""
    class FailingAction:
        def __init__(self):
            self.attempts = 0
        
        async def execute(self, parameters, context):
            self.attempts += 1
            if self.attempts < 3:
                raise Exception("Simulated failure")
            return {'success': True}
    
    failing_action = FailingAction()
    action_registry = {'failing': failing_action}
    engine = PlaybookEngine(action_registry)
    
    action = Action(
        name='retry_test',
        action_type='failing',
        parameters={},
        max_retries=3
    )
    
    playbook = Playbook(
        name='retry_playbook',
        description='Test retry',
        severity='low',
        triggers=['test'],
        actions=[action]
    )
    
    result = await engine.execute_playbook(playbook, 'retry-exec-1')
    
    assert failing_action.attempts == 3
    assert result['actions'][0]['status'] == 'success'


def test_condition_evaluation():
    """Test condition evaluation"""
    engine = PlaybookEngine({})
    
    conditions = [
        {'field': 'severity', 'operator': 'equals', 'value': 'high'}
    ]
    context = {'severity': 'high'}
    
    assert engine._evaluate_conditions(conditions, context) == True
    
    context = {'severity': 'low'}
    assert engine._evaluate_conditions(conditions, context) == False
EOF

echo -e "${BLUE}📝 Creating configuration...${NC}"

cat > config/config.py << 'EOF'
"""Configuration settings"""
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings"""
    
    # API settings
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    
    # Playbook settings
    max_concurrent_playbooks: int = 10
    default_action_timeout: int = 30
    default_max_retries: int = 2
    
    # Alert settings
    email_enabled: bool = True
    slack_enabled: bool = True
    pagerduty_enabled: bool = True
    
    # Evidence collection
    forensics_base_path: str = "/forensics"
    preserve_evidence: bool = True
    
    class Config:
        env_file = ".env"


settings = Settings()
EOF

echo -e "${BLUE}📝 Creating Docker configuration...${NC}"

cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY src/ ./src/
COPY config/ ./config/
COPY tests/ ./tests/

EXPOSE 8000

CMD ["python", "-m", "uvicorn", "src.api.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  incident-response:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - ./src:/app/src
      - ./logs:/app/logs
    environment:
      - PYTHONPATH=/app
    command: python -m uvicorn src.api.main:app --host 0.0.0.0 --port 8000 --reload
EOF

cat > .dockerignore << 'EOF'
__pycache__
*.pyc
*.pyo
*.pyd
.Python
env/
venv/
.pytest_cache/
.coverage
htmlcov/
dist/
build/
*.egg-info/
EOF

echo -e "${BLUE}📝 Creating start/stop scripts...${NC}"

cat > start.sh << 'EOF'
#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Starting Day 160 Incident Response System"
echo "Working directory: $(pwd)"

# Check if we're in the right directory
if [ ! -f "requirements.txt" ]; then
    echo "❌ Error: requirements.txt not found. Please run this script from the project directory."
    exit 1
fi

# Check for existing processes
if pgrep -f "uvicorn src.api.main:app" > /dev/null; then
    echo "⚠️  Warning: API server is already running. Stopping existing processes..."
    pkill -f "uvicorn src.api.main:app"
    sleep 2
fi

# Create virtual environment if needed
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv || python3.11 -m venv venv || python -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt

# Set PYTHONPATH
export PYTHONPATH="$(pwd):$PYTHONPATH"

# Run tests
echo "Running tests..."
python -m pytest tests/ -v --tb=short

if [ $? -ne 0 ]; then
    echo "❌ Tests failed!"
    exit 1
fi

echo "✅ Tests passed!"

# Start API server in background
echo "Starting API server..."
python -m uvicorn src.api.main:app --host 0.0.0.0 --port 8000 &
API_PID=$!

# Wait for server to be ready
echo "Waiting for server to start..."
for i in {1..10}; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        echo "✅ Server is ready!"
        break
    fi
    sleep 1
done

# Check if server is running
if ! ps -p $API_PID > /dev/null; then
    echo "❌ Server failed to start!"
    exit 1
fi

echo ""
echo "🎯 System URLs:"
echo "   Dashboard: http://localhost:8000"
echo "   API Docs:  http://localhost:8000/docs"
echo "   Health:    http://localhost:8000/health"
echo ""
echo "💡 Test scenarios available in dashboard!"
echo ""
echo "Press Ctrl+C to stop..."

# Keep script running
wait $API_PID
EOF

chmod +x start.sh

cat > stop.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping Incident Response System..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Kill all uvicorn processes related to this project
pkill -f "uvicorn src.api.main:app"

# Wait a moment for processes to stop
sleep 2

# Check if any processes are still running
if pgrep -f "uvicorn src.api.main:app" > /dev/null; then
    echo "⚠️  Some processes may still be running. Force killing..."
    pkill -9 -f "uvicorn src.api.main:app"
    sleep 1
fi

echo "✅ System stopped"
EOF

chmod +x stop.sh

echo -e "${BLUE}📝 Creating demo script...${NC}"

cat > demo.py << 'EOF'
"""Demo script for incident response system"""
import asyncio
import httpx
from datetime import datetime


async def run_demo():
    """Run automated demo scenarios"""
    base_url = "http://localhost:8000"
    
    print("\n🎬 Day 160: Automated Incident Response Demo")
    print("=" * 60)
    
    async with httpx.AsyncClient() as client:
        # Check system health
        print("\n1️⃣  Checking system health...")
        health = await client.get(f"{base_url}/health")
        print(f"   Status: {health.json()['status']}")
        
        # Get initial metrics
        print("\n2️⃣  Getting initial metrics...")
        metrics = await client.get(f"{base_url}/api/metrics")
        print(f"   {metrics.json()}")
        
        # Simulate brute force attack
        print("\n3️⃣  Simulating brute force attack...")
        event1 = await client.post(f"{base_url}/api/events", json={
            'event_type': 'brute_force_attack',
            'severity': 'high',
            'source': '192.168.1.100',
            'details': {
                'source_ip': '192.168.1.100',
                'target_user': 'admin',
                'failed_attempts': 15
            }
        })
        print(f"   Event submitted: {event1.json()['event_id']}")
        
        # Wait for processing
        await asyncio.sleep(3)
        
        # Simulate malware detection
        print("\n4️⃣  Simulating malware detection...")
        event2 = await client.post(f"{base_url}/api/events", json={
            'event_type': 'malware_detected',
            'severity': 'critical',
            'source': 'workstation-42',
            'details': {
                'system_id': 'workstation-42',
                'user_id': 'jsmith',
                'malware_type': 'ransomware'
            }
        })
        print(f"   Event submitted: {event2.json()['event_id']}")
        
        await asyncio.sleep(4)
        
        # Check responses
        print("\n5️⃣  Checking incident responses...")
        responses = await client.get(f"{base_url}/api/responses?limit=5")
        resp_data = responses.json()
        for resp in resp_data['responses']:
            print(f"   {resp['event_type']}: {len(resp['playbooks'])} playbooks executed")
        
        # Get audit log
        print("\n6️⃣  Retrieving audit log...")
        audit = await client.get(f"{base_url}/api/audit-log?limit=10")
        audit_data = audit.json()
        print(f"   Total audit entries: {len(audit_data['audit_log'])}")
        for entry in audit_data['audit_log'][:5]:
            print(f"   - {entry['action']} ({entry['status']})")
        
        # Final metrics
        print("\n7️⃣  Final metrics...")
        final_metrics = await client.get(f"{base_url}/api/metrics")
        print(f"   {final_metrics.json()}")
        
        print("\n" + "=" * 60)
        print("✅ Demo completed successfully!")
        print("\n📊 View real-time dashboard at: http://localhost:8000")
        print("📖 API documentation at: http://localhost:8000/docs")


if __name__ == "__main__":
    asyncio.run(run_demo())
EOF

echo -e "${GREEN}✅ Project setup complete!${NC}"
echo ""
echo "🎯 Next steps:"
echo "   1. Run tests: pytest tests/ -v"
echo "   2. Start system: ./start.sh"
echo "   3. Run demo: python demo.py (after system starts)"
echo "   4. Open dashboard: http://localhost:8000"
echo ""
echo "📝 Or use Docker: docker-compose up --build"

cd ..
echo ""
echo -e "${GREEN}🎉 Day 160: Automated Incident Response Setup Complete!${NC}"