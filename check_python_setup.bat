@echo off
echo ========================================
echo   Signik Python Setup Checker
echo ========================================
echo.

echo Checking Python installation...
python --version 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Python is not installed or not in PATH
    echo.
    echo To install Python:
    echo 1. Download from https://www.python.org/downloads/
    echo 2. During installation, CHECK "Add Python to PATH"
    echo 3. Or install via: winget install Python.Python.3.11
    echo.
    goto :check_pip
) else (
    echo [OK] Python is installed
)

:check_pip
echo.
echo Checking pip installation...
pip --version 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] pip is not available
    echo.
    echo To install pip:
    echo 1. Download get-pip.py from https://bootstrap.pypa.io/get-pip.py
    echo 2. Run: python get-pip.py
) else (
    echo [OK] pip is installed
)

echo.
echo ========================================
echo.

REM Try to install broker dependencies if Python is available
python --version 2>nul
if %errorlevel% equ 0 (
    echo Would you like to install Signik broker dependencies now? (Y/N)
    set /p choice=
    if /i "%choice%"=="Y" (
        echo.
        echo Installing dependencies...
        cd signik_broker
        pip install -r requirements.txt
        echo.
        echo Installation complete!
        echo You can now run the broker with: python main.py
        cd ..
    )
)

echo.
pause 