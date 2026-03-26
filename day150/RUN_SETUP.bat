@echo off
REM Windows batch script to run setup via WSL
echo ========================================
echo Day 150 - Setup Execution
echo ========================================
echo.

wsl bash -c "cd /home/systemdr03/git/course/day150 && bash setup.sh"

echo.
echo ========================================
echo Setup execution complete!
echo ========================================
echo.
echo Next steps:
echo 1. Verify files: wsl bash verify_setup.sh
echo 2. Start dashboard: wsl bash -c "cd day150-cloud-deployment && bash start.sh"
echo 3. Open http://localhost:5000 in browser
echo.
pause
