@echo off
setlocal enabledelayedexpansion

echo 🔐 Firebase Security Rules Testing Suite
echo ========================================

REM Check if Firebase CLI is installed
firebase --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Firebase CLI not found. Please install it first:
    echo    npm install -g firebase-tools
    exit /b 1
)

REM Check if Flutter is available
flutter --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Flutter not found. Please ensure Flutter is installed and in PATH.
    exit /b 1
)

echo ✅ Prerequisites check passed
echo.

REM Start Firebase Emulators
echo 🚀 Starting Firebase Emulators...
start /b firebase emulators:start --only auth,firestore

REM Wait for emulators to start
echo ⏳ Waiting for emulators to initialize...
timeout /t 15 /nobreak >nul

REM Check if emulators are running
curl -s http://127.0.0.1:4000 >nul 2>&1
if errorlevel 1 (
    echo ❌ Firebase Emulator UI not accessible. Please check emulator status.
    taskkill /f /im node.exe >nul 2>&1
    exit /b 1
)

echo ✅ Firebase Emulators are running
echo    - Firestore: http://127.0.0.1:8080
echo    - Auth: http://127.0.0.1:9099
echo    - UI: http://127.0.0.1:4000
echo.

REM Run security tests
echo 🔐 Running Security Rules Tests...
echo ==================================

REM Create test runner
flutter test lib\test\emulator_test_runner.dart

REM Capture test result
set TEST_RESULT=%errorlevel%

REM Stop emulators
echo.
echo 🛑 Stopping Firebase Emulators...
taskkill /f /im node.exe >nul 2>&1

REM Print final result
echo.
if %TEST_RESULT% equ 0 (
    echo ✅ All Security Rules Tests Passed!
) else (
    echo ❌ Some Security Rules Tests Failed!
)

echo ========================================
echo Security Rules Testing Complete

exit /b %TEST_RESULT%
