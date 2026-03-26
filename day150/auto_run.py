#!/usr/bin/env python3
"""
Automated execution script for Day 150 setup
Runs setup, verification, tests, and starts dashboard
"""
import subprocess
import os
import sys
import time
from pathlib import Path

def run_command(cmd, cwd=None, check=False):
    """Run a shell command and return result"""
    print(f"\n>>> Running: {' '.join(cmd) if isinstance(cmd, list) else cmd}")
    print("-" * 60)
    
    try:
        if isinstance(cmd, str):
            result = subprocess.run(
                cmd,
                shell=True,
                cwd=cwd,
                capture_output=False,
                text=True,
                check=check
            )
        else:
            result = subprocess.run(
                cmd,
                cwd=cwd,
                capture_output=False,
                text=True,
                check=check
            )
        return result.returncode == 0
    except Exception as e:
        print(f"Error: {e}")
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

def check_duplicate_services():
    """Check for duplicate Flask services"""
    print("\n🔍 Checking for duplicate services...")
    try:
        result = subprocess.run(
            ["pgrep", "-f", "python.*web/app.py"],
            capture_output=True,
            text=True
        )
        if result.returncode == 0 and result.stdout.strip():
            pids = result.stdout.strip().split('\n')
            print(f"⚠️  Found existing Flask processes: {', '.join(pids)}")
            print("   Stopping them...")
            subprocess.run(["pkill", "-f", "python.*web/app.py"], check=False)
            time.sleep(2)
            return True
        else:
            print("✅ No duplicate services found")
            return False
    except Exception as e:
        print(f"⚠️  Could not check for duplicates: {e}")
        return False

def main():
    """Main execution function"""
    script_dir = Path(__file__).parent
    os.chdir(script_dir)
    
    print("=" * 60)
    print("Day 150 - Automated Setup and Execution")
    print("=" * 60)
    
    # Step 1: Run setup script
    print("\n📦 Step 1: Running setup.sh...")
    if not Path("setup.sh").exists():
        print("❌ Error: setup.sh not found")
        return 1
    
    success = run_command(["bash", "setup.sh"], cwd=str(script_dir), check=False)
    if not success:
        print("⚠️  Setup script had issues, but continuing...")
    
    # Step 2: Verify files
    print("\n🔍 Step 2: Verifying generated files...")
    if not verify_files():
        print("❌ File verification failed")
        return 1
    
    # Step 3: Check for duplicates
    check_duplicate_services()
    
    # Step 4: Run tests
    project_dir = script_dir / "day150-cloud-deployment"
    print("\n🧪 Step 4: Running tests...")
    
    # Check if venv exists, create if not
    venv_path = project_dir / "venv"
    if not venv_path.exists():
        print("Creating virtual environment...")
        run_command(
            ["python3", "-m", "venv", "venv"],
            cwd=str(project_dir),
            check=False
        )
    
    # Activate venv and install dependencies
    if (project_dir / "venv" / "bin" / "activate").exists():
        pip_cmd = str(project_dir / "venv" / "bin" / "pip")
        python_cmd = str(project_dir / "venv" / "bin" / "python")
        
        print("Installing dependencies...")
        run_command([pip_cmd, "install", "--upgrade", "pip"], cwd=str(project_dir), check=False)
        run_command([pip_cmd, "install", "-r", "requirements.txt"], cwd=str(project_dir), check=False)
        
        print("Running tests...")
        run_command([python_cmd, "-m", "pytest", "tests/", "-v"], cwd=str(project_dir), check=False)
    
    # Step 5: Start dashboard
    print("\n🌐 Step 5: Starting dashboard...")
    start_script = project_dir / "start.sh"
    if start_script.exists():
        print(f"Starting dashboard with: {start_script}")
        # Run in background
        subprocess.Popen(
            ["bash", str(start_script)],
            cwd=str(project_dir)
        )
        print("✅ Dashboard starting...")
        print("   Wait a few seconds, then access: http://localhost:5000")
        print("   Metrics should show non-zero values in demo mode")
        time.sleep(3)
    else:
        print("❌ start.sh not found")
        return 1
    
    print("\n" + "=" * 60)
    print("✅ Automated execution complete!")
    print("=" * 60)
    print("\nDashboard should be available at: http://localhost:5000")
    print("To stop: cd day150-cloud-deployment && bash stop.sh")
    print("\nPress Ctrl+C to exit this script (dashboard will continue running)")
    
    # Keep script running
    try:
        while True:
            time.sleep(10)
            # Check if dashboard is still running
            result = subprocess.run(
                ["pgrep", "-f", "python.*web/app.py"],
                capture_output=True
            )
            if result.returncode != 0:
                print("\n⚠️  Dashboard process not found. It may have stopped.")
                break
    except KeyboardInterrupt:
        print("\n\nStopping...")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
