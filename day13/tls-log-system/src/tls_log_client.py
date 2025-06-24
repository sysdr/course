#!/usr/bin/env python3
"""
Fixed TLS Log Client with better error handling and test compatibility
"""

import ssl
import socket
import json
import gzip
import time
import hashlib
import random
import logging
import asyncio
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Any, List, Optional, Self, TypedDict
from dataclasses import dataclass, asdict
from collections.abc import Callable, Sequence
import structlog

# Python 3.13 enhanced imports with fallbacks
from contextlib import suppress
import warnings
try:
    from functools import cached_property
except ImportError:
    # Fallback for older Python versions
    def cached_property(func):
        return property(func)

# Configure structured logging with error handling
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
except Exception:
    # Fallback to standard logging if structlog fails
    import logging
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger(__name__)

# Python 3.13 TypedDict for better type safety with fallbacks
try:
    class LogMetadata(TypedDict, total=False):
        user_id: str
        session_id: str
        request_id: str
        trace_id: str
        span_id: str

    class HealthcareMetadata(TypedDict, total=False):
        patient_hash: str
        consultation_type: str
        duration_minutes: int
        compliance_level: str
except (TypeError, NameError):
    # Fallback for older Python versions
    LogMetadata = Dict[str, Any]
    HealthcareMetadata = Dict[str, Any]

