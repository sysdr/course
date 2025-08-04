import os
from dataclasses import dataclass

@dataclass
class NLPConfig:
    """Configuration for NLP Log Processor"""
    
    # Model settings
    # spacy_model: str = "en_core_web_sm"  # Not used - using NLTK instead
    max_text_length: int = 1000
    batch_size: int = 32
    
    # Processing settings
    extract_keywords: bool = True
    max_keywords: int = 10
    sentiment_analysis: bool = True
    entity_extraction: bool = True
    
    # Server settings
    host: str = "0.0.0.0"
    port: int = int(os.environ.get('PORT', 5000))
    debug: bool = True
    
    # File paths
    data_dir: str = "data"
    models_dir: str = "data/models"
    logs_dir: str = "data/logs"
    
    def __post_init__(self):
        # Create directories if they don't exist
        os.makedirs(self.data_dir, exist_ok=True)
        os.makedirs(self.models_dir, exist_ok=True)
        os.makedirs(self.logs_dir, exist_ok=True)

# Global config instance
config = NLPConfig()
