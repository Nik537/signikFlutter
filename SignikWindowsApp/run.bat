@echo off
echo Building Signik Windows Device Manager...
dotnet build

if %ERRORLEVEL% EQU 0 (
    echo Build successful! Starting application...
    dotnet run
) else (
    echo Build failed. Please check for errors.
    pause
) 