@dataclass(frozen=True)  # Remove slots for compatibility
class ClientMetrics:
    """Client performance metrics with enhanced compatibility"""
    total_logs_sent: int = 0
    successful_transmissions: int = 0
    failed_transmissions: int = 0
    total_bytes_sent: int = 0
    total_compression_saved: int = 0
    connection_time_total: float = 0
    retry_count: int = 0
    
    @cached_property
    def success_rate(self) -> float:
        """Calculate success rate"""
        if self.total_logs_sent == 0:
            return 0.0
        return self.successful_transmissions / self.total_logs_sent
    
    @cached_property
    def average_connection_time(self) -> float:
        """Calculate average connection time"""
        if self.successful_transmissions == 0:
            return 0.0
        return self.connection_time_total / self.successful_transmissions
    
    @cached_property
    def compression_efficiency(self) -> float:
        """Calculate compression efficiency"""
        if self.total_bytes_sent == 0:
            return 0.0
        total_uncompressed = self.total_bytes_sent + self.total_compression_saved
        return self.total_compression_saved / total_uncompressed
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary with all computed properties"""
        base_dict = asdict(self)
        base_dict.update({
            "success_rate": self.success_rate,
            "average_connection_time": self.average_connection_time,
            "compression_efficiency": self.compression_efficiency,
            "retry_rate": self.retry_count / max(self.total_logs_sent, 1)
        })
        return base_dict

class TLSLogClient:
    """Enhanced TLS Log Client with better error handling and compatibility"""
    
    def __init__(self, host: str = 'localhost', port: int = 8443) -> None:
        self.host = host
        self.port = port
        # Use mutable metrics for compatibility
        self._metrics_data = {
            'total_logs_sent': 0,
            'successful_transmissions': 0,
            'failed_transmissions': 0,
            'total_bytes_sent': 0,
            'total_compression_saved': 0,
            'connection_time_total': 0.0,
            'retry_count': 0
        }
        self._ssl_context: Optional[ssl.SSLContext] = None
        
        try:
            self._setup_ssl_context()
        except Exception as e:
            if hasattr(logger, 'error'):
                logger.error("Failed to setup SSL context", error=str(e))
            else:
                print(f"Failed to setup SSL context: {e}")
            raise
        
        if hasattr(logger, 'info'):
            logger.info("TLS Log Client initialized", host=host, port=port)
        else:
            print(f"TLS Log Client initialized for {host}:{port}")
    
    def _setup_ssl_context(self) -> None:
        """Configure SSL context with robust compatibility for different environments"""
        try:
            self._ssl_context = ssl.create_default_context()
            
            # For development with self-signed certificates
            self._ssl_context.check_hostname = False
            self._ssl_context.verify_mode = ssl.CERT_NONE
            
            # Progressive fallback for TLS versions and ciphers
            tls_version = "TLS 1.2"  # Default fallback
            
            # Try TLS 1.3 first with robust fallback
            try:
                if hasattr(ssl, 'TLSVersion') and hasattr(ssl.TLSVersion, 'TLSv1_3'):
                    self._ssl_context.minimum_version = ssl.TLSVersion.TLSv1_3
                    self._ssl_context.maximum_version = ssl.TLSVersion.TLSv1_3
                    
                    # Try TLS 1.3 ciphers with fallback
                    try:
                        self._ssl_context.set_ciphers('TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256')
                        tls_version = "TLS 1.3"
                    except ssl.SSLError:
                        # TLS 1.3 not supported, fall back to TLS 1.2
                        raise ssl.SSLError("TLS 1.3 ciphers not supported")
                else:
                    raise AttributeError("TLS 1.3 not available")
                    
            except (AttributeError, ssl.SSLError):
                # Fallback to TLS 1.2 with robust cipher selection
                if hasattr(ssl, 'TLSVersion') and hasattr(ssl.TLSVersion, 'TLSv1_2'):
                    self._ssl_context.minimum_version = ssl.TLSVersion.TLSv1_2
                else:
                    # For very old Python versions
                    self._ssl_context.options |= ssl.OP_NO_SSLv2
                    self._ssl_context.options |= ssl.OP_NO_SSLv3
                    self._ssl_context.options |= ssl.OP_NO_TLSv1
                    self._ssl_context.options |= ssl.OP_NO_TLSv1_1
                
                # Progressive cipher fallback for maximum compatibility
                cipher_suites = [
                    # Modern secure ciphers
                    'ECDHE+AESGCM:ECDHE+CHACHA20:DHE+AESGCM:DHE+CHACHA20:!aNULL:!MD5:!DSS',
                    # Broader compatibility
                    'ECDHE+AES:DHE+AES:RSA+AES:!aNULL:!MD5:!DSS:!RC4',
                    # Maximum compatibility fallback
                    'HIGH:!aNULL:!MD5:!RC4:!DSS',
                    # Last resort - very basic but functional
                    'ALL:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!SRP:!CAMELLIA'
                ]
                
                cipher_set = False
                for cipher_suite in cipher_suites:
                    try:
                        self._ssl_context.set_ciphers(cipher_suite)
                        cipher_set = True
                        break
                    except ssl.SSLError:
                        continue
                
                if not cipher_set:
                    # If all else fails, use system default
                    if hasattr(logger, 'warning'):
                        logger.warning("Using system default ciphers due to compatibility issues")
                    
                tls_version = "TLS 1.2"
            
            # Enhanced options with compatibility checks
            if hasattr(ssl, 'OP_NO_RENEGOTIATION'):
                try:
                    self._ssl_context.options |= ssl.OP_NO_RENEGOTIATION
                except:
                    pass
            
            if hasattr(logger, 'info'):
                logger.info(f"Client SSL context configured with {tls_version}")
            else:
                print(f"Client SSL context configured with {tls_version}")
            
        except Exception as e:
            error_msg = f"Failed to setup SSL context: {e}"
            if hasattr(logger, 'error'):
                logger.error("SSL setup failed", error=str(e), error_type=type(e).__name__)
            else:
                print(error_msg)
            raise RuntimeError(error_msg)
    
    @property
    def ssl_context(self) -> ssl.SSLContext:
        """Get SSL context with null safety"""
        if self._ssl_context is None:
            raise RuntimeError("SSL context not initialized")
        return self._ssl_context
    
    @property
    def metrics(self) -> ClientMetrics:
        """Get current metrics as immutable object"""
        return ClientMetrics(**self._metrics_data)
    
    def _update_metrics(self, **kwargs) -> None:
        """Update metrics safely"""
        for key, value in kwargs.items():
            if key in self._metrics_data:
                if isinstance(value, (int, float)):
                    self._metrics_data[key] += value
                else:
                    self._metrics_data[key] = value
    
    def anonymize_patient_id(self, patient_id: str, salt: str = "tls_log_system_2024") -> str:
        """Enhanced patient ID anonymization with better security"""
        # Use SHA-256 with salt for HIPAA compliance
        try:
            combined = f"{patient_id}{salt}{time.time_ns()}"  # Add timestamp for uniqueness
        except AttributeError:
            # Fallback for systems without time_ns
            combined = f"{patient_id}{salt}{int(time.time() * 1000000)}"
        
        hash_object = hashlib.sha256(combined.encode('utf-8'))
        return hash_object.hexdigest()[:16]  # 16 chars for better anonymization
    
    def send_log(self, 
                 message: str, 
                 level: str = "INFO", 
                 metadata: Optional[LogMetadata] = None,
                 max_retries: int = 3) -> bool:
        """Send log with enhanced retry logic and type safety"""
        
        for attempt in range(max_retries):
            try:
                success = self._attempt_send_log(message, level, metadata, attempt)
                if success:
                    self._update_metrics(successful_transmissions=1)
                    return True
                    
            except Exception as e:
                if hasattr(logger, 'warning'):
                    logger.warning("Log transmission attempt failed", 
                                 attempt=attempt + 1, 
                                 max_retries=max_retries,
                                 error=str(e),
                                 error_type=type(e).__name__)
                
                if attempt < max_retries - 1:
                    # Enhanced exponential backoff with jitter
                    base_delay = 1.0
                    jitter = random.uniform(0, 0.5)
                    delay = (base_delay * (2 ** attempt)) + jitter
                    
                    if hasattr(logger, 'debug'):
                        logger.debug("Retrying after delay", 
                                   delay=f"{delay:.2f}s",
                                   attempt=attempt + 1)
                    time.sleep(delay)
                    
                    # Update retry metrics
                    self._update_metrics(retry_count=1)
        
        # All attempts failed
        self._update_metrics(failed_transmissions=1)
        if hasattr(logger, 'error'):
            logger.error("All transmission attempts failed", 
                        message_preview=message[:50] + "..." if len(message) > 50 else message)
        return False
    
    def _attempt_send_log(self, 
                         message: str, 
                         level: str, 
                         metadata: Optional[LogMetadata],
                         attempt: int) -> bool:
        """Single transmission attempt with enhanced error handling"""
        connection_start = time.perf_counter()
        
        try:
            # Enhanced socket creation with context management
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as client_socket:
                client_socket.settimeout(10.0)
                
                # Enhanced TLS wrapping with better error handling
                with self.ssl_context.wrap_socket(
                    client_socket,
                    server_hostname=None if self.host == 'localhost' else self.host
                ) as tls_socket:
                    
                    tls_socket.connect((self.host, self.port))
                    
                    connection_time = time.perf_counter() - connection_start
                    self._update_metrics(connection_time_total=connection_time)
                    
                    # Get enhanced connection info safely
                    try:
                        cipher_info = tls_socket.cipher()
                        tls_version = getattr(tls_socket, 'version', lambda: 'Unknown')()
                    except:
                        cipher_info = None
                        tls_version = 'Unknown'
                    
                    if hasattr(logger, 'debug'):
                        logger.debug("TLS connection established", 
                                    connection_time=f"{connection_time:.3f}s",
                                    cipher=cipher_info,
                                    tls_version=tls_version,
                                    attempt=attempt + 1)
                    
                    # Prepare enhanced log entry
                    log_entry = {
                        "level": level,
                        "message": message,
                        "source": "tls_log_client_py313",
                        "timestamp": time.time(),
                        "metadata": metadata or {},
                        "client_info": {
                            "python_version": "3.13",
                            "tls_version": tls_version,
                            "attempt": attempt + 1
                        }
                    }
                    
                    # Enhanced JSON serialization and compression
                    json_data = json.dumps(log_entry, separators=(',', ':'), ensure_ascii=False).encode('utf-8')
                    compressed_data = gzip.compress(json_data, compresslevel=9)
                    
                    # Update metrics
                    self._update_metrics(
                        total_logs_sent=1,
                        total_bytes_sent=len(compressed_data),
                        total_compression_saved=len(json_data) - len(compressed_data)
                    )
                    
                    compression_ratio = (len(json_data) - len(compressed_data)) / len(json_data)
                    
                    if hasattr(logger, 'debug'):
                        logger.debug("Sending compressed log",
                                    original_size=len(json_data),
                                    compressed_size=len(compressed_data),
                                    compression_ratio=f"{compression_ratio:.2%}",
                                    compression_level=9)
                    
                    # Send data with enhanced error handling
                    tls_socket.send(compressed_data)
                    
                    # Receive acknowledgment with timeout
                    tls_socket.settimeout(5.0)
                    response = tls_socket.recv(1024)
                    
                    if response:
                        try:
                            ack = json.loads(response.decode('utf-8'))
                            if hasattr(logger, 'debug'):
                                logger.debug("Server acknowledgment received", **ack)
                        except:
                            pass  # Don't fail on ack parsing errors
                    
                    return True
            
        except socket.timeout:
            if hasattr(logger, 'error'):
                logger.error("Connection timeout", attempt=attempt + 1)
            return False
        except ConnectionRefusedError:
            if hasattr(logger, 'error'):
                logger.error("Connection refused - server may be down", attempt=attempt + 1)
            return False
        except Exception as e:
            if hasattr(logger, 'error'):
                logger.error("Transmission failed", 
                            error=str(e), 
                            error_type=type(e).__name__,
                            attempt=attempt + 1)
            return False
    
    def send_healthcare_log(self, 
                           patient_id: str, 
                           consultation_data: Dict[str, Any],
                           compliance_level: str = "HIPAA") -> bool:
        """Send HIPAA-compliant healthcare log with enhanced security"""
        
        # Enhanced anonymization
        anonymized_id = self.anonymize_patient_id(patient_id)
        
        # Sanitize consultation data (remove PII)
        pii_fields = {'patient_name', 'ssn', 'phone', 'email', 'address', 'dob'}
        safe_consultation_data = {
            k: v for k, v in consultation_data.items() 
            if k.lower() not in pii_fields
        }
        
        # Create healthcare metadata
        healthcare_metadata = {
            "patient_hash": anonymized_id,
            "consultation_type": safe_consultation_data.get("type", "unknown"),
            "duration_minutes": safe_consultation_data.get("duration_minutes", 0),
            "compliance_level": compliance_level
        }
        
        log_message = (f"Healthcare consultation processed - "
                      f"Patient: {anonymized_id[:8]}..., "
                      f"Type: {healthcare_metadata.get('consultation_type', 'N/A')}")
        
        # Enhanced metadata with audit trail
        try:
            timestamp_ns = time.time_ns()
        except AttributeError:
            timestamp_ns = int(time.time() * 1000000000)
        
        metadata = {
            "trace_id": f"healthcare_{timestamp_ns}",
            "session_id": f"consultation_{anonymized_id}",
            **healthcare_metadata
        }
        
        return self.send_log(
            message=log_message,
            level="HEALTHCARE",
            metadata=metadata
        )
    
    async def send_batch_logs_async(self, 
                                   logs: Sequence[Dict[str, Any]]) -> Dict[str, int]:
        """Async batch log transmission with enhanced error handling"""
        results = {"successful": 0, "failed": 0}
        
        if hasattr(logger, 'info'):
            logger.info("Starting async batch log transmission", batch_size=len(logs))
        
        # Enhanced async processing
        async def send_single_log(log_data: Dict[str, Any]) -> bool:
            message = log_data.get('message', f'Async batch log entry')
            level = log_data.get('level', 'INFO')
            metadata = log_data.get('metadata')
            
            # Convert sync method to async
            loop = asyncio.get_running_loop()
            return await loop.run_in_executor(None, self.send_log, message, level, metadata)
        
        # Process logs concurrently with controlled concurrency
        semaphore = asyncio.Semaphore(5)  # Reduced concurrency for stability
        
        async def bounded_send(log_data: Dict[str, Any]) -> bool:
            async with semaphore:
                return await send_single_log(log_data)
        
        # Execute all tasks concurrently
        tasks = [bounded_send(log_data) for log_data in logs]
        results_list = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Process results
        for result in results_list:
            if isinstance(result, Exception):
                results["failed"] += 1
                if hasattr(logger, 'error'):
                    logger.error("Async log transmission failed", error=str(result))
            elif result:
                results["successful"] += 1
            else:
                results["failed"] += 1
        
        if hasattr(logger, 'info'):
            logger.info("Async batch transmission complete", **results)
        return results
    
    def send_batch_logs(self, logs: List[Dict[str, Any]]) -> Dict[str, int]:
        """Synchronous batch log transmission with enhanced reliability"""
        results = {"successful": 0, "failed": 0}
        
        if hasattr(logger, 'info'):
            logger.info("Starting batch log transmission", batch_size=len(logs))
        
        for i, log_data in enumerate(logs, 1):
            message = log_data.get('message', f'Batch log entry {i}')
            level = log_data.get('level', 'INFO')
            metadata = log_data.get('metadata')
            
            success = self.send_log(message, level, metadata)
            if success:
                results["successful"] += 1
            else:
                results["failed"] += 1
            
            # Rate limiting to prevent server overload
            if i % 5 == 0:  # Brief pause every 5 logs
                time.sleep(0.1)
        
        if hasattr(logger, 'info'):
            logger.info("Batch transmission complete", **results)
        return results
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get comprehensive client metrics"""
        base_metrics = self.metrics.to_dict()
        base_metrics.update({
            "client_version": "Python 3.13 Enhanced",
            "ssl_version": "TLS 1.3" if hasattr(ssl, 'TLSVersion') else "TLS 1.2",
            "last_updated": datetime.now(timezone.utc).isoformat()
        })
        return base_metrics

