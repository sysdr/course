#!/usr/bin/env python3
"""
Cleanup script for the webhook notifications system.
Removes temporary files, cache directories, and resets demo data.
"""

import os
import shutil
import sys
from pathlib import Path

def cleanup():
    """Clean up temporary files and cache directories"""
    
    print("🧹 Cleaning up webhook notifications system...")
    
    # Get project root
    project_root = Path(__file__).parent.parent
    
    # Directories to remove
    dirs_to_remove = [
        project_root / "src" / "__pycache__",
        project_root / ".pytest_cache",
        project_root / "frontend" / "build",
        project_root / "frontend" / "node_modules",
        project_root / "__pycache__",
    ]
    
    # Files to remove
    files_to_remove = [
        project_root / "requirements.txt.bak",
        project_root / ".coverage",
        project_root / "htmlcov",
    ]
    
    # Remove directories
    for dir_path in dirs_to_remove:
        if dir_path.exists():
            print(f"   Removing directory: {dir_path}")
            shutil.rmtree(dir_path)
    
    # Remove files
    for file_path in files_to_remove:
        if file_path.exists():
            print(f"   Removing file: {file_path}")
            file_path.unlink()
    
    # Find and remove Python cache files
    for root, dirs, files in os.walk(project_root):
        # Remove __pycache__ directories
        if "__pycache__" in dirs:
            pycache_path = Path(root) / "__pycache__"
            print(f"   Removing: {pycache_path}")
            shutil.rmtree(pycache_path)
        
        # Remove .pyc files
        for file in files:
            if file.endswith(".pyc"):
                pyc_path = Path(root) / file
                print(f"   Removing: {pyc_path}")
                pyc_path.unlink()
    
    print("✅ Cleanup complete!")

if __name__ == "__main__":
    cleanup()
