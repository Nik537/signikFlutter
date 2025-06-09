@echo off
echo ==========================================
echo Complete Gradle Cache Cleanup
echo ==========================================
echo.

echo WARNING: This will delete all Gradle caches and require re-downloading dependencies.
echo Close Android Studio and any other Java/Gradle processes before continuing.
echo.
pause

echo.
echo Step 1: Killing Java processes...
taskkill /F /IM java.exe 2>nul
taskkill /F /IM javaw.exe 2>nul

echo.
echo Step 2: Deleting Gradle cache directories...
echo Deleting %USERPROFILE%\.gradle\caches...
rmdir /s /q "%USERPROFILE%\.gradle\caches" 2>nul

echo Deleting %USERPROFILE%\.gradle\daemon...
rmdir /s /q "%USERPROFILE%\.gradle\daemon" 2>nul

echo Deleting %USERPROFILE%\.gradle\wrapper...
rmdir /s /q "%USERPROFILE%\.gradle\wrapper" 2>nul

echo.
echo Step 3: Deleting project-specific build directories...
cd /d %~dp0
rmdir /s /q .gradle 2>nul
rmdir /s /q build 2>nul
rmdir /s /q android\.gradle 2>nul
rmdir /s /q android\build 2>nul
rmdir /s /q android\app\build 2>nul
rmdir /s /q android\app\.cxx 2>nul

echo.
echo Step 4: Deleting Flutter build cache...
flutter clean

echo.
echo Step 5: Creating fresh gradle.properties...
echo # Gradle properties > android\gradle.properties
echo org.gradle.jvmargs=-Xmx4096m -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8 >> android\gradle.properties
echo org.gradle.parallel=true >> android\gradle.properties
echo org.gradle.configureondemand=false >> android\gradle.properties
echo org.gradle.caching=false >> android\gradle.properties
echo android.useAndroidX=true >> android\gradle.properties
echo android.enableJetifier=true >> android\gradle.properties

echo.
echo Step 6: Getting dependencies...
flutter pub get

echo.
echo ==========================================
echo Cleanup complete!
echo ==========================================
echo.
echo Now try running the app with:
echo   flutter run -d TB328FU
echo.
echo If it still fails, try:
echo   1. Open the project in Android Studio
echo   2. File -^> Invalidate Caches and Restart
echo   3. Let it sync and then run from Android Studio
echo.
pause