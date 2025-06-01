# integration/pipeline.py
import os
import yaml
import argparse
import subprocess
import time
import signal
import sys

class LogPipeline:
    def __init__(self, config_path):
        self.config_path = config_path
        self.processes = {}
        self.running = False
        self.load_config()
    
    def load_config(self):
        """Load configuration from YAML file"""
        try:
            with open(self.config_path, 'r') as f:
                self.config = yaml.safe_load(f)
            print(f"Configuration loaded from {self.config_path}")
        except Exception as e:
            print(f"Error loading configuration: {str(e)}")
            sys.exit(1)
    
    def start_component(self, name, command):
        """Start a component process"""
        try:
            print(f"Starting {name} component...")
            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1,
                shell=True
            )
            self.processes[name] = {
                'process': process,
                'command': command
            }
            print(f"{name} component started with PID {process.pid}")
            return True
        except Exception as e:
            print(f"Error starting {name} component: {str(e)}")
            return False
    
    def stop_component(self, name):
        """Stop a component process"""
        if name not in self.processes:
            return
        
        try:
            process = self.processes[name]['process']
            print(f"Stopping {name} component (PID {process.pid})...")
            
            # Try to terminate gracefully
            process.terminate()
            
            # Wait for a moment to let it terminate
            for _ in range(5):
                if process.poll() is not None:
                    break
                time.sleep(0.5)
            
            # Force kill if still running
            if process.poll() is None:
                print(f"{name} not responding to termination, killing process...")
                process.kill()
            
            print(f"{name} component stopped")
            del self.processes[name]
        except Exception as e:
            print(f"Error stopping {name} component: {str(e)}")
    
    def start_pipeline(self):
        """Start all components of the pipeline"""
        print("Starting log processing pipeline...")
        self.running = True
        
        # Create required directories
        for directory in self.config.get('directories', []):
            os.makedirs(directory, exist_ok=True)
            print(f"Ensured directory exists: {directory}")
        
        # Start components in order
        for component in self.config.get('components', []):
            name = component.get('name')
            command = component.get('command')
            
            if not name or not command:
                continue
            
            success = self.start_component(name, command)
            if not success:
                print(f"Failed to start {name} component")
                self.stop_pipeline()
                return False
            
            # Slight delay between starting components
            time.sleep(2)
        
        print("All components started successfully")
        return True
    
    def stop_pipeline(self):
        """Stop all components of the pipeline"""
        print("Stopping log processing pipeline...")
        self.running = False
        
        # Stop components in reverse order
        component_names = list(self.processes.keys())
        for name in reversed(component_names):
            self.stop_component(name)
        
        print("All components stopped")
    
    def monitor_pipeline(self):
        """Monitor running components and restart if needed"""
        while self.running:
            for name, data in list(self.processes.items()):
                process = data['process']
                if process.poll() is not None:
                    print(f"{name} component exited unexpectedly with code {process.returncode}")
                    print(f"Restarting {name} component...")
                    self.stop_component(name)
                    self.start_component(name, data['command'])
            
            time.sleep(5)
    
    def run(self):
        """Run the pipeline and handle interruption"""
        try:
            success = self.start_pipeline()
            if success:
                print("Pipeline is running. Press Ctrl+C to stop.")
                self.monitor_pipeline()
        except KeyboardInterrupt:
            print("\nReceived interrupt signal. Shutting down pipeline...")
        finally:
            self.stop_pipeline()

def main():
    parser = argparse.ArgumentParser(description='Run an integrated log processing pipeline')
    parser.add_argument('--config', type=str, default='/app/integration/config.yml', help='Path to configuration file')
    
    args = parser.parse_args()
    
    pipeline = LogPipeline(args.config)
    pipeline.run()

if __name__ == "__main__":
    main()