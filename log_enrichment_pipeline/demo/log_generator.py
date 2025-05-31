"""
Log generator script for testing the enrichment pipeline.
"""

import time
import requests
import random

logs = [
    'INFO: User authentication successful',
    'ERROR: Database connection timeout',
    'WARN: High CPU usage detected',
    'DEBUG: Cache miss for key user:12345',
    'CRITICAL: Disk space critically low'
]

while True:
    log = random.choice(logs)
    try:
        requests.post('http://log-enrichment:8080/api/enrich',
                     json={'log_message': log, 'source': 'auto-generator'})
        print(f'Sent: {log}')
    except:
        print('Failed to send log')
    time.sleep(5)