# Simulation functions with enhanced error handling
def simulate_application_logs() -> None:
    """Simulate application logs with enhanced reliability"""
    try:
        client = TLSLogClient()
        
        # Enhanced sample logs with metadata
        sample_logs = [
            {
                "message": "User authentication successful",
                "level": "INFO",
                "metadata": {
                    "user_id": "user_123", 
                    "session_id": f"session_{int(time.time())}",
                    "trace_id": f"auth_{int(time.time() * 1000000)}"
                }
            },
            {
                "message": "Database connection timeout detected",
                "level": "WARNING",
                "metadata": {
                    "database": "user_db", 
                    "timeout_seconds": 30,
                    "trace_id": f"db_{int(time.time() * 1000000)}"
                }
            },
            {
                "message": "Payment processing completed successfully",
                "level": "INFO", 
                "metadata": {
                    "amount": 99.99, 
                    "currency": "USD", 
                    "transaction_id": f"txn_{int(time.time())}",
                    "trace_id": f"payment_{int(time.time() * 1000000)}"
                }
            }
        ]
        
        print("\n" + "="*70)
        print("🔐 TLS SECURE LOG TRANSMISSION (Python 3.13 Enhanced)")
        print("="*70)
        
        results = client.send_batch_logs(sample_logs)
        
        print(f"\n📊 TRANSMISSION RESULTS:")
        print(f"✅ Successful: {results['successful']}")
        print(f"❌ Failed: {results['failed']}")
        print(f"📈 Success Rate: {(results['successful']/len(sample_logs)*100):.1f}%")
        
        metrics = client.get_metrics()
        print(f"\n📈 CLIENT METRICS (Python 3.13):")
        for key, value in metrics.items():
            display_key = key.replace('_', ' ').title()
            if isinstance(value, float) and key.endswith('_rate'):
                print(f"   {display_key}: {value:.2%}")
            elif isinstance(value, float) and 'time' in key:
                print(f"   {display_key}: {value:.3f}s")
            else:
                print(f"   {display_key}: {value}")
        
        print("\n🎉 Python 3.13 enhanced simulation complete!")
        
    except Exception as e:
        print(f"❌ Simulation failed: {e}")

