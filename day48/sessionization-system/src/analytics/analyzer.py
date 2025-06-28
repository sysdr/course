import asyncio
import time
from typing import Dict, List, Any
from collections import defaultdict, deque
import numpy as np
import structlog

logger = structlog.get_logger()

class SessionAnalyzer:
    """Real-time session analytics and pattern detection"""
    
    def __init__(self):
        self.session_metrics = defaultdict(list)
        self.user_patterns = defaultdict(dict)
        self.hourly_stats = deque(maxlen=24)  # Keep 24 hours of data
        self.realtime_metrics = {
            'sessions_this_hour': 0,
            'avg_session_length': 0,
            'bounce_rate': 0,
            'popular_pages': {},
            'conversion_rate': 0
        }
        
    async def analyze_session(self, session_data: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze individual session and update metrics"""
        try:
            analysis = {
                'session_quality': self._calculate_session_quality(session_data),
                'user_engagement': self._calculate_engagement_score(session_data),
                'session_type': self._classify_session_type(session_data),
                'anomaly_score': await self._calculate_anomaly_score(session_data)
            }
            
            # Update real-time metrics
            await self._update_realtime_metrics(session_data, analysis)
            
            return analysis
            
        except Exception as e:
            logger.error("Error analyzing session", error=str(e))
            return {}
    
    def _calculate_session_quality(self, session_data: Dict[str, Any]) -> float:
        """Calculate session quality score (0-100)"""
        duration = session_data.get('duration', 0)
        pages_visited = session_data.get('pages_visited', 0)
        events_count = session_data.get('total_events', 0)
        
        # Quality factors
        duration_score = min(duration / 600, 1.0) * 40  # Up to 10 minutes = 40 points
        depth_score = min(pages_visited / 5, 1.0) * 30  # Up to 5 pages = 30 points
        engagement_score = min(events_count / 20, 1.0) * 30  # Up to 20 events = 30 points
        
        return duration_score + depth_score + engagement_score
    
    def _calculate_engagement_score(self, session_data: Dict[str, Any]) -> str:
        """Classify user engagement level"""
        quality = self._calculate_session_quality(session_data)
        
        if quality >= 80:
            return "highly_engaged"
        elif quality >= 50:
            return "moderately_engaged"
        elif quality >= 20:
            return "low_engagement"
        else:
            return "bounce"
    
    def _classify_session_type(self, session_data: Dict[str, Any]) -> str:
        """Classify session based on behavior patterns"""
        duration = session_data.get('duration', 0)
        pages_visited = session_data.get('pages_visited', 0)
        events = session_data.get('events', [])
        
        # Quick bounce
        if duration < 30 and pages_visited <= 1:
            return "bounce"
        
        # Browser session
        if pages_visited >= 5 and duration > 300:
            return "exploration"
        
        # Focused session
        if pages_visited <= 3 and duration > 120:
            return "focused_task"
        
        # Shopping behavior (look for purchase-related events)
        purchase_keywords = ['cart', 'checkout', 'purchase', 'buy']
        has_purchase_intent = any(
            any(keyword in event.get('page_url', '').lower() for keyword in purchase_keywords)
            for event in events
        )
        
        if has_purchase_intent:
            return "shopping"
        
        return "general_browsing"
    
    async def _calculate_anomaly_score(self, session_data: Dict[str, Any]) -> float:
        """Calculate how unusual this session is (0-1, higher = more anomalous)"""
        # Simple anomaly detection based on statistical deviation
        user_id = session_data.get('user_id')
        
        if user_id not in self.user_patterns:
            return 0.0  # No historical data
        
        user_history = self.user_patterns[user_id]
        current_duration = session_data.get('duration', 0)
        
        # Compare with user's typical session duration
        if 'avg_duration' in user_history:
            duration_deviation = abs(current_duration - user_history['avg_duration'])
            max_deviation = user_history.get('max_duration', current_duration) * 2
            anomaly_score = min(duration_deviation / max_deviation, 1.0) if max_deviation > 0 else 0.0
            return anomaly_score
        
        return 0.0
    
    async def _update_realtime_metrics(self, session_data: Dict[str, Any], analysis: Dict[str, Any]):
        """Update real-time analytics metrics"""
        # Update session count
        self.realtime_metrics['sessions_this_hour'] += 1
        
        # Update average session length
        duration = session_data.get('duration', 0)
        current_avg = self.realtime_metrics['avg_session_length']
        count = self.realtime_metrics['sessions_this_hour']
        self.realtime_metrics['avg_session_length'] = (current_avg * (count - 1) + duration) / count
        
        # Update bounce rate
        if analysis.get('user_engagement') == 'bounce':
            bounce_count = getattr(self, '_bounce_count', 0) + 1
            self.realtime_metrics['bounce_rate'] = bounce_count / count
            self._bounce_count = bounce_count
        
        # Update popular pages
        events = session_data.get('events', [])
        for event in events:
            page_url = event.get('page_url', '')
            if page_url:
                self.realtime_metrics['popular_pages'][page_url] = \
                    self.realtime_metrics['popular_pages'].get(page_url, 0) + 1
        
        # Update user patterns
        user_id = session_data.get('user_id')
        if user_id:
            if user_id not in self.user_patterns:
                self.user_patterns[user_id] = {
                    'session_count': 0,
                    'total_duration': 0,
                    'avg_duration': 0,
                    'max_duration': 0
                }
            
            patterns = self.user_patterns[user_id]
            patterns['session_count'] += 1
            patterns['total_duration'] += duration
            patterns['avg_duration'] = patterns['total_duration'] / patterns['session_count']
            patterns['max_duration'] = max(patterns['max_duration'], duration)
    
    async def get_analytics_dashboard_data(self) -> Dict[str, Any]:
        """Get comprehensive analytics for dashboard"""
        # Get top pages (sorted by popularity)
        sorted_pages = sorted(
            self.realtime_metrics['popular_pages'].items(),
            key=lambda x: x[1],
            reverse=True
        )[:10]
        
        # Calculate session type distribution
        session_types = defaultdict(int)
        for user_pattern in self.user_patterns.values():
            # This is simplified - in real implementation, you'd track session types per user
            session_types['general_browsing'] += user_pattern.get('session_count', 0)
        
        return {
            'realtime_metrics': self.realtime_metrics,
            'popular_pages': dict(sorted_pages),
            'session_type_distribution': dict(session_types),
            'user_engagement_trends': self._calculate_engagement_trends(),
            'anomaly_alerts': await self._get_recent_anomalies()
        }
    
    def _calculate_engagement_trends(self) -> Dict[str, List[float]]:
        """Calculate engagement trends over time"""
        # Simplified implementation - in production, you'd use time-series data
        return {
            'hourly_sessions': [50, 75, 100, 120, 90, 85],  # Mock data
            'engagement_scores': [65, 70, 68, 72, 69, 71],  # Mock data
            'bounce_rates': [0.3, 0.25, 0.28, 0.22, 0.26, 0.24]  # Mock data
        }
    
    async def _get_recent_anomalies(self) -> List[Dict[str, Any]]:
        """Get recent anomalous sessions"""
        # In production, you'd maintain a list of anomalous sessions
        return [
            {
                'user_id': 'user_123',
                'anomaly_type': 'unusual_duration',
                'score': 0.85,
                'timestamp': time.time() - 300
            }
        ]
