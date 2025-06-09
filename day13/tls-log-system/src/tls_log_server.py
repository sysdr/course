#!/usr/bin/env python3
"""
Complete TLS Log Server with robust SSL/TLS configuration and error handling
Supports Python 3.8+ with progressive fallback for maximum compatibility
"""

import ssl
import socket
import threading
import json
import gzip
import time
import logging
import signal
import sys
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Any, Optional, Self
from dataclasses import dataclass, asdict
from collections.abc import Callable
import structlog

# Python 3.13 enhanced error handling with fallbacks
from contextlib import suppress
import warnings

# Configure structured logging with comprehensive error handling
try:
    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer()
        ],
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )
    logger = structlog.get_logger()
    HAS_STRUCTLOG = True
except Exception:
    # Fallback to standard logging if structlog fails
    import logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    logger = logging.getLogger(__name__)
    HAS_STRUCTLOG = False

# Enhanced dataclass with compatibility
try:
    @dataclass(frozen=True, slots=True)  # Python 3.13 slots optimization
    class LogEntry:
        """Structured log entry with Python 3.13+ optimizations"""
        level: str
        message: str
        source: str
        timestamp: float
        client_ip: Optional[str] = None
        compression_ratio: Optional[float] = None
        
        def __post_init__(self) -> None:
            """Validate log entry data"""
            if not self.message.strip():
                raise ValueError("Log message cannot be empty")
            if self.timestamp <= 0:
                raise ValueError("Timestamp must be positive")
                
except TypeError:
    # Fallback for older Python versions without slots
    @dataclass(frozen=True)
    class LogEntry:
        """Structured log entry with compatibility fallback"""
        level: str
        message: str
        source: str
        timestamp: float
        client_ip: Optional[str] = None
        compression_ratio: Optional[float] = None
        
        def __post_init__(self) -> None:
            """Validate log entry data"""
            if not self.message.strip():
                raise ValueError("Log message cannot be empty")
            if self.timestamp <= 0:
                raise ValueError("Timestamp must be positive")

try:
    @dataclass(slots=True)  # Python 3.13 performance enhancement
    class ServerMetrics:
        """Server performance metrics with Python 3.13+ optimizations"""
        total_connections: int = 0
        total_logs_processed: int = 0
        total_bytes_received: int = 0
        total_bytes_decompressed: int = 0
        start_time: float = 0
        error_count: int = 0
        
        @property
        def uptime(self) -> float:
            """Calculate server uptime"""
            return time.time() - self.start_time if self.start_time > 0 else 0
        
        @property
        def logs_per_second(self) -> float:
            """Calculate logs processed per second"""
            return self.total_logs_processed / max(self.uptime, 1)
        
        @property
        def compression_efficiency(self) -> float:
            """Calculate average compression efficiency"""
            if self.total_bytes_decompressed == 0:
                return 0.0
            return 1 - (self.total_bytes_received / self.total_bytes_decompressed)
        
        def to_dict(self) -> Dict[str, Any]:
            """Convert metrics to dictionary with computed properties"""
            base_dict = asdict(self)
            base_dict.update({
                "uptime_seconds": self.uptime,
                "logs_per_second": self.logs_per_second,
                "compression_efficiency": self.compression_efficiency,
                "error_rate": self.error_count / max(self.total_logs_processed, 1)
            })
            return base_dict
            
except TypeError:
    # Fallback for older Python versions
    @dataclass
    class ServerMetrics:
        """Server performance metrics with compatibility fallback"""
        total_connections: int = 0
        total_logs_processed: int = 0
        total_bytes_received: int = 0
        total_bytes_decompressed: int = 0
        start_time: float = 0
        error_count: int = 0
        
        @property
        def uptime(self) -> float:
            """Calculate server uptime"""
            return time.time() - self.start_time if self.start_time > 0 else 0
        
        @property
        def logs_per_second(self) -> float:
            """Calculate logs processed per second"""
            return self.total_logs_processed / max(self.uptime, 1)
        
        @property
        def compression_efficiency(self) -> float:
            """Calculate average compression efficiency"""
            if self.total_bytes_decompressed == 0:
                return 0.0
            return 1 - (self.total_bytes_received / self.total_bytes_decompressed)
        
        def to_dict(self) -> Dict[str, Any]:
            """Convert metrics to dictionary with computed properties"""
            base_dict = asdict(self)
            base_dict.update({
                "uptime_seconds": self.uptime,
                "logs_per_second": self.logs_per_second,
                "compression_efficiency": self.compression_efficiency,
                "error_rate": self.error_count / max(self.total_logs_processed, 1)
            })
            return base_dict

class TLSLogServer:
    """
    Enhanced TLS Log Server with robust SSL/TLS configuration
    Supports Python 3.8+ with progressive fallback for maximum compatibility
    """
    
    def __init__(self, host: str = 'localhost', port: int = 8443) -> None:
        self.host = host
        self.port = port
        self.metrics = ServerMetrics(start_time=time.time())
        self.running = False
        self.server_socket: Optional[socket.socket] = None
        self._ssl_context: Optional[ssl.SSLContext] = None
        
        # Setup with comprehensive error handling
        try:
            self._setup_ssl_context()
            self._setup_signal_handlers()
        except Exception as e:
            self._log_error("Failed to initialize server", e)
            raise
        
        # Ensure logs directory exists
        Path('logs').mkdir(exist_ok=True)
        
        self._log_info("TLS Log Server initialized", {
            "host": host, 
            "port": port, 
            "python_version": f"{sys.version_info.major}.{sys.version_info.minor}",
            "ssl_version": ssl.OPENSSL_VERSION
        })
    
    def _log_info(self, message: str, extra: Dict[str, Any] = None) -> None:
        """Unified info logging"""
        if HAS_STRUCTLOG:
            logger.info(message, **(extra or {}))
        else:
            extra_str = f" - {extra}" if extra else ""
            logger.info(f"{message}{extra_str}")
    
    def _log_warning(self, message: str, extra: Dict[str, Any] = None) -> None:
        """Unified warning logging"""
        if HAS_STRUCTLOG:
            logger.warning(message, **(extra or {}))
        else:
            extra_str = f" - {extra}" if extra else ""
            logger.warning(f"{message}{extra_str}")
    
    def _log_error(self, message: str, error: Exception, extra: Dict[str, Any] = None) -> None:
        """Unified error logging"""
        error_info = {
            "error": str(error),
            "error_type": type(error).__name__,
            **(extra or {})
        }
        if HAS_STRUCTLOG:
            logger.error(message, **error_info)
        else:
            logger.error(f"{message} - {error_info}")
    
    def _setup_ssl_context(self) -> None:
        """Configure SSL context with comprehensive fallback for maximum compatibility"""
        try:
            # Create SSL context
            self._ssl_context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
            
            # Load certificate and key with enhanced error handling
            cert_path = Path('certs/server.crt')
            key_path = Path('certs/server.key')
            
            if not cert_path.exists() or not key_path.exists():
                raise FileNotFoundError(
                    f"SSL certificate or key not found. "
                    f"Cert exists: {cert_path.exists()}, Key exists: {key_path.exists()}"
                )
            
            # Load certificate chain
            self._ssl_context.load_cert_chain(str(cert_path), str(key_path))
            
            # Progressive TLS version and cipher configuration
            tls_version, cipher_info = self._configure_tls_security()
            
            # Additional security hardening
            self._apply_security_options()
            
            self._log_info("SSL context configured successfully", {
                "tls_version": tls_version,
                "cipher_info": cipher_info
            })
            
        except Exception as e:
            self._log_error("Failed to setup SSL context", e)
            raise RuntimeError(f"SSL context setup failed: {e}")
    
    def _configure_tls_security(self) -> tuple[str, str]:
        """Configure TLS version and ciphers with progressive fallback"""
        
        # Try TLS 1.3 first (most secure)
        if self._try_tls_13():
            return "TLS 1.3", "TLS 1.3 AEAD ciphers"
        
        # Fallback to TLS 1.2 with progressive cipher selection
        return self._configure_tls_12()
    
    def _try_tls_13(self) -> bool:
        """Attempt to configure TLS 1.3"""
        try:
            if not (hasattr(ssl, 'TLSVersion') and hasattr(ssl.TLSVersion, 'TLSv1_3')):
                return False
            
            # Set TLS 1.3
            self._ssl_context.minimum_version = ssl.TLSVersion.TLSv1_3
            self._ssl_context.maximum_version = ssl.TLSVersion.TLSv1_3
            
            # Try TLS 1.3 cipher suites
            tls13_ciphers = [
                'TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256',
                'TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256',
                'TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384'
            ]
            
            for cipher_suite in tls13_ciphers:
                try:
                    self._ssl_context.set_ciphers(cipher_suite)
                    return True
                except ssl.SSLError:
                    continue
            
            return False
            
        except (AttributeError, ssl.SSLError):
            return False
    
    def _configure_tls_12(self) -> tuple[str, str]:
        """Configure TLS 1.2 with progressive cipher fallback"""
        
        # Set TLS 1.2 minimum version
        if hasattr(ssl, 'TLSVersion') and hasattr(ssl.TLSVersion, 'TLSv1_2'):
            self._ssl_context.minimum_version = ssl.TLSVersion.TLSv1_2
        else:
            # Fallback for older Python versions
            self._ssl_context.options |= ssl.OP_NO_SSLv2
            self._ssl_context.options |= ssl.OP_NO_SSLv3
            self._ssl_context.options |= ssl.OP_NO_TLSv1
            self._ssl_context.options |= ssl.OP_NO_TLSv1_1
        
        # Progressive cipher suite fallback
        cipher_configs = [
            ("Modern ECDHE", "ECDHE+AESGCM:ECDHE+CHACHA20:DHE+AESGCM:DHE+CHACHA20:!aNULL:!MD5:!DSS"),
            ("Broad Compatibility", "ECDHE+AES:DHE+AES:RSA+AES:!aNULL:!MD5:!DSS:!RC4"),
            ("High Security", "HIGH:!aNULL:!MD5:!RC4:!DSS:!EXPORT"),
            ("Maximum Compatibility", "ALL:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!SRP:!CAMELLIA"),
            ("System Default", None)  # Use system defaults
        ]
        
        for cipher_name, cipher_suite in cipher_configs:
            try:
                if cipher_suite:
                    self._ssl_context.set_ciphers(cipher_suite)
                return "TLS 1.2", cipher_name
            except ssl.SSLError:
                continue
        
        # If we get here, use system defaults
        self._log_warning("Using system default cipher configuration")
        return "TLS 1.2", "System Default"
    
    def _apply_security_options(self) -> None:
        """Apply additional security hardening options"""
        security_options = [
            ('OP_NO_RENEGOTIATION', 'Disable renegotiation'),
            ('OP_CIPHER_SERVER_PREFERENCE', 'Server cipher preference'),
            ('OP_NO_COMPRESSION', 'Disable compression (CRIME attack prevention)'),
            ('OP_SINGLE_DH_USE', 'Single DH use'),
            ('OP_SINGLE_ECDH_USE', 'Single ECDH use')
        ]
        
        applied_options = []
        
        for option_name, description in security_options:
            if hasattr(ssl, option_name):
                try:
                    option_value = getattr(ssl, option_name)
                    self._ssl_context.options |= option_value
                    applied_options.append(description)
                except Exception:
                    pass
        
        if applied_options:
            self._log_info("Applied security options", {"options": applied_options})
    
    def _setup_signal_handlers(self) -> None:
        """Setup graceful shutdown signal handlers"""
        def signal_handler(signum: int, frame) -> None:
            self._log_info("Received shutdown signal", {"signal": signum})
            self.shutdown()
        
        try:
            signal.signal(signal.SIGINT, signal_handler)
            signal.signal(signal.SIGTERM, signal_handler)
        except (ValueError, OSError):
            # Signal handling may not work in all environments (like tests)
            self._log_warning("Signal handlers not available in this environment")
    
    @property
    def ssl_context(self) -> ssl.SSLContext:
        """Get SSL context with null safety"""
        if self._ssl_context is None:
            raise RuntimeError("SSL context not initialized")
        return self._ssl_context
    
    def handle_client(self, client_socket: ssl.SSLSocket, address: tuple[str, int]) -> None:
        """Process encrypted log data with comprehensive error handling"""
        client_ip = address[0]
        session_start = time.time()
        logs_processed = 0
        
        try:
            # Get connection info safely
            connection_info = self._get_connection_info(client_socket)
            
            self._log_info("Secure connection established", {
                "client_ip": client_ip,
                **connection_info
            })
            
            self.metrics.total_connections += 1
            
            while self.running:
                try:
                    # Set reasonable timeout
                    client_socket.settimeout(30.0)
                    
                    # Receive encrypted, compressed data
                    data = client_socket.recv(4096)
                    if not data:
                        break
                    
                    # Process the received data
                    if self._process_log_data(data, client_ip):
                        logs_processed += 1
                    
                    # Send acknowledgment
                    ack_data = self._create_acknowledgment(logs_processed, connection_info)
                    response = json.dumps(ack_data, separators=(',', ':')).encode('utf-8')
                    client_socket.send(response)
                    
                except socket.timeout:
                    self._log_warning("Client connection timeout", {"client_ip": client_ip})
                    break
                except ConnectionResetError:
                    self._log_info("Client disconnected", {"client_ip": client_ip})
                    break
                except Exception as e:
                    self.metrics.error_count += 1
                    self._log_error("Error processing client data", e, {"client_ip": client_ip})
                    break
                    
        except Exception as e:
            self.metrics.error_count += 1
            self._log_error("Error handling client connection", e, {"client_ip": client_ip})
        finally:
            session_duration = time.time() - session_start
            self._log_info("Client session ended", {
                "client_ip": client_ip,
                "duration_seconds": round(session_duration, 2),
                "logs_processed": logs_processed
            })
            
            # Close socket safely
            with suppress(Exception):
                client_socket.close()
    
    def _get_connection_info(self, client_socket: ssl.SSLSocket) -> Dict[str, Any]:
        """Safely extract connection information"""
        info = {}
        
        try:
            info["cipher"] = client_socket.cipher()
        except:
            info["cipher"] = "Unknown"
        
        try:
            if hasattr(client_socket, 'version'):
                info["tls_version"] = client_socket.version()
            else:
                info["tls_version"] = "Unknown"
        except:
            info["tls_version"] = "Unknown"
        
        try:
            if hasattr(client_socket, 'getpeercert'):
                peer_cert = client_socket.getpeercert()
                if peer_cert:
                    info["peer_cert_subject"] = peer_cert.get('subject', 'Unknown')
        except:
            pass
        
        return info
    
    def _create_acknowledgment(self, logs_processed: int, connection_info: Dict[str, Any]) -> Dict[str, Any]:
        """Create acknowledgment response"""
        return {
            "status": "received",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "server_id": f"tls-log-server-{os.getpid()}",
            "session_logs": logs_processed,
            "server_metrics": {
                "total_connections": self.metrics.total_connections,
                "total_logs_processed": self.metrics.total_logs_processed,
                "uptime_seconds": round(self.metrics.uptime, 1)
            },
            "connection_info": {
                "tls_version": connection_info.get("tls_version", "Unknown"),
                "cipher": connection_info.get("cipher", {}).get("name", "Unknown") if isinstance(connection_info.get("cipher"), dict) else "Unknown"
            }
        }
    
    def _process_log_data(self, data: bytes, client_ip: str) -> bool:
        """Process and store log data with comprehensive error handling"""
        try:
            # Update metrics
            self.metrics.total_bytes_received += len(data)
            
            # Decompress with error handling
            try:
                decompressed = gzip.decompress(data)
            except gzip.BadGzipFile as e:
                self._log_error("Invalid gzip data received", e, {"client_ip": client_ip})
                return False
            
            self.metrics.total_bytes_decompressed += len(decompressed)
            
            # Parse JSON with error handling
            try:
                log_data = json.loads(decompressed.decode('utf-8'))
            except (json.JSONDecodeError, UnicodeDecodeError) as e:
                self._log_error("Invalid JSON/UTF-8 data received", e, {"client_ip": client_ip})
                return False
            
            # Create and validate log entry
            try:
                log_entry = LogEntry(
                    level=log_data.get('level', 'INFO'),
                    message=log_data.get('message', ''),
                    source=log_data.get('source', 'unknown'),
                    timestamp=log_data.get('timestamp', time.time()),
                    client_ip=client_ip,
                    compression_ratio=1 - (len(data) / len(decompressed)) if len(decompressed) > 0 else 0
                )
            except (ValueError, TypeError) as e:
                self._log_error("Invalid log entry data", e, {"client_ip": client_ip})
                return False
            
            # Write log entry
            if self._write_log_entry(log_entry):
                self.metrics.total_logs_processed += 1
                
                # Structured logging
                self._log_info("Log entry processed", {
                    "level": log_entry.level,
                    "source": log_entry.source,
                    "client_ip": client_ip,
                    "compression_ratio": f"{log_entry.compression_ratio:.2%}",
                    "message_length": len(log_entry.message)
                })
                
                return True
            
            return False
                       
        except Exception as e:
            self.metrics.error_count += 1
            self._log_error("Failed to process log data", e, {"client_ip": client_ip})
            return False
    
    def _write_log_entry(self, log_entry: LogEntry) -> bool:
        """Write log entry to file with enhanced I/O and rotation"""
        try:
            timestamp = datetime.fromtimestamp(log_entry.timestamp, timezone.utc)
            log_file = Path(f'logs/secure_logs_{timestamp.strftime("%Y%m%d")}.jsonl')
            
            # Ensure parent directory exists
            log_file.parent.mkdir(exist_ok=True)
            
            # Write log entry
            with log_file.open('a', encoding='utf-8') as f:
                json.dump(asdict(log_entry), f, separators=(',', ':'))
                f.write('\n')
            
            return True
            
        except Exception as e:
            self._log_error("Failed to write log entry", e, {
                "log_file": str(log_file) if 'log_file' in locals() else "Unknown"
            })
            return False
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get comprehensive server performance metrics"""
        return self.metrics.to_dict()
    
    def get_health_status(self) -> Dict[str, Any]:
        """Get server health status"""
        return {
            "status": "healthy" if self.running else "stopped",
            "uptime_seconds": self.metrics.uptime,
            "total_connections": self.metrics.total_connections,
            "total_logs_processed": self.metrics.total_logs_processed,
            "error_count": self.metrics.error_count,
            "error_rate": self.metrics.error_count / max(self.metrics.total_logs_processed, 1),
            "logs_per_second": self.metrics.logs_per_second,
            "compression_efficiency": self.metrics.compression_efficiency,
            "memory_usage": self._get_memory_usage(),
            "ssl_info": self._get_ssl_info()
        }
    
    def _get_memory_usage(self) -> Dict[str, Any]:
        """Get memory usage information"""
        try:
            import psutil
            process = psutil.Process()
            memory_info = process.memory_info()
            return {
                "rss_mb": round(memory_info.rss / 1024 / 1024, 2),
                "vms_mb": round(memory_info.vms / 1024 / 1024, 2)
            }
        except ImportError:
            return {"status": "psutil not available"}
        except Exception as e:
            return {"error": str(e)}
    
    def _get_ssl_info(self) -> Dict[str, Any]:
        """Get SSL configuration information"""
        try:
            return {
                "openssl_version": ssl.OPENSSL_VERSION,
                "has_tls_1_3": hasattr(ssl, 'TLSVersion') and hasattr(ssl.TLSVersion, 'TLSv1_3'),
                "supported_protocols": [
                    protocol for protocol in ['TLSv1.2', 'TLSv1.3']
                    if hasattr(ssl, 'TLSVersion') and hasattr(ssl.TLSVersion, f'TLSv{protocol[3:].replace(".", "_")}')
                ]
            }
        except Exception as e:
            return {"error": str(e)}
    
    def start(self) -> None:
        """Start the TLS log server with comprehensive error handling"""
        try:
            # Create and configure server socket
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            
            # Try to enable SO_REUSEPORT if available
            if hasattr(socket, 'SO_REUSEPORT'):
                try:
                    self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
                except OSError:
                    pass  # Not supported on all systems
            
            # Bind and listen
            self.server_socket.bind((self.host, self.port))
            self.server_socket.listen(20)  # Increased backlog
            
            self.running = True
            
            self._log_info("TLS Log Server started successfully", {
                "host": self.host,
                "port": self.port,
                "pid": os.getpid(),
                "python_version": sys.version,
                "ssl_version": ssl.OPENSSL_VERSION
            })
            
            # Main server loop
            while self.running:
                try:
                    # Accept client connection
                    client_socket, address = self.server_socket.accept()
                    
                    # Wrap with SSL/TLS
                    try:
                        tls_socket = self.ssl_context.wrap_socket(
                            client_socket,
                            server_side=True,
                            suppress_ragged_eofs=True
                        )
                    except Exception as e:
                        self._log_error("SSL handshake failed", e, {"client_address": address})
                        client_socket.close()
                        continue
                    
                    # Handle client in separate thread
                    thread = threading.Thread(
                        target=self.handle_client,
                        args=(tls_socket, address),
                        name=f"TLSHandler-{address[0]}:{address[1]}",
                        daemon=True
                    )
                    thread.start()
                    
                except OSError as e:
                    if self.running:  # Only log if we're not shutting down
                        self._log_error("Socket error in main loop", e)
                except Exception as e:
                    if self.running:
                        self._log_error("Unexpected error in main loop", e)
                        
        except Exception as e:
            self._log_error("Failed to start server", e)
            raise
        finally:
            self.shutdown()
    
    def shutdown(self) -> None:
        """Gracefully shutdown the server with comprehensive cleanup"""
        if not self.running:
            return
            
        self._log_info("Initiating TLS Log Server shutdown...")
        self.running = False
        
        # Close server socket
        if self.server_socket:
            with suppress(Exception):
                self.server_socket.close()
        
        # Wait a moment for active connections to finish
        time.sleep(1)
        
        # Print final metrics
        try:
            metrics = self.get_metrics()
            health = self.get_health_status()
            
            self._log_info("Final server metrics", metrics)
            
            # Print summary to console
            print("\n" + "="*70)
            print("🔐 TLS LOG SERVER - SHUTDOWN COMPLETE")
            print("="*70)
            print(f"Total Runtime: {metrics['uptime_seconds']:.1f} seconds")
            print(f"Total Connections: {metrics['total_connections']:,}")
            print(f"Total Logs Processed: {metrics['total_logs_processed']:,}")
            print(f"Total Bytes Received: {metrics['total_bytes_received']:,}")
            print(f"Compression Efficiency: {metrics['compression_efficiency']:.2%}")
            print(f"Error Rate: {metrics['error_rate']:.2%}")
            print(f"Performance: {metrics['logs_per_second']:.1f} logs/sec")
            
            if 'memory_usage' in health and 'rss_mb' in health['memory_usage']:
                print(f"Peak Memory Usage: {health['memory_usage']['rss_mb']:.1f} MB")
            
            print("="*70)
            print("Thank you for using TLS Log Server! 🚀")
            print("="*70)
            
        except Exception as e:
            print(f"Server shutdown complete (metrics unavailable: {e})")

def main() -> None:
    """Main entry point with comprehensive error handling and configuration"""
    
    # Parse command line arguments
    import argparse
    parser = argparse.ArgumentParser(description='TLS Log Server')
    parser.add_argument('--host', default=os.getenv('TLS_SERVER_HOST', 'localhost'),
                       help='Server host (default: localhost)')
    parser.add_argument('--port', type=int, default=int(os.getenv('TLS_SERVER_PORT', '8443')),
                       help='Server port (default: 8443)')
    parser.add_argument('--debug', action='store_true',
                       help='Enable debug logging')
    
    args = parser.parse_args()
    
    # Configure logging level
    if args.debug:
        if HAS_STRUCTLOG:
            structlog.configure(level=logging.DEBUG)
        else:
            logging.getLogger().setLevel(logging.DEBUG)
    
    # Display startup banner
    print("="*70)
    print("🔐 TLS LOG SERVER - PYTHON 3.13 ENHANCED")
    print("="*70)
    print(f"Python Version: {sys.version}")
    print(f"OpenSSL Version: {ssl.OPENSSL_VERSION}")
    print(f"Server Address: {args.host}:{args.port}")
    print(f"Process ID: {os.getpid()}")
    print(f"Debug Mode: {'Enabled' if args.debug else 'Disabled'}")
    print("="*70)
    
    # Enhanced startup logging
    logger_info = {
        "python_version": sys.version,
        "platform": sys.platform,
        "host": args.host,
        "port": args.port,
        "debug": args.debug,
        "pid": os.getpid()
    }
    
    if HAS_STRUCTLOG:
        logger.info("Starting TLS Log Server", **logger_info)
    else:
        logger.info(f"Starting TLS Log Server - {logger_info}")
    
    # Create and start server
    try:
        server = TLSLogServer(host=args.host, port=args.port)
        
        # Display ready message
        print(f"\n🚀 Server ready and listening on {args.host}:{args.port}")
        print("📊 Health status: http://localhost:8080/api/health (if dashboard is running)")
        print("🛑 Press Ctrl+C to shutdown gracefully")
        print("-"*70)
        
        server.start()
        
    except KeyboardInterrupt:
        print("\n🛑 Received keyboard interrupt...")
        if HAS_STRUCTLOG:
            logger.info("Received keyboard interrupt")
        else:
            logger.info("Received keyboard interrupt")
    except Exception as e:
        error_msg = f"Server failed to start: {e}"
        print(f"\n❌ {error_msg}")
        
        if HAS_STRUCTLOG:
            logger.error("Server failed", error=str(e), error_type=type(e).__name__)
        else:
            logger.error(error_msg)
        
        # Print troubleshooting hints
        print("\n🔧 TROUBLESHOOTING HINTS:")
        print("1. Check if certificates exist: ls -la certs/")
        print("2. Verify port is available: lsof -i :8443")
        print("3. Test SSL configuration: python test_ssl_compatibility.py")
        print("4. Check logs directory: ls -la logs/")
        print("5. Run with debug: python src/tls_log_server.py --debug")
        
        sys.exit(1)
    
if __name__ == "__main__":
    main()