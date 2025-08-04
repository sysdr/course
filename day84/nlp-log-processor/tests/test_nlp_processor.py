import pytest
import asyncio
import sys
import os

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from nlp.log_processor import NLPLogProcessor

class TestNLPLogProcessor:
    
    @pytest.fixture
    async def processor(self):
        processor = NLPLogProcessor()
        await processor.initialize()
        return processor
    
    @pytest.mark.asyncio
    async def test_entity_extraction(self, processor):
        """Test entity extraction functionality"""
        proc = await processor
        test_message = "ERROR: Connection failed to 192.168.1.100 for user admin@company.com"
        
        entities = proc.extract_entities(test_message)
        
        assert 'ip_address' in entities
        assert '192.168.1.100' in entities['ip_address']
        assert 'email' in entities
        assert 'admin@company.com' in entities['email']
    
    @pytest.mark.asyncio
    async def test_intent_classification(self, processor):
        """Test intent classification"""
        proc = await processor
        test_cases = [
            ("ERROR: Database connection failed", "error"),
            ("WARNING: High memory usage detected", "warning"),
            ("INFO: User logged in successfully", "info"),
            ("SECURITY: Unauthorized access attempt", "security")
        ]
        
        for message, expected_intent in test_cases:
            intent, confidence = proc.classify_intent(message)
            assert intent == expected_intent
            assert confidence > 0
    
    @pytest.mark.asyncio
    async def test_sentiment_analysis(self, processor):
        """Test sentiment analysis"""
        proc = await processor
        positive_message = "INFO: Backup completed successfully"
        negative_message = "CRITICAL: System failure detected"
        
        positive_sentiment = proc.analyze_sentiment(positive_message)
        negative_sentiment = proc.analyze_sentiment(negative_message)
        
        assert 'compound' in positive_sentiment
        assert 'compound' in negative_sentiment
        assert positive_sentiment['compound'] >= negative_sentiment['compound']
    
    @pytest.mark.asyncio
    async def test_keyword_extraction(self, processor):
        """Test keyword extraction"""
        proc = await processor
        message = "Database connection timeout occurred during backup process"
        
        keywords = proc.extract_keywords(message)
        
        assert len(keywords) > 0
        assert any(keyword in ['database', 'connection', 'timeout', 'backup'] for keyword in keywords)
    
    @pytest.mark.asyncio
    async def test_log_processing(self, processor):
        """Test complete log message processing"""
        proc = await processor
        log_message = {
            'timestamp': '2025-06-16T10:00:00Z',
            'message': 'ERROR: Failed to connect to database server 192.168.1.100',
            'source': 'web-app',
            'level': 'ERROR'
        }
        
        result = await proc.process_log_message(log_message)
        
        assert 'nlp_analysis' in result
        assert 'entities' in result['nlp_analysis']
        assert 'intent' in result['nlp_analysis']
        assert 'sentiment' in result['nlp_analysis']
        assert 'keywords' in result['nlp_analysis']
    
    @pytest.mark.asyncio
    async def test_batch_processing(self, processor):
        """Test batch processing of log messages"""
        proc = await processor
        log_messages = [
            {'message': 'INFO: User login successful'},
            {'message': 'ERROR: Database connection failed'},
            {'message': 'WARNING: High CPU usage detected'}
        ]
        
        results = await proc.batch_process(log_messages)
        
        assert len(results) == 3
        for result in results:
            assert 'nlp_analysis' in result
    
    @pytest.mark.asyncio
    async def test_summary_generation(self, processor):
        """Test summary generation from processed logs"""
        proc = await processor
        processed_logs = [
            {'nlp_analysis': {'intent': 'error', 'sentiment': {'compound': -0.5}, 'keywords': ['database'], 'entities': {'ip_address': ['192.168.1.1']}}},
            {'nlp_analysis': {'intent': 'info', 'sentiment': {'compound': 0.2}, 'keywords': ['login'], 'entities': {'email': ['user@test.com']}}},
            {'nlp_analysis': {'intent': 'warning', 'sentiment': {'compound': -0.1}, 'keywords': ['memory'], 'entities': {}}}
        ]
        
        summary = proc.generate_summary(processed_logs)
        
        assert 'total_processed' in summary
        assert 'intent_distribution' in summary
        assert 'average_sentiment' in summary
        assert 'top_keywords' in summary
        assert 'entity_counts' in summary
        
        assert summary['total_processed'] == 3
        assert 'error' in summary['intent_distribution']
        assert 'info' in summary['intent_distribution']
        assert 'warning' in summary['intent_distribution']
