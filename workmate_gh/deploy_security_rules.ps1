# WorkMate GH - Firebase Security Rules Deployment Script
# PowerShell version for Windows

Write-Host "🚀 WorkMate GH - Firebase Security Rules Deployment" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
Write-Host "🔍 Checking prerequisites..." -ForegroundColor Yellow

try {
    $firebaseVersion = firebase --version
    Write-Host "✅ Firebase CLI found: $firebaseVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Firebase CLI not found. Please install it first:" -ForegroundColor Red
    Write-Host "   npm install -g firebase-tools" -ForegroundColor White
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""

# Verify security rules compliance
Write-Host "🛡️  Verifying security rules compliance..." -ForegroundColor Yellow
$complianceResult = dart run analyze_security_rules.dart
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Security rules compliance check failed!" -ForegroundColor Red
    Write-Host "   Please fix security issues before deployment." -ForegroundColor White
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "✅ Security rules compliance verified (100%)" -ForegroundColor Green
Write-Host ""

# Run mock security tests
Write-Host "🧪 Running security validation tests..." -ForegroundColor Yellow
$testResult = flutter test test/security_rules_mock_test.dart
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Security tests failed!" -ForegroundColor Red
    Write-Host "   Please fix test failures before deployment." -ForegroundColor White
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "✅ All security tests passed" -ForegroundColor Green
Write-Host ""

# Confirm deployment
Write-Host "⚠️  DEPLOYMENT CONFIRMATION" -ForegroundColor Yellow
Write-Host "========================" -ForegroundColor Yellow
Write-Host ""
Write-Host "You are about to deploy Firebase Security Rules to production." -ForegroundColor White
Write-Host "This will update the security rules for your Firebase project." -ForegroundColor White
Write-Host ""

$confirmation = Read-Host "Do you want to continue? (y/N)"
if ($confirmation -ne "y" -and $confirmation -ne "Y") {
    Write-Host "Deployment cancelled by user." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 0
}

Write-Host ""
Write-Host "📤 Deploying Firebase Security Rules..." -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

# Deploy only firestore rules
try {
    firebase deploy --only firestore:rules
    if ($LASTEXITCODE -ne 0) {
        throw "Firebase deployment failed"
    }
} catch {
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    Write-Host "   Please check your Firebase project configuration." -ForegroundColor White
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "✅ Security Rules Successfully Deployed!" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Post-Deployment Checklist:" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host "✅ Firebase Security Rules deployed" -ForegroundColor Green
Write-Host "🔍 Verify deployment in Firebase Console" -ForegroundColor Yellow
Write-Host "📊 Monitor for any permission errors" -ForegroundColor Yellow
Write-Host "🛡️  Security status: PRODUCTION READY" -ForegroundColor Green
Write-Host ""
Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
Write-Host "   Your WorkMate GH security rules are now active." -ForegroundColor White
Write-Host ""

Read-Host "Press Enter to exit"
