#!/usr/bin/env python3

import os
import sys

def verify_project_structure():
    """Verify that all required files and directories exist"""
    
    print("🔍 Verifying project structure...")
    
    required_items = [
        # Directories
        ("src/webhook", "directory"),
        ("src/api", "directory"), 
        ("frontend/src", "directory"),
        ("tests/unit", "directory"),
        ("tests/integration", "directory"),
        ("config", "directory"),
        ("scripts", "directory"),
        
        # Python files
        ("src/main.py", "file"),
        ("src/webhook/models.py", "file"),
        ("src/webhook/subscription_manager.py", "file"),
        ("src/webhook/delivery_engine.py", "file"),
        ("src/webhook/event_listener.py", "file"),
        ("src/api/routes.py", "file"),
        ("config/webhook_config.py", "file"),
        
        # Frontend files
        ("frontend/package.json", "file"),
        ("frontend/src/App.js", "file"),
        ("frontend/src/index.js", "file"),
        
        # Configuration files
        ("requirements.txt", "file"),
        ("Dockerfile", "file"),
        ("docker-compose.yml", "file"),
        (".env", "file"),
        
        # Scripts
        ("start.sh", "file"),
        ("stop.sh", "file"),
        ("scripts/demo.py", "file"),
        
        # Tests
        ("tests/unit/test_subscription_manager.py", "file"),
        ("tests/integration/test_webhook_flow.py", "file")
    ]
    
    missing_items = []
    
    for item_path, item_type in required_items:
        if item_type == "directory":
            if not os.path.isdir(item_path):
                missing_items.append(f"Directory: {item_path}")
        elif item_type == "file":
            if not os.path.isfile(item_path):
                missing_items.append(f"File: {item_path}")
    
    if missing_items:
        print("❌ Missing items:")
        for item in missing_items:
            print(f"   • {item}")
        return False
    else:
        print("✅ All required files and directories exist")
        return True

def verify_file_contents():
    """Verify that key files have content"""
    
    print("🔍 Verifying file contents...")
    
    key_files = [
        "src/main.py",
        "src/webhook/models.py", 
        "src/webhook/subscription_manager.py",
        "frontend/src/App.js",
        "requirements.txt"
    ]
    
    for file_path in key_files:
        if os.path.isfile(file_path):
            with open(file_path, 'r') as f:
                content = f.read().strip()
                if content:
                    print(f"   ✅ {file_path} has content ({len(content)} chars)")
                else:
                    print(f"   ❌ {file_path} is empty")
                    return False
        else:
            print(f"   ❌ {file_path} does not exist")
            return False
    
    return True

def main():
    print("🚀 Day 90: Webhook Notifications - Project Verification")
    print("=" * 60)
    
    structure_ok = verify_project_structure()
    content_ok = verify_file_contents()
    
    if structure_ok and content_ok:
        print("\n✅ Project verification successful!")
        print("🎯 Ready to start the webhook notifications system")
        return 0
    else:
        print("\n❌ Project verification failed!")
        print("Please run the setup script again")
        return 1

if __name__ == "__main__":
    sys.exit(main())
