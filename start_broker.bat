@echo off
echo Starting Signik Broker Service...
echo ================================
echo.

cd signik_broker

python --version 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Python is not installed!
    echo Please run check_python_setup.bat first
    echo.
    pause
    exit /b 1
)

echo Starting broker on http://localhost:8000
echo.
echo API Documentation: http://localhost:8000/docs
echo.
echo Press Ctrl+C to stop the broker
echo.

python main.py

pause 