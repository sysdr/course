# Add to the __init__ method:
self.log_buffer = []
self.buffer_size = 100  # Flush after this many logs
self.buffer_timeout = 5  # Flush after this many seconds
self.last_flush_time = time.time()

# Add a new method to flush the buffer:
def flush_buffer(self):
    """Write buffered logs to disk."""
    if not self.log_buffer:
        return
        
    # Write all logs in buffer to file
    with open(self.log_file, 'a') as f:
        f.write('\n'.join(self.log_buffer) + '\n')
        
    # Clear the buffer
    self.log_buffer.clear()
    self.last_flush_time = time.time()

# Modify the process_log method:
def process_log(self, data, addr):
    try:
        # ... (existing code to process the log)
        
        # Add to buffer instead of writing immediately
        self.log_buffer.append(log_str)
        
        # Flush if buffer is full or timeout reached
        if (len(self.log_buffer) >= self.buffer_size or
                time.time() - self.last_flush_time >= self.buffer_timeout):
            self.flush_buffer()
            
        # ... (rest of existing code)
    except Exception as e:
        print(f"Error processing log: {e}")

# Modify the run method to flush before exiting:
def run(self):
    # ... (existing code)
    
    try:
        while True:
            # ... (existing code)
            
    except KeyboardInterrupt:
        print("\nShutting down server...")
    finally:
        # Flush any remaining logs
        self.flush_buffer()
        
        if self.socket:
            self.socket.close()
        print(f"Server stopped. Processed {self.log_count} logs.")