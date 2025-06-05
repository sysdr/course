# main.py
import time
import random
from src.log_storage import LogStorage
from src.rotation_policy import SizeBasedRotationPolicy, TimeBasedRotationPolicy
from src.retention_policy import CountBasedRetentionPolicy

def main():
    # Create a log storage system with size-based rotation (rotate at 1KB)
    # and retention policy (keep only 5 most recent logs)
    log_storage = LogStorage(
        log_directory="./logs",
        base_filename="application.log",
        rotation_policy=SizeBasedRotationPolicy(1024),  # 1 KB
        retention_policy=CountBasedRetentionPolicy(5),
        compress_rotated=True
    )
    
    # Simulate logging activity
    print("Starting log generation...")
    try:
        log_count = 0
        while True:
            # Generate some realistic-looking log messages
            log_levels = ["INFO", "DEBUG", "WARNING", "ERROR"]
            level = random.choice(log_levels)
            timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
            
            # Weighted random selection for more realistic logs
            if level == "ERROR":
                message = random.choice([
                    "Connection refused",
                    "Database query timeout",
                    "Failed to process request",
                    "Authentication failed"
                ])
            elif level == "WARNING":
                message = random.choice([
                    "High memory usage detected",
                    "Slow query performance",
                    "Rate limit approaching",
                    "Retry attempt #3"
                ])
            else:
                message = random.choice([
                    "Request processed successfully",
                    "User logged in",
                    "Cache updated",
                    "Scheduled task completed"
                ])
            
            # Generate the log entry
            log_entry = f"{timestamp} [{level}] {message}"
            log_storage.write_log(log_entry)
            
            log_count += 1
            if log_count % 100 == 0:
                print(f"Generated {log_count} log entries...")
            
            # Random small delay between log entries
            time.sleep(random.uniform(0.01, 0.05))
            
    except KeyboardInterrupt:
        print("\nStopping log generation.")
        log_storage.close()
        print(f"Total logs generated: {log_count}")

if __name__ == "__main__":
    main()