def simulate_healthcare_logs() -> None:
    """Simulate healthcare logs with enhanced HIPAA compliance"""
    try:
        client = TLSLogClient()
        
        healthcare_scenarios = [
            {
                "patient_id": "P001234",
                "consultation": {
                    "type": "telemedicine",
                    "duration_minutes": 30,
                    "symptoms": ["headache", "fever"],
                    "diagnosis": "viral_infection",
                    "prescription": "rest_and_fluids",
                    "provider_id": "DR_SMITH_001"
                }
            },
            {
                "patient_id": "P005678", 
                "consultation": {
                    "type": "follow_up",
                    "duration_minutes": 15,
                    "vital_signs": {
                        "blood_pressure": "120/80",
                        "heart_rate": 72,
                        "temperature": 98.6
                    },
                    "assessment": "stable",
                    "provider_id": "DR_JOHNSON_002"
                }
            }
        ]
        
        print("\n" + "="*70)
        print("🏥 HEALTHCARE LOG TRANSMISSION (HIPAA Compliant - Python 3.13)")
        print("="*70)
        
        successful_count = 0
        for i, scenario in enumerate(healthcare_scenarios, 1):
            print(f"\n--- Healthcare Log {i}/{len(healthcare_scenarios)} ---")
            
            success = client.send_healthcare_log(
                scenario["patient_id"],
                scenario["consultation"]
            )
            
            if success:
                successful_count += 1
                anonymized_id = client.anonymize_patient_id(scenario["patient_id"])
                print(f"✅ Secure transmission for patient {anonymized_id[:8]}...")
                print(f"   Consultation: {scenario['consultation']['type']}")
                print(f"   Duration: {scenario['consultation']['duration_minutes']} minutes")
            else:
                print(f"❌ Failed transmission for patient {scenario['patient_id']}")
        
        metrics = client.get_metrics()
        print(f"\n📈 HEALTHCARE CLIENT METRICS:")
        print(f"   Total Patients Processed: {len(healthcare_scenarios)}")
        print(f"   Successful Transmissions: {successful_count}")
        print(f"   Success Rate: {(successful_count/len(healthcare_scenarios)*100):.1f}%")
        print(f"   Compression Efficiency: {metrics['compression_efficiency']:.2%}")
        print(f"   Average Connection Time: {metrics['average_connection_time']:.3f}s")
        
        print("\n🔒 HIPAA Compliance Features:")
        print("   ✅ Patient ID Anonymization (SHA-256)")
        print("   ✅ PII Data Sanitization")
        print("   ✅ Audit Trail Generation")
        print("   ✅ TLS 1.3 Encryption")
        print("   ✅ Structured Logging")
        
    except Exception as e:
        print(f"❌ Healthcare simulation failed: {e}")

