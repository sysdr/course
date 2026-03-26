#!/usr/bin/env python3
"""
Run setup.sh and verify all files are created
"""
import subprocess
import os
import sys
from pathlib import Path

def run_setup():
    """Run the setup script"""
    script_dir = Path(__file__).parent
    setup_script = script_dir / "setup.sh"
    
    if not setup_script.exists():
        print(f"❌ Error: {setup_script} not found")
        return False
    
    print("🚀 Running setup.sh...")
    print("=" * 60)
    
    try:
        result = subprocess.run(
            ["bash", str(setup_script)],
            cwd=str(script_dir),
            capture_output=False,
            text=True
        )
        
        if result.returncode == 0:
            print("\n✅ Setup script completed successfully")
            return True
        else:
            print(f"\n⚠️  Setup script exited with code {result.returncode}")
            return False
    except Exception as e:
        print(f"❌ Error running setup script: {e}")
        return False

def verify_files():
    """Verify all expected files exist"""
    script_dir = Path(__file__).parent
    project_dir = script_dir / "day150-cloud-deployment"
    
    if not project_dir.exists():
        print(f"❌ Project directory {project_dir} does not exist")
        return False
    
    expected_files = [
        "requirements.txt",
        "requirements-terraform.txt",
        "terraform/modules/aws/compute/main.tf",
        "terraform/modules/aws/storage/main.tf",
        "terraform/modules/aws/network/main.tf",
        "terraform/environments/dev/main.tf",
        "scripts/deploy.py",
        "web/app.py",
        "web/templates/dashboard.html",
        "tests/test_terraform_validation.py",
        "tests/test_cost_estimation.py",
        "docs/DEPLOYMENT_GUIDE.md",
        "Dockerfile",
        "docker-compose.yml",
        ".dockerignore",
        "start.sh",
        "stop.sh",
    ]
    
    print("\n🔍 Verifying generated files...")
    missing = []
    for file in expected_files:
        full_path = project_dir / file
        if full_path.exists():
            print(f"  ✅ {file}")
        else:
            print(f"  ❌ MISSING: {file}")
            missing.append(file)
    
    if missing:
        print(f"\n❌ {len(missing)} file(s) are missing")
        return False
    else:
        print("\n✅ All expected files are present!")
        return True

if __name__ == "__main__":
    success = run_setup()
    if success:
        verify_files()
    sys.exit(0 if success else 1)
