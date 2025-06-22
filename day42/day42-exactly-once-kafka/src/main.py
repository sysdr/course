"""Main application for exactly-once processing demo"""

import sys
import time
import threading
import signal
import uuid
from decimal import Decimal
from config.kafka_config import KafkaConfig, DATABASE_URL, TOPICS
from src.models import create_tables, Account, get_session
from src.producers.transactional_producer import TransactionalProducer, create_sample_transfers
from src.consumers.exactly_once_consumer import ExactlyOnceConsumer
from src.monitoring.transaction_monitor import TransactionMonitor
from decimal import Decimal
import structlog


# Configure logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.dev.ConsoleRenderer()
    ],
    wrapper_class=structlog.stdlib.BoundLogger,
    logger_factory=structlog.stdlib.LoggerFactory(),
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

def setup_database():
    """Initialize database with sample accounts"""
    from decimal import Decimal
    
    engine = create_tables(DATABASE_URL)
    session = get_session(engine)
    
    # Check if accounts already exist
    existing_accounts = session.query(Account).count()
    if existing_accounts > 0:
        logger.info("Database already initialized")
        session.close()
        return
    
    # Create sample accounts
    accounts = [
        Account(account_number='ACC001', balance=Decimal('1000.00')),
        Account(account_number='ACC002', balance=Decimal('1500.00')),
        Account(account_number='ACC003', balance=Decimal('2000.00'))
    ]
    
    for account in accounts:
        session.add(account)
    
    session.commit()
    session.close()
    
    logger.info("Database initialized with sample accounts")

def run_producer():
    """Run the transactional producer"""
    config = KafkaConfig()
    producer = TransactionalProducer(config.producer_config)
    
    try:
        sample_transfers = create_sample_transfers()
        
        for i, transfer in enumerate(sample_transfers):
            try:
                # Begin transaction
                producer.begin_transaction()
                
                # Send transfer
                tx_id = producer.send_payment_transfer(
                    from_account=transfer['from'],
                    to_account=transfer['to'],
                    amount=transfer['amount']
                )
                
                # Commit transaction
                producer.commit_transaction()
                
                logger.info(f"Transfer {i+1} sent successfully", 
                           transaction_id=tx_id)
                
                time.sleep(2)  # Wait between transfers
                
            except Exception as e:
                logger.error(f"Transfer {i+1} failed", error=str(e))
                producer.abort_transaction()
        
        # Keep producing for demo
        while True:
            try:
                transfer = sample_transfers[len(sample_transfers) % 5]
                
                producer.begin_transaction()
                tx_id = producer.send_payment_transfer(
                    from_account=transfer['from'],
                    to_account=transfer['to'],
                    amount=transfer['amount']
                )
                producer.commit_transaction()
                
                logger.info("Continuous transfer sent", transaction_id=tx_id)
                time.sleep(10)  # Wait 10 seconds
                
            except KeyboardInterrupt:
                break
            except Exception as e:
                logger.error("Continuous transfer failed", error=str(e))
                producer.abort_transaction()
                time.sleep(5)
    
    finally:
        producer.close()

def run_consumer():
    """Run the exactly-once consumer"""
    config = KafkaConfig()
    consumer = ExactlyOnceConsumer(config.consumer_config, DATABASE_URL)
    
    # Subscribe to transfer topic
    consumer.subscribe([TOPICS['transfers']])
    
    try:
        consumer.consume_messages()
    except KeyboardInterrupt:
        logger.info("Consumer interrupted")
    finally:
        consumer.close()

def run_monitor():
    """Run the transaction monitor"""
    monitor = TransactionMonitor(DATABASE_URL)
    monitor.start_monitoring()
    
    try:
        while True:
            stats = monitor.get_transaction_stats()
            guarantee_check = monitor.check_exactly_once_guarantee()
            
            print("\n" + "="*50)
            print("EXACTLY-ONCE PROCESSING MONITOR")
            print("="*50)
            print(f"Total Transactions: {stats['total_transactions']}")
            print(f"Completed: {stats['completed_transactions']}")
            print(f"Failed: {stats['failed_transactions']}")
            print(f"Pending: {stats['pending_transactions']}")
            print(f"Processing Rate: {stats['processing_rate']} tx/min")
            print(f"Guarantee Status: {guarantee_check['guarantee_status']}")
            
            if guarantee_check['duplicate_transactions']:
                print("⚠️  DUPLICATES DETECTED:")
                for dup in guarantee_check['duplicate_transactions']:
                    print(f"  - {dup['transaction_id']}: {dup['count']} copies")
            
            time.sleep(15)
            
    except KeyboardInterrupt:
        logger.info("Monitor interrupted")
    finally:
        monitor.stop_monitoring()

def main():
    if len(sys.argv) < 2:
        print("Usage: python -m src.main <producer|consumer|monitor|web>")
        sys.exit(1)
    
    # Setup database
    setup_database()
    
    mode = sys.argv[1]
    
    if mode == 'producer':
        run_producer()
    elif mode == 'consumer':
        run_consumer()
    elif mode == 'monitor':
        run_monitor()
    elif mode == 'web':
        from web.dashboard import app, socketio, monitor
        monitor.start_monitoring()
        socketio.run(app, host='0.0.0.0', port=5000, debug=False)
    else:
        print("Invalid mode. Use: producer, consumer, monitor, or web")
        sys.exit(1)

if __name__ == '__main__':
    main()
