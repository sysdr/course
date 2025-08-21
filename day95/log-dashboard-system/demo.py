#!/usr/bin/env python3
"""
Demo script for the Log Dashboard System
Generates sample data and starts the dashboard
"""

import asyncio
import uvicorn
import threading
import time
import webbrowser
from pathlib import Path
import subprocess
import sys
import os

def start_frontend():
    """Start the frontend development server"""
    frontend_dir = Path(__file__).parent / "frontend"
    try:
        print("🎨 Starting frontend development server...")
        subprocess.Popen(
            ["npm", "run", "dev"],
            cwd=frontend_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        print("✅ Frontend server started on http://localhost:3000")
    except Exception as e:
        print(f"❌ Failed to start frontend: {e}")

def start_backend():
    """Start the backend server"""
    try:
        print("🔧 Starting backend server...")
        uvicorn.run(
            "app.main:app",
            host="0.0.0.0",
            port=8000,
            reload=True,
            log_level="info"
        )
    except Exception as e:
        print(f"❌ Failed to start backend: {e}")

def open_browser():
    """Open browser after a delay"""
    time.sleep(3)
    try:
        webbrowser.open("http://localhost:3000")
        print("🌐 Browser opened to dashboard")
    except Exception as e:
        print(f"⚠️ Could not open browser automatically: {e}")
        print("🌐 Please open http://localhost:3000 manually")

def main():
    """Main demo function"""
    print("🎬 Day 95: Log Dashboard System Demo")
    print("=" * 50)
    
    # Check if we're in the right directory
    project_root = Path(__file__).parent
    backend_dir = project_root / "backend"
    
    if not backend_dir.exists():
        print("❌ Backend directory not found. Please run from project root.")
        sys.exit(1)
    
    # Change to backend directory for imports
    os.chdir(backend_dir)
    
    # Add current directory to Python path
    sys.path.insert(0, str(backend_dir))
    
    print("🚀 Starting dashboard system...")
    print("📊 Backend: http://localhost:8000")
    print("🎨 Frontend: http://localhost:3000")
    print("📚 API Docs: http://localhost:8000/docs")
    
    # Start frontend in a separate thread
    frontend_thread = threading.Thread(target=start_frontend, daemon=True)
    frontend_thread.start()
    
    # Start browser in a separate thread
    browser_thread = threading.Thread(target=open_browser, daemon=True)
    browser_thread.start()
    
    # Start backend (this will block)
    try:
        start_backend()
    except KeyboardInterrupt:
        print("\n🛑 Demo stopped by user")
    except Exception as e:
        print(f"❌ Demo failed: {e}")

if __name__ == "__main__":
    main()
