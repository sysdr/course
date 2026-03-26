# Execution Guide - Day 150 Setup

## Quick Start

Since automated execution is having issues, here are the manual steps:

### Option 1: Using WSL (Recommended)

```bash
# 1. Open WSL terminal
wsl

# 2. Navigate to project
cd /home/systemdr03/git/course/day150

# 3. Run setup
bash setup.sh

# 4. Verify files were created
bash verify_setup.sh

# 5. Navigate to project and start
cd day150-cloud-deployment
bash start.sh

# 6. Open browser to http://localhost:5000
```

### Option 2: Using Windows Batch File

Double-click `RUN_SETUP.bat` or run:
```cmd
RUN_SETUP.bat
```

### Option 3: Direct WSL Command

```cmd
wsl bash -c "cd /home/systemdr03/git/course/day150 && bash setup.sh"
```

## Verification Steps

After setup completes, verify:

1. **Check project directory exists:**
   ```bash
   ls -la day150-cloud-deployment
   ```

2. **Verify key files:**
   ```bash
   cd day150-cloud-deployment
   ls -la start.sh stop.sh web/app.py scripts/deploy.py
   ```

3. **Check for duplicate services:**
   ```bash
   pgrep -f "python.*web/app.py"
   ```

4. **Run tests:**
   ```bash
   cd day150-cloud-deployment
   source venv/bin/activate  # if venv exists
   python -m pytest tests/ -v
   ```

## Starting the Dashboard

```bash
cd day150-cloud-deployment
bash start.sh
```

The dashboard will:
- Check for duplicate services and stop them
- Create/activate virtual environment
- Install dependencies
- Run tests
- Start Flask dashboard on http://localhost:5000

## Dashboard Validation

Once the dashboard is running:

1. Open http://localhost:5000 in your browser
2. Verify metrics show **non-zero values**:
   - **Dev**: Should show 18 resources, $150/month
   - **Staging**: Should show 25 resources, $500/month  
   - **Prod**: Should show 44 resources, $2500/month
3. Metrics auto-refresh every 30 seconds
4. Status badges should show "Deployed" (green)

## Stopping Services

```bash
cd day150-cloud-deployment
bash stop.sh
```

Or manually:
```bash
pkill -f "python.*web/app.py"
```

## Troubleshooting

### Setup script fails
- Check you have bash available
- Ensure you have write permissions in the directory
- Check disk space

### Dashboard shows zero values
- The dashboard is in DEMO_MODE by default
- If you see zeros, check browser console for errors
- Verify web/app.py has DEMO_MODE = True

### Port 5000 already in use
```bash
# Find process using port 5000
lsof -i :5000

# Kill it
kill <PID>

# Or use stop.sh
cd day150-cloud-deployment
bash stop.sh
```

### Tests fail
- Some tests require cloud CLI tools (terraform, aws cli, etc.)
- This is expected if tools aren't installed
- The setup script continues even if tests fail

## Files Created

The setup script creates:

```
day150-cloud-deployment/
├── requirements.txt
├── start.sh (with full path support)
├── stop.sh (with duplicate detection)
├── terraform/ (modules and environments)
├── scripts/ (deploy.py)
├── web/ (app.py with DEMO_MODE, dashboard.html)
├── tests/ (test files)
├── docs/ (documentation)
└── Docker files
```

## Key Features Implemented

✅ **Full path support** in start.sh and stop.sh  
✅ **Duplicate service detection** and cleanup  
✅ **Demo mode** with non-zero metrics  
✅ **Error handling** for optional steps  
✅ **File verification** script  
✅ **Comprehensive testing** setup  

## Next Steps After Setup

1. Review `docs/DEPLOYMENT_GUIDE.md`
2. Customize Terraform configurations in `terraform/environments/`
3. Deploy to cloud: `python scripts/deploy.py --environment dev --cloud aws`
4. Monitor via dashboard
