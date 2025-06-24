import json
import csv
import io

class LogGenerator:
    # Add to __init__
    def __init__(self, config):
        self.config = config
        self.ensure_log_directory()
        self.in_burst_mode = False
        self.burst_end_time = 0
        self.user_sessions = {}  # Track user sessions
        
    def generate_log_message(self):
        """Generate a random log message with additional fields."""
        # Select log type based on distribution
        log_type = self._select_log_type()
        
        # Generate timestamp
        timestamp = datetime.now().isoformat()
        
        # Generate additional fields
        service_name = random.choice(self.config["SERVICES"])
        user_id = f"user-{random.randint(1000, 9999)}"
        request_id = f"req-{int(time.time())}-{random.randint(10000, 99999)}"
        duration = random.randint(5, 500)  # milliseconds
        
        # Create or update user session
        self._update_user_session(user_id)
        
        # Create message based on log type and session state
        message = self._create_message_from_pattern(log_type, user_id)
        
        # Create log data dictionary
        log_data = {
            "timestamp": timestamp,
            "level": log_type,
            "service": service_name,
            "user_id": user_id,
            "request_id": request_id,
            "duration": duration,
            "message": message
        }
        
        # Format the log entry based on configuration
        if self.config["LOG_FORMAT"] == "json":
            log_entry = json.dumps(log_data)
        elif self.config["LOG_FORMAT"] == "csv":
            output = io.StringIO()
            writer = csv.writer(output)
            writer.writerow(log_data.values())
            log_entry = output.getvalue().strip()
        else:  # text format
            log_entry = f"{timestamp} [{log_type}] {service_name} [{request_id}] [{user_id}] ({duration}ms): {message}"
            
        return log_entry
    
    def _update_user_session(self, user_id):
        """Update the user session state machine."""
        states = ["login", "browse", "search", "view_item", "add_to_cart", "checkout", "purchase", "logout"]
        
        if user_id not in self.user_sessions:
            # New user, start at login
            self.user_sessions[user_id] = {
                "state": "login",
                "last_update": time.time()
            }
        else:
            # Existing user, advance state
            current_idx = states.index(self.user_sessions[user_id]["state"])
            next_idx = (current_idx + 1) % len(states)
            self.user_sessions[user_id] = {
                "state": states[next_idx],
                "last_update": time.time()
            }
            
            # Clean up old sessions
            if len(self.user_sessions) > 100:
                # Remove oldest sessions
                current_time = time.time()
                self.user_sessions = {
                    uid: session for uid, session in self.user_sessions.items()
                    if current_time - session["last_update"] < 300  # 5 minutes
                }
    
    def _create_message_from_pattern(self, log_type, user_id):
        """Create message based on log patterns."""
        if user_id in self.user_sessions:
            state = self.user_sessions[user_id]["state"]
            
            # User session pattern
            session_messages = {
                "login": "User logged in successfully",
                "browse": "User browsing product catalog",
                "search": "User performed search query",
                "view_item": "User viewing product details",
                "add_to_cart": "User added item to cart",
                "checkout": "User initiated checkout process",
                "purchase": "User completed purchase",
                "logout": "User logged out"
            }
            
            if state in session_messages:
                return session_messages[state]
        
        # Fallback to standard messages
        messages = {
            "INFO": [
                "User logged in successfully",
                "Page loaded in 0.2 seconds",
                "Database connection established",
                "Cache refreshed successfully",
                "API request completed"
            ],
            "WARNING": [
                "High memory usage detected",
                "API response time exceeding threshold",
                "Database connection pool running low",
                "Retry attempt for failed operation",
                "Cache miss rate increasing"
            ],
            "ERROR": [
                "Failed to connect to database",
                "API request timeout",
                "Invalid user credentials",
                "Processing error in data pipeline",
                "Out of memory error"
            ],
            "DEBUG": [
                "Function X called with parameters Y",
                "SQL query execution details",
                "Cache lookup performed",
                "Request headers processed",
                "Internal state transition"
            ]
        }
        
        if log_type in messages:
            return random.choice(messages[log_type])
        else:
            return f"Sample log message for {log_type}"
    
    def run(self, duration=None):
        """Run the log generator with burst mode support."""
        print(f"Starting log generator with rate: {self.config['LOG_RATE']} logs/second")
        print(f"Log format: {self.config['LOG_FORMAT']}")
        print(f"Burst mode enabled: {self.config['ENABLE_BURSTS']}")
        
        start_time = time.time()
        count = 0
        
        try:
            while duration is None or time.time() - start_time < duration:
                # Check if we should enter or exit burst mode
                current_time = time.time()
                if self.config["ENABLE_BURSTS"]:
                    if not self.in_burst_mode:
                        # Check if we should start a burst
                        if random.random() < self.config["BURST_FREQUENCY"]:
                            self.in_burst_mode = True
                            self.burst_end_time = current_time + self.config["BURST_DURATION"]
                            print(f"⚡ Entering burst mode for {self.config['BURST_DURATION']} seconds")
                    elif current_time > self.burst_end_time:
                        # Exit burst mode
                        self.in_burst_mode = False
                        print("✓ Exiting burst mode")
                
                # Calculate current log rate
                current_rate = self.config["LOG_RATE"]
                if self.in_burst_mode:
                    current_rate = current_rate * self.config["BURST_MULTIPLIER"]
                
                # Calculate sleep time based on current rate
                sleep_time = 1.0 / current_rate if current_rate > 0 else 1.0
                
                # Generate and write log entry
                log_entry = self.generate_log_message()
                self.write_log(log_entry)
                count += 1
                
                # Sleep to maintain the configured rate
                time.sleep(sleep_time)
                
        except KeyboardInterrupt:
            print("\nLog generator stopped by user")
        
        print(f"Generated {count} log entries")