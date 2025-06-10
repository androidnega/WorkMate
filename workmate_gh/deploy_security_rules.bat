@echo off
setlocal enabledelayedexpansion

echo 🚀 WorkMate GH - Firebase Security Rules Deployment
echo ===================================================
echo.

REM Check prerequisites
echo 🔍 Checking prerequisites...
firebase --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Firebase CLI not found. Please install it first:
    echo    npm install -g firebase-tools
    pause
    exit /b 1
)

echo ✅ Firebase CLI found
echo.

REM Verify security rules compliance
echo 🛡️  Verifying security rules compliance...
dart run analyze_security_rules.dart
if errorlevel 1 (
    echo ❌ Security rules compliance check failed!
    echo    Please fix security issues before deployment.
    pause
    exit /b 1
)

echo.
echo ✅ Security rules compliance verified (100%)
echo.

REM Run mock security tests
echo 🧪 Running security validation tests...
flutter test test/security_rules_mock_test.dart
if errorlevel 1 (
    echo ❌ Security tests failed!
    echo    Please fix test failures before deployment.
    pause
    exit /b 1
)

echo.
echo ✅ All security tests passed
echo.

REM Confirm deployment
echo ⚠️  DEPLOYMENT CONFIRMATION
echo ========================
echo.
echo You are about to deploy Firebase Security Rules to production.
echo This will update the security rules for your Firebase project.
echo.
set /p CONFIRM="Do you want to continue? (y/N): "
if /i not "%CONFIRM%"=="y" (
    echo Deployment cancelled by user.
    pause
    exit /b 0
)

echo.
echo 📤 Deploying Firebase Security Rules...
echo =======================================

REM Deploy only firestore rules
firebase deploy --only firestore:rules
if errorlevel 1 (
    echo ❌ Deployment failed!
    echo    Please check your Firebase project configuration.
    pause
    exit /b 1
)

echo.
echo ✅ Security Rules Successfully Deployed!
echo =======================================
echo.
echo 📋 Post-Deployment Checklist:
echo ============================
echo ✅ Firebase Security Rules deployed
echo 🔍 Verify deployment in Firebase Console
echo 📊 Monitor for any permission errors
echo 🛡️  Security status: PRODUCTION READY
echo.
echo 🎉 Deployment completed successfully!
echo    Your WorkMate GH security rules are now active.
echo.

pause
