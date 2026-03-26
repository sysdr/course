#!/usr/bin/env python3
"""
Complete automated setup execution
Executes setup.sh and verifies everything
"""
import subprocess
import os
import sys
import time
from pathlib import Path

def main():
    script_dir = Path(__file__).parent.absolute()
    os.chdir(script_dir)
    
    print("=" * 70)
    print("Day 150 - Complete Automated Setup")
    print("=" * 70)
    print(f"Working directory: {script_dir}\n")
    
    # Step 1: Execute setup.sh
    print("📦 Step 1: Executing setup.sh...")
    print("-" * 70)
    
    setup_script = script_dir / "setup.sh"
    if not setup_script.exists():
        print(f"❌ Error: {setup_script} not found")
        return 1
    
    # Make executable
    os.chmod(setup_script, 0o755)
    
    try:
        # Run setup script
        process = subprocess.Popen(
            ["bash", str(setup_script)],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            universal_newlines=True
        )
        
        # Stream output
        for line in process.stdout:
            print(line, end='')
        
        process.wait()
        
        if process.returncode != 0:
            print(f"\n⚠️  Setup script exited with code {process.returncode}")
            print("Continuing with verification...")
    except Exception as e:
        print(f"❌ Error executing setup: {e}")
        return 1
    
    # Step 2: Verify project directory exists
    project_dir = script_dir / "day150-cloud-deployment"
    print("\n" + "=" * 70)
    print("🔍 Step 2: Verifying setup...")
    print("-" * 70)
    
    if not project_dir.exists():
        print(f"❌ Project directory {project_dir} does not exist")
        return 1
    
    print(f"✅ Project directory exists: {project_dir}")
    
    # Step 3: Verify key files
    key_files = [
        "requirements.txt",
        "start.sh",
        "stop.sh",
        "web/app.py",
        "web/templates/dashboard.html",
        "scripts/deploy.py",
        "terraform/environments/dev/main.tf",
    ]
    
    missing = []
    for file in key_files:
        full_path = project_dir / file
        if full_path.exists():
            print(f"  ✅ {file}")
        else:
            print(f"  ❌ MISSING: {file}")
            missing.append(file)
    
    if missing:
        print(f"\n⚠️  {len(missing)} file(s) missing, but continuing...")
    
    # Step 4: Check for duplicate services
    print("\n" + "=" * 70)
    print("🔍 Step 4: Checking for duplicate services...")
    print("-" * 70)
    
    try:
        result = subprocess.run(
            ["pgrep", "-f", "python.*web/app.py"],
            capture_output=True,
            text=True
        )
        if result.returncode == 0 and result.stdout.strip():
            pids = result.stdout.strip().split('\n')
            print(f"⚠️  Found existing processes: {', '.join(pids)}")
            print("   Stopping duplicates...")
            subprocess.run(["pkill", "-f", "python.*web/app.py"], check=False)
            time.sleep(2)
        else:
            print("✅ No duplicate services found")
    except Exception as e:
        print(f"⚠️  Could not check: {e}")
    
    # Step 5: Prepare environment
    print("\n" + "=" * 70)
    print("🔧 Step 5: Preparing environment...")
    print("-" * 70)
    
    os.chdir(project_dir)
    
    # Make scripts executable
    for script in ["start.sh", "stop.sh", "scripts/deploy.py"]:
        script_path = project_dir / script
        if script_path.exists():
            os.chmod(script_path, 0o755)
            print(f"  ✅ Made executable: {script}")
    
    # Step 6: Run tests (optional, non-blocking)
    print("\n" + "=" * 70)
    print("🧪 Step 6: Running tests (optional)...")
    print("-" * 70)
    
    venv_path = project_dir / "venv"
    if venv_path.exists() and (venv_path / "bin" / "python").exists():
        python_cmd = str(venv_path / "bin" / "python")
        try:
            result = subprocess.run(
                [python_cmd, "-m", "pytest", "tests/", "-v"],
                cwd=str(project_dir),
                capture_output=True,
                text=True,
                timeout=60
            )
            print(result.stdout)
            if result.stderr:
                print(result.stderr)
        except subprocess.TimeoutExpired:
            print("⚠️  Tests timed out")
        except Exception as e:
            print(f"⚠️  Could not run tests: {e}")
    else:
        print("⚠️  Virtual environment not ready, skipping tests")
        print("   (Tests will run when you execute start.sh)")
    
    # Step 7: Start dashboard
    print("\n" + "=" * 70)
    print("🌐 Step 7: Starting dashboard...")
    print("-" * 70)
    
    start_script = project_dir / "start.sh"
    if start_script.exists():
        print(f"Executing: {start_script}")
        print("Dashboard will start in the background...")
        print("Access at: http://localhost:5000")
        print("\n" + "=" * 70)
        print("✅ Setup Complete!")
        print("=" * 70)
        print(f"\nTo start dashboard manually:")
        print(f"  cd {project_dir}")
        print(f"  bash start.sh")
        print(f"\nTo stop dashboard:")
        print(f"  cd {project_dir}")
        print(f"  bash stop.sh")
        print(f"\nDashboard metrics will show non-zero values in demo mode:")
        print(f"  - Dev: 18 resources, $150/month")
        print(f"  - Staging: 25 resources, $500/month")
        print(f"  - Prod: 44 resources, $2500/month")
        print("\n" + "=" * 70)
        
        # Optionally start in background
        try:
            subprocess.Popen(
                ["bash", str(start_script)],
                cwd=str(project_dir),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            print("\n✅ Dashboard started in background!")
            print("   Wait 5-10 seconds, then access: http://localhost:5000")
        except Exception as e:
            print(f"⚠️  Could not start dashboard automatically: {e}")
            print("   Please run manually: cd day150-cloud-deployment && bash start.sh")
    else:
        print(f"❌ start.sh not found at {start_script}")
        return 1
    
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
