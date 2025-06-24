#!/usr/bin/env python3
import asyncio
import ssl
import json
import gzip
import time
import socket
from datetime import datetime

class LogShipper:
    def __init__(self, server_host='localhost', server_port=8888, 
                 batch_size=100, batch_interval=1.0, use_tls=False):
        self.server_host = server_host
        self.server_port = server_port
        self.batch_size = batch_size
        self.batch_interval = batch_interval
        self.use_tls = use_tls
        self.log_batch = []
        self.writer = None
        self.reader = None
        self.connected = False
        self.last_flush = time.time()
        
    async def connect(self):
        try:
            if self.use_tls:
                context = ssl.create_default_context()
                context.check_hostname = False
                context.verify_mode = ssl.CERT_NONE
            else:
                context = None
                
            self.reader, self.writer = await asyncio.wait_for(
                asyncio.open_connection(
                    self.server_host, self.server_port, ssl=context
                ), timeout=10.0
            )
            self.connected = True
            print(f"Connected to {self.server_host}:{self.server_port}")
            return True
        except Exception as e:
            print(f"Connection failed: {e}")
            self.connected = False
            return False
    
    async def send_batch(self, logs):
        if not self.connected or not self.writer:
            return False
            
        try:
            # Convert logs to JSON and compress
            json_data = json.dumps(logs).encode('utf-8')
            compressed_data = gzip.compress(json_data)
            
            # Send length prefix + compressed data
            length = len(compressed_data)
            self.writer.write(length.to_bytes(4, byteorder='big'))
            self.writer.write(compressed_data)
            await self.writer.drain()
            
            return True
            
        except Exception as e:
            print(f"Failed to send batch: {e}")
            self.connected = False
            return False
    
    async def add_log(self, log_entry):
        self.log_batch.append(log_entry)
        
        # Check if we should flush
        should_flush = (
            len(self.log_batch) >= self.batch_size or
            time.time() - self.last_flush >= self.batch_interval
        )
        
        if should_flush and self.log_batch:
            batch_to_send = self.log_batch.copy()
            self.log_batch.clear()
            self.last_flush = time.time()
            return batch_to_send
        return None
    
    async def flush_batch(self):
        if self.log_batch:
            batch_to_send = self.log_batch.copy()
            self.log_batch.clear()
            self.last_flush = time.time()
            return batch_to_send
        return None
    
    async def ship_log(self, log_entry):
        batch = await self.add_log(log_entry)
        if batch:
            await self.send_batch(batch)
    
    async def start(self):
        return await self.connect()
    
    async def close(self):
        # Flush remaining logs
        batch = await self.flush_batch()
        if batch:
            await self.send_batch(batch)
            
        if self.writer:
            try:
                self.writer.close()
                await self.writer.wait_closed()
            except:
                pass
        self.connected = False

# Example usage
async def example_usage():
    shipper = LogShipper(batch_size=50, batch_interval=2.0, use_tls=False)
    
    if await shipper.start():
        # Send some test logs
        for i in range(10):
            log_entry = {
                'timestamp': datetime.now().isoformat(),
                'level': 'INFO',
                'message': f'Test log message {i}',
                'service': 'example-app'
            }
            await shipper.ship_log(log_entry)
            await asyncio.sleep(0.1)
        
        await shipper.close()
        print("Example completed successfully")

if __name__ == "__main__":
    asyncio.run(example_usage())