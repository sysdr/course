"""Transaction monitoring for exactly-once processing"""

import time
import threading
from datetime import datetime, timedelta
from typing import Dict, Any, List
from sqlalchemy import create_engine, func
from sqlalchemy.orm import sessionmaker
import structlog

from ..models import Transaction, Account, ProcessingOffset

logger = structlog.get_logger()

class TransactionMonitor:
    def __init__(self, database_url: str):
        self.engine = create_engine(database_url)
        self.SessionLocal = sessionmaker(bind=self.engine)
        self.stats = {
            'total_transactions': 0,
            'completed_transactions': 0,
            'failed_transactions': 0,
            'pending_transactions': 0,
            'processing_rate': 0.0,
            'last_updated': datetime.utcnow()
        }
        self.running = False
        self.monitor_thread = None
    
    def get_transaction_stats(self) -> Dict[str, Any]:
        """Get transaction processing statistics"""
        session = self.SessionLocal()
        
        try:
            total = session.query(func.count(Transaction.id)).scalar()
            completed = session.query(func.count(Transaction.id)).filter(
                Transaction.status == 'completed'
            ).scalar()
            failed = session.query(func.count(Transaction.id)).filter(
                Transaction.status == 'failed'
            ).scalar()
            pending = session.query(func.count(Transaction.id)).filter(
                Transaction.status.in_(['pending', 'processing'])
            ).scalar()
            
            # Calculate processing rate (transactions per minute)
            one_minute_ago = datetime.utcnow() - timedelta(minutes=1)
            recent_completed = session.query(func.count(Transaction.id)).filter(
                Transaction.status == 'completed',
                Transaction.processed_at >= one_minute_ago
            ).scalar()
            
            self.stats.update({
                'total_transactions': total or 0,
                'completed_transactions': completed or 0,
                'failed_transactions': failed or 0,
                'pending_transactions': pending or 0,
                'processing_rate': recent_completed or 0,
                'last_updated': datetime.utcnow()
            })
            
            return self.stats.copy()
            
        finally:
            session.close()
    
    def get_account_balances(self) -> List[Dict[str, Any]]:
        """Get current account balances"""
        session = self.SessionLocal()
        
        try:
            accounts = session.query(Account).all()
            return [
                {
                    'account_number': acc.account_number,
                    'balance': float(acc.balance),
                    'last_updated': acc.updated_at.isoformat()
                }
                for acc in accounts
            ]
        finally:
            session.close()
    
    def get_recent_transactions(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Get recent transactions"""
        session = self.SessionLocal()
        
        try:
            transactions = session.query(Transaction).order_by(
                Transaction.created_at.desc()
            ).limit(limit).all()
            
            return [
                {
                    'transaction_id': tx.transaction_id,
                    'from_account': tx.from_account,
                    'to_account': tx.to_account,
                    'amount': float(tx.amount),
                    'status': tx.status,
                    'created_at': tx.created_at.isoformat(),
                    'processed_at': tx.processed_at.isoformat() if tx.processed_at else None
                }
                for tx in transactions
            ]
        finally:
            session.close()
    
    def check_exactly_once_guarantee(self) -> Dict[str, Any]:
        """Verify exactly-once processing guarantee"""
        session = self.SessionLocal()
        
        try:
            # Check for duplicate transaction IDs
            duplicate_check = session.query(
                Transaction.transaction_id,
                func.count(Transaction.id).label('count')
            ).group_by(Transaction.transaction_id).having(
                func.count(Transaction.id) > 1
            ).all()
            
            duplicates = [
                {'transaction_id': dup[0], 'count': dup[1]}
                for dup in duplicate_check
            ]
            
            # Check processing consistency
            total_balance = session.query(func.sum(Account.balance)).scalar() or 0
            
            return {
                'duplicate_transactions': duplicates,
                'total_system_balance': float(total_balance),
                'guarantee_status': 'VIOLATED' if duplicates else 'MAINTAINED',
                'check_timestamp': datetime.utcnow().isoformat()
            }
            
        finally:
            session.close()
    
    def start_monitoring(self):
        """Start background monitoring"""
        self.running = True
        self.monitor_thread = threading.Thread(target=self._monitor_loop)
        self.monitor_thread.start()
        logger.info("Transaction monitoring started")
    
    def _monitor_loop(self):
        """Background monitoring loop"""
        while self.running:
            try:
                self.get_transaction_stats()
                time.sleep(10)  # Update every 10 seconds
            except Exception as e:
                logger.error("Monitoring error", error=str(e))
                time.sleep(30)
    
    def stop_monitoring(self):
        """Stop background monitoring"""
        self.running = False
        if self.monitor_thread:
            self.monitor_thread.join()
        logger.info("Transaction monitoring stopped")