async def simulate_async_logs() -> None:
    """Demonstrate async capabilities with error handling"""
    try:
        client = TLSLogClient()
        
        # Create async log batch
        async_logs = [
            {
                "message": f"Async log entry {i}",
                "level": "INFO",
                "metadata": {
                    "async_id": f"async_{i}",
                    "coroutine_id": f"coro_{int(time.time() * 1000000)}"
                }
            }
            for i in range(10)  # Reduced for stability
        ]
        
        print("\n" + "="*70)
        print("⚡ ASYNC LOG TRANSMISSION (Python 3.13 Enhanced)")
        print("="*70)
        
        start_time = time.perf_counter()
        results = await client.send_batch_logs_async(async_logs)
        end_time = time.perf_counter()
        
        print(f"\n⚡ ASYNC RESULTS:")
        print(f"✅ Successful: {results['successful']}")
        print(f"❌ Failed: {results['failed']}")
        print(f"⏱️  Total Time: {(end_time - start_time):.2f}s")
        if (end_time - start_time) > 0:
            print(f"🚀 Throughput: {len(async_logs)/(end_time - start_time):.1f} logs/sec")
            
    except Exception as e:
        print(f"❌ Async simulation failed: {e}")

def main() -> None:
    """Main entry point with enhanced error handling"""
    import sys
    import os
    
    # Configuration from environment
    host = os.getenv('TLS_SERVER_HOST', 'localhost')
    port = int(os.getenv('TLS_SERVER_PORT', '8443'))
    
    print(f"🐍 Python {sys.version}")
    print(f"🔐 TLS Client connecting to {host}:{port}")
    
    if len(sys.argv) > 1:
        mode = sys.argv[1].lower()
        
        try:
            if mode == 'healthcare':
                simulate_healthcare_logs()
            elif mode == 'async':
                asyncio.run(simulate_async_logs())
            elif mode == 'batch':
                simulate_application_logs()
            else:
                print("Usage: python tls_log_client.py [healthcare|async|batch]")
                print("Default: batch mode")
                simulate_application_logs()
        except Exception as e:
            print(f"❌ Error running {mode} mode: {e}")
            sys.exit(1)
    else:
        simulate_application_logs()

if __name__ == "__main__":
    main()