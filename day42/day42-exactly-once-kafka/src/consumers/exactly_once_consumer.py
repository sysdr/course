"""Exactly-once consumer for payment processing"""

import json
import time
from datetime import datetime
from typing import Dict, Any, List
from decimal import Decimal
from confluent_kafka import Consumer, KafkaError, TopicPartition
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import structlog

from ..models import Account, Transaction, ProcessingOffset, get_session

logger = structlog.get_logger()

class ExactlyOnceConsumer:
    def __init__(self, config: Dict[str, Any], database_url: str):
        self.config = config
        self.consumer = Consumer(config)
        self.engine = create_engine(database_url)
        self.SessionLocal = sessionmaker(bind=self.engine)
        self.running = False
        
        logger.info("Exactly-once consumer initialized", 
                   group_id=config.get('group.id'))
    
    def subscribe(self, topics: List[str]):
        """Subscribe to topics"""
        self.consumer.subscribe(topics)
        logger.info("Subscribed to topics", topics=topics)
    
    def process_transfer_message(self, message) -> bool:
        """Process a transfer message with exactly-once semantics"""
        try:
            # Parse message
            data = json.loads(message.value().decode('utf-8'))
            transaction_id = data['transaction_id']
            
            # Convert amount to Decimal for consistent arithmetic
            amount = Decimal(str(data['amount']))
            
            # Create database session
            session = self.SessionLocal()
            
            try:
                # Check if already processed (idempotency)
                existing = session.query(Transaction).filter_by(
                    transaction_id=transaction_id
                ).first()
                
                if existing and existing.processed:
                    logger.info("Transaction already processed, skipping",
                              transaction_id=transaction_id)
                    session.close()
                    return True
                
                # Process the transfer
                if existing:
                    # Update existing transaction
                    transaction = existing
                else:
                    # Create new transaction record
                    transaction = Transaction(
                        transaction_id=transaction_id,
                        from_account=data['from_account'],
                        to_account=data['to_account'],
                        amount=amount,
                        status='processing'
                    )
                    session.add(transaction)
                
                # Update account balances
                from_account = session.query(Account).filter_by(
                    account_number=data['from_account']
                ).first()
                
                to_account = session.query(Account).filter_by(
                    account_number=data['to_account']
                ).first()
                
                if not from_account or not to_account:
                    logger.error("Account not found", 
                               from_account=data['from_account'],
                               to_account=data['to_account'])
                    transaction.status = 'failed'
                    session.commit()
                    session.close()
                    return True
                
                # Check sufficient balance
                if from_account.balance < amount:
                    logger.error("Insufficient balance",
                               account=data['from_account'],
                               balance=float(from_account.balance),
                               amount=float(amount))
                    transaction.status = 'failed'
                    session.commit()
                    session.close()
                    return True
                
                # Perform transfer
                from_account.balance -= amount
                to_account.balance += amount
                from_account.updated_at = datetime.utcnow()
                to_account.updated_at = datetime.utcnow()
                
                # Mark transaction as completed
                transaction.status = 'completed'
                transaction.processed = True
                transaction.processed_at = datetime.utcnow()
                
                # Store processing offset atomically with business logic
                offset_record = ProcessingOffset(
                    topic=message.topic(),
                    partition=message.partition(),
                    offset=message.offset(),
                    consumer_group=self.config['group.id']
                )
                session.add(offset_record)
                
                # Commit everything atomically
                session.commit()
                
                logger.info("Transfer processed successfully",
                           transaction_id=transaction_id,
                           from_account=data['from_account'],
                           to_account=data['to_account'],
                           amount=float(amount))
                
                session.close()
                return True
                
            except Exception as e:
                session.rollback()
                session.close()
                logger.error("Failed to process transfer", 
                           transaction_id=transaction_id, 
                           error=str(e))
                raise
                
        except Exception as e:
            logger.error("Failed to parse message", error=str(e))
            return False
    
    def consume_messages(self):
        """Main consumption loop with exactly-once processing"""
        self.running = True
        
        while self.running:
            try:
                msg = self.consumer.poll(timeout=1.0)
                
                if msg is None:
                    continue
                
                if msg.error():
                    if msg.error().code() == KafkaError._PARTITION_EOF:
                        continue
                    else:
                        logger.error("Consumer error", error=msg.error())
                        continue
                
                # Process message with exactly-once semantics
                success = self.process_transfer_message(msg)
                
                if success:
                    # Manually commit offset only after successful processing
                    self.consumer.commit(message=msg)
                    logger.debug("Offset committed", 
                               topic=msg.topic(),
                               partition=msg.partition(),
                               offset=msg.offset())
                else:
                    logger.warning("Message processing failed, will retry",
                                 topic=msg.topic(),
                                 partition=msg.partition(),
                                 offset=msg.offset())
                
            except KeyboardInterrupt:
                logger.info("Received interrupt signal")
                break
            except Exception as e:
                logger.error("Unexpected error in consumption loop", error=str(e))
                time.sleep(5)  # Brief pause before retrying
        
        self.close()
    
    def close(self):
        """Close the consumer"""
        self.running = False
        self.consumer.close()
        logger.info("Consumer closed")
