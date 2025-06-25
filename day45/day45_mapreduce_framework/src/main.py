#!/usr/bin/env python3
import os
import sys
import logging
import asyncio
from pathlib import Path

# Add src to Python path
sys.path.insert(0, str(Path(__file__).parent))

from mapreduce.coordinator import JobCoordinator
from mapreduce.job import MapReduceConfig
from mapreduce.analyzers import (
    word_count_mapper, word_count_reducer,
    pattern_frequency_mapper, pattern_frequency_reducer,
    comprehensive_log_mapper, comprehensive_log_reducer
)
from utils.data_generator import generate_sample_data
from web.app import app
import uvicorn

def setup_logging():
    """Setup logging configuration"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler('logs/mapreduce.log'),
            logging.StreamHandler()
        ]
    )

def main():
    """Main application entry point"""
    print("🚀 MapReduce Framework Starting...")
    
    # Setup logging
    os.makedirs('logs', exist_ok=True)
    setup_logging()
    
    # Generate sample data if not exists
    if not os.path.exists('data/input/json_logs.txt'):
        print("📊 Generating sample data...")
        generate_sample_data()
    
    # Start web application
    print("🌐 Starting web interface on http://localhost:8080")
    uvicorn.run(app, host="0.0.0.0", port=8080, log_level="info")

if __name__ == "__main__":
    main()
