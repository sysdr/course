#!/usr/bin/env python3
import asyncio
import ssl
import json
import time
import gzip
import threading
import socket
from datetime import datetime

class LogMetrics:
    def __init__(self):
        self.logs_received = 0
        self.bytes_received = 0
        self.start_time = time.time()
        self.lock = threading.Lock()
    
    def add_log(self, size):
        with self.lock:
            self.logs_received += 1
            self.bytes_received += size
    
    def get_stats(self):
        with self.lock:
            current_time = time.time()
            elapsed = current_time - self.start_time
            logs_per_sec = self.logs_received / elapsed if elapsed > 0 else 0
            mb_per_sec = (self.bytes_received / 1024 / 1024) / elapsed if elapsed > 0 else 0
            return {
                'logs_received': self.logs_received,
                'logs_per_second': logs_per_sec,
                'mb_per_second': mb_per_sec,
                'elapsed_time': elapsed
            }

class TCPLogServer:
    def __init__(self, host='localhost', port=8888, use_tls=False, cert_file='certs/server.crt', key_file='certs/server.key'):
        self.host = host
        self.port = port
        self.use_tls = use_tls
        self.cert_file = cert_file
        self.key_file = key_file
        self.metrics = LogMetrics()
        self.clients = set()
        self.running = True
        
    async def handle_client(self, reader, writer):
        client_addr = writer.get_extra_info('peername')
        self.clients.add(writer)
        print(f"Client connected: {client_addr}")
        
        try:
            while self.running:
                try:
                    # Read message length (4 bytes)
                    length_data = await asyncio.wait_for(reader.read(4), timeout=1.0)
                    if not length_data or len(length_data) != 4:
                        break
                        
                    message_length = int.from_bytes(length_data, byteorder='big')
                    if message_length > 10 * 1024 * 1024:  # 10MB limit
                        print(f"Message too large: {message_length}")
                        break
                    
                    # Read compressed message
                    compressed_data = await asyncio.wait_for(reader.read(message_length), timeout=5.0)
                    if not compressed_data:
                        break
                    
                    # Process message
                    try:
                        json_data = gzip.decompress(compressed_data).decode('utf-8')
                        logs = json.loads(json_data)
                        
                        # Process logs
                        if isinstance(logs, list):
                            for log in logs:
                                self.metrics.add_log(len(str(log)))
                        else:
                            self.metrics.add_log(len(str(logs)))
                            
                    except Exception as e:
                        print(f"Error processing logs: {e}")
                        continue
                        
                except asyncio.TimeoutError:
                    continue
                except Exception as e:
                    print(f"Error reading from client: {e}")
                    break
                    
        except Exception as e:
            print(f"Error handling client {client_addr}: {e}")
        finally:
            self.clients.discard(writer)
            try:
                writer.close()
                await writer.wait_closed()
            except:
                pass
            print(f"Client disconnected: {client_addr}")
    
    async def stats_reporter(self):
        while self.running:
            await asyncio.sleep(5)
            if not self.running:
                break
            stats = self.metrics.get_stats()
            print(f"[STATS] Logs: {stats['logs_received']}, "
                  f"Rate: {stats['logs_per_second']:.2f} logs/sec, "
                  f"Throughput: {stats['mb_per_second']:.2f} MB/sec")
    
    async def start_server(self):
        context = None
        if self.use_tls:
            try:
                context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
                context.load_cert_chain(self.cert_file, self.key_file)
            except Exception as e:
                print(f"TLS setup failed: {e}")
                return
            
        try:
            server = await asyncio.start_server(
                self.handle_client, 
                self.host, 
                self.port,
                ssl=context
            )
        except Exception as e:
            print(f"Failed to start server: {e}")
            return
        
        print(f"TCP Server listening on {self.host}:{self.port} (TLS: {self.use_tls})")
        
        # Start stats reporter
        stats_task = asyncio.create_task(self.stats_reporter())
        
        try:
            async with server:
                await server.serve_forever()
        except KeyboardInterrupt:
            print("Server shutting down...")
        finally:
            self.running = False
            stats_task.cancel()
            try:
                await stats_task
            except asyncio.CancelledError:
                pass

if __name__ == "__main__":
    import sys
    use_tls = len(sys.argv) < 2 or sys.argv[1] != "--no-tls"
    server = TCPLogServer(use_tls=use_tls)
    try:
        asyncio.run(server.start_server())
    except KeyboardInterrupt:
        print("Server stopped.")