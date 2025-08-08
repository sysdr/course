import os

class Settings:
    DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://postgres:postgres@localhost:5432/logdb')
    REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
    MAX_BATCH_SIZE = int(os.getenv('MAX_BATCH_SIZE', '10000'))
    DEFAULT_CHUNK_SIZE = int(os.getenv('DEFAULT_CHUNK_SIZE', '1000'))
    MAX_CONCURRENT_CHUNKS = int(os.getenv('MAX_CONCURRENT_CHUNKS', '10'))

settings = Settings()
