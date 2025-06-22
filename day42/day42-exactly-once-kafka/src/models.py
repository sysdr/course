"""Database models for exactly-once processing demo"""

from sqlalchemy import Column, Integer, String, DateTime, Boolean, create_engine
from sqlalchemy.types import DECIMAL
from sqlalchemy.orm import declarative_base, sessionmaker
from datetime import datetime
import uuid

Base = declarative_base()

class Account(Base):
    __tablename__ = 'accounts'
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    account_number = Column(String, unique=True, nullable=False)
    balance = Column(DECIMAL(15, 2), default=0.00)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class Transaction(Base):
    __tablename__ = 'transactions'
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    transaction_id = Column(String, unique=True, nullable=False)  # Idempotency key
    from_account = Column(String, nullable=False)
    to_account = Column(String, nullable=False)
    amount = Column(DECIMAL(15, 2), nullable=False)
    status = Column(String, default='pending')  # pending, completed, failed
    processed = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    processed_at = Column(DateTime)

class ProcessingOffset(Base):
    __tablename__ = 'processing_offsets'
    
    id = Column(Integer, primary_key=True)
    topic = Column(String, nullable=False)
    partition = Column(Integer, nullable=False)
    offset = Column(Integer, nullable=False)
    consumer_group = Column(String, nullable=False)
    last_processed = Column(DateTime, default=datetime.utcnow)

def create_tables(database_url: str):
    engine = create_engine(database_url)
    Base.metadata.create_all(engine)
    return engine

def get_session(engine):
    SessionLocal = sessionmaker(bind=engine)
    return SessionLocal()
