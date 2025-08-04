import re
import json
import asyncio
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import nltk
from nltk.sentiment import SentimentIntensityAnalyzer
from textblob import TextBlob
import pandas as pd
from collections import defaultdict

class NLPLogProcessor:
    """Natural Language Processing engine for log understanding"""
    
    def __init__(self):
        self.nlp_model = None
        self.sentiment_analyzer = None
        self.entity_patterns = {}
        self.intent_classifier = None
        self.processed_count = 0
        self.entity_cache = {}
        
    async def initialize(self):
        """Initialize NLP models and components"""
        print("🧠 Initializing NLP models...")
        
        # Initialize NLTK sentiment analyzer
        try:
            nltk.data.find('vader_lexicon')
        except LookupError:
            print("📦 Downloading NLTK data...")
            nltk.download('vader_lexicon', quiet=True)
            nltk.download('punkt', quiet=True)
            nltk.download('stopwords', quiet=True)
            nltk.download('averaged_perceptron_tagger', quiet=True)
        
        self.sentiment_analyzer = SentimentIntensityAnalyzer()
        print("✅ NLTK-based NLP models initialized successfully")
        
        # Define entity extraction patterns
        self.entity_patterns = {
            'ip_address': r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b',
            'email': r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
            'url': r'https?://[^\s<>"{}|\\^`\[\]]+',
            'error_code': r'\b[A-Z]+[-_]?\d{3,4}\b',
            'file_path': r'[A-Za-z]:[\\\/](?:[^\\\/\s]+[\\\/])*[^\\\/\s]*|\/(?:[^\/\s]+\/)*[^\/\s]*',
            'timestamp': r'\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2}:\d{2}',
            'database_table': r'\b(users?|orders?|products?|sessions?|logs?|events?)\b',
            'http_status': r'\b[1-5]\d{2}\b'
        }
        
        print("✅ NLP models initialized successfully")
    
    def extract_entities(self, text: str) -> Dict[str, List[str]]:
        """Extract entities from log text using regex patterns and NLTK"""
        entities = defaultdict(list)
        
        # Extract using regex patterns
        for entity_type, pattern in self.entity_patterns.items():
            matches = re.findall(pattern, text, re.IGNORECASE)
            if matches:
                entities[entity_type].extend(matches)
        
        # Extract using NLTK POS tagging for additional entities
        try:
            tokens = nltk.word_tokenize(text)
            pos_tags = nltk.pos_tag(tokens)
            
            # Extract proper nouns (NNP, NNPS) as potential entities
            proper_nouns = [word for word, pos in pos_tags if pos in ['NNP', 'NNPS']]
            if proper_nouns:
                entities['proper_nouns'] = proper_nouns
        except Exception as e:
            # Fallback if NLTK tagging fails
            pass
        
        return dict(entities)
    
    def classify_intent(self, text: str) -> Tuple[str, float]:
        """Classify the intent of the log message"""
        text_lower = text.lower()
        
        # Simple rule-based intent classification
        intent_patterns = {
            'error': ['error', 'exception', 'failed', 'failure', 'timeout', 'crashed'],
            'warning': ['warning', 'warn', 'deprecated', 'slow', 'retry'],
            'security': ['unauthorized', 'forbidden', 'authentication', 'login', 'blocked'],
            'performance': ['latency', 'response time', 'slow query', 'memory', 'cpu'],
            'info': ['started', 'completed', 'success', 'initialized', 'connected'],
            'debug': ['debug', 'trace', 'verbose', 'dump']
        }
        
        scores = {}
        for intent, keywords in intent_patterns.items():
            score = sum(1 for keyword in keywords if keyword in text_lower)
            if score > 0:
                scores[intent] = score / len(keywords)
        
        if not scores:
            return 'info', 0.5
        
        best_intent = max(scores, key=scores.get)
        confidence = scores[best_intent]
        
        return best_intent, confidence
    
    def analyze_sentiment(self, text: str) -> Dict[str, float]:
        """Analyze sentiment of log message"""
        if not self.sentiment_analyzer:
            return {'compound': 0.0, 'pos': 0.0, 'neu': 1.0, 'neg': 0.0}
        
        scores = self.sentiment_analyzer.polarity_scores(text)
        return scores
    
    def extract_keywords(self, text: str, top_k: int = 5) -> List[str]:
        """Extract important keywords from log text using NLTK"""
        try:
            # Tokenize and POS tag
            tokens = nltk.word_tokenize(text.lower())
            pos_tags = nltk.pos_tag(tokens)
            
            # Extract nouns, verbs, and adjectives
            stop_words = set(nltk.corpus.stopwords.words('english'))
            keywords = []
            
            for word, pos in pos_tags:
                if (len(word) > 2 and 
                    word not in stop_words and 
                    pos in ['NN', 'NNS', 'NNP', 'NNPS', 'VB', 'VBD', 'VBG', 'VBN', 'VBP', 'VBZ', 'JJ', 'JJR', 'JJS']):
                    keywords.append(word)
            
            return list(set(keywords))[:top_k]
        except Exception as e:
            # Fallback to simple word frequency
            words = re.findall(r'\b\w+\b', text.lower())
            common_words = ['the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by']
            keywords = [w for w in words if len(w) > 3 and w not in common_words]
            return list(set(keywords))[:top_k]
    
    async def process_log_message(self, log_message: Dict) -> Dict:
        """Process a single log message with NLP analysis"""
        text = log_message.get('message', '')
        
        if not text:
            return log_message
        
        # Extract entities
        entities = self.extract_entities(text)
        
        # Classify intent
        intent, intent_confidence = self.classify_intent(text)
        
        # Analyze sentiment
        sentiment = self.analyze_sentiment(text)
        
        # Extract keywords
        keywords = self.extract_keywords(text)
        
        # Create enriched log message
        enriched_log = {
            **log_message,
            'nlp_analysis': {
                'entities': entities,
                'intent': intent,
                'intent_confidence': intent_confidence,
                'sentiment': sentiment,
                'keywords': keywords,
                'processed_at': datetime.utcnow().isoformat(),
                'text_length': len(text),
                'word_count': len(text.split())
            }
        }
        
        self.processed_count += 1
        return enriched_log
    
    async def batch_process(self, log_messages: List[Dict]) -> List[Dict]:
        """Process multiple log messages in batch"""
        print(f"🔄 Processing batch of {len(log_messages)} log messages...")
        
        tasks = [self.process_log_message(msg) for msg in log_messages]
        results = await asyncio.gather(*tasks)
        
        print(f"✅ Processed {len(results)} messages successfully")
        return results
    
    def generate_summary(self, processed_logs: List[Dict]) -> Dict:
        """Generate summary insights from processed logs"""
        if not processed_logs:
            return {}
        
        intents = [log.get('nlp_analysis', {}).get('intent', 'unknown') for log in processed_logs]
        sentiments = [log.get('nlp_analysis', {}).get('sentiment', {}).get('compound', 0) 
                     for log in processed_logs]
        
        all_entities = defaultdict(list)
        all_keywords = []
        
        for log in processed_logs:
            nlp_data = log.get('nlp_analysis', {})
            entities = nlp_data.get('entities', {})
            keywords = nlp_data.get('keywords', [])
            
            for entity_type, entity_list in entities.items():
                all_entities[entity_type].extend(entity_list)
            
            all_keywords.extend(keywords)
        
        # Calculate statistics
        intent_counts = pd.Series(intents).value_counts().to_dict()
        avg_sentiment = sum(sentiments) / len(sentiments) if sentiments else 0
        
        keyword_counts = pd.Series(all_keywords).value_counts().head(10).to_dict()
        
        entity_counts = {}
        for entity_type, entity_list in all_entities.items():
            entity_counts[entity_type] = len(set(entity_list))
        
        return {
            'total_processed': len(processed_logs),
            'intent_distribution': intent_counts,
            'average_sentiment': round(avg_sentiment, 3),
            'top_keywords': keyword_counts,
            'entity_counts': entity_counts,
            'processing_timestamp': datetime.utcnow().isoformat()
        }
