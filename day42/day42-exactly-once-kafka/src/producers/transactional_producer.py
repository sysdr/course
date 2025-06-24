"""Transactional producer for exactly-once processing"""

import json
import time
import uuid
from datetime import datetime
from typing import Dict, Any, Optional
from confluent_kafka import Producer, KafkaError
import structlog

logger = structlog.get_logger()

class TransactionalProducer:
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.producer = Producer(config)
        self.transaction_active = False
        
        # Initialize transactions
        self.producer.init_transactions()
        logger.info("Transactional producer initialized", 
                   transactional_id=config.get('transactional.id'))
    
    def begin_transaction(self):
        """Begin a new transaction"""
        if self.transaction_active:
            raise RuntimeError("Transaction already active")
        
        self.producer.begin_transaction()
        self.transaction_active = True
        logger.info("Transaction started")
    
    def send_payment_transfer(self, from_account: str, to_account: str, 
                            amount: float, transaction_id: Optional[str] = None) -> str:
        """Send payment transfer with exactly-once semantics"""
        
        if not self.transaction_active:
            raise RuntimeError("No active transaction")
        
        if transaction_id is None:
            transaction_id = str(uuid.uuid4())
        
        # Create transfer message
        transfer_msg = {
            'transaction_id': transaction_id,
            'from_account': from_account,
            'to_account': to_account,
            'amount': amount,
            'timestamp': datetime.utcnow().isoformat(),
            'type': 'transfer'
        }
        
        # Create account update messages
        debit_msg = {
            'account': from_account,
            'amount': -amount,
            'transaction_id': transaction_id,
            'timestamp': datetime.utcnow().isoformat(),
            'type': 'debit'
        }
        
        credit_msg = {
            'account': to_account,
            'amount': amount,
            'transaction_id': transaction_id,
            'timestamp': datetime.utcnow().isoformat(),
            'type': 'credit'
        }
        
        try:
            # Send all messages within the same transaction
            self.producer.produce('banking-transfers', 
                                key=transaction_id,
                                value=json.dumps(transfer_msg))
            
            self.producer.produce('account-balance-updates',
                                key=from_account,
                                value=json.dumps(debit_msg))
            
            self.producer.produce('account-balance-updates',
                                key=to_account,
                                value=json.dumps(credit_msg))
            
            logger.info("Payment transfer sent", 
                       transaction_id=transaction_id,
                       from_account=from_account,
                       to_account=to_account,
                       amount=amount)
            
            return transaction_id
            
        except Exception as e:
            logger.error("Failed to send payment transfer", error=str(e))
            raise
    
    def commit_transaction(self):
        """Commit the current transaction"""
        if not self.transaction_active:
            raise RuntimeError("No active transaction")
        
        try:
            self.producer.commit_transaction()
            self.transaction_active = False
            logger.info("Transaction committed successfully")
        except Exception as e:
            logger.error("Failed to commit transaction", error=str(e))
            self.abort_transaction()
            raise
    
    def abort_transaction(self):
        """Abort the current transaction"""
        if not self.transaction_active:
            return
        
        try:
            self.producer.abort_transaction()
            self.transaction_active = False
            logger.info("Transaction aborted")
        except Exception as e:
            logger.error("Failed to abort transaction", error=str(e))
    
    def close(self):
        """Close the producer"""
        if self.transaction_active:
            self.abort_transaction()
        self.producer.flush()
        logger.info("Producer closed")

def create_sample_transfers():
    """Create sample transfer data for testing"""
    return [
        {'from': 'ACC001', 'to': 'ACC002', 'amount': 100.50},
        {'from': 'ACC002', 'to': 'ACC003', 'amount': 250.75},
        {'from': 'ACC003', 'to': 'ACC001', 'amount': 75.25},
        {'from': 'ACC001', 'to': 'ACC003', 'amount': 500.00},
        {'from': 'ACC002', 'to': 'ACC001', 'amount': 150.00}
    ]
