# PowerShell script to deploy Firestore indexes for WorkMate GH
# This script creates the necessary composite indexes for optimal query performance

Write-Host "=== WorkMate GH Firestore Index Deployment ===" -ForegroundColor Green
Write-Host "Project: workmate-gh" -ForegroundColor Yellow

# Check if Firebase CLI is installed
try {
    $firebaseVersion = firebase --version
    Write-Host "Firebase CLI Version: $firebaseVersion" -ForegroundColor Green
} catch {
    Write-Host "Error: Firebase CLI is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Firebase CLI: npm install -g firebase-tools" -ForegroundColor Yellow
    exit 1
}

# Check if logged in to Firebase
Write-Host "Checking Firebase authentication..." -ForegroundColor Yellow
try {
    $authList = firebase projects:list --json 2>$null | ConvertFrom-Json
    if ($authList -and $authList.Count -gt 0) {
        Write-Host "Firebase authentication: OK" -ForegroundColor Green
    } else {
        Write-Host "Error: Not logged in to Firebase" -ForegroundColor Red
        Write-Host "Please run: firebase login" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "Error: Not logged in to Firebase" -ForegroundColor Red
    Write-Host "Please run: firebase login" -ForegroundColor Yellow
    exit 1
}

# Deploy Firestore indexes
Write-Host "`nDeploying Firestore indexes..." -ForegroundColor Yellow

try {
    # Deploy indexes using Firebase CLI
    firebase deploy --only firestore:indexes --project workmate-gh
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n=== Indexes Deployed Successfully ===" -ForegroundColor Green
        Write-Host "The following indexes have been created/updated:" -ForegroundColor Cyan
        Write-Host "1. Companies index (active, name, __name__)" -ForegroundColor White
        Write-Host "2. Time entries by user and date" -ForegroundColor White
        Write-Host "3. Time entries by company and date" -ForegroundColor White
        Write-Host "4. Users by company, role, and name" -ForegroundColor White
        
        Write-Host "`nNote: Index creation may take 2-5 minutes to complete." -ForegroundColor Yellow
        Write-Host "Monitor progress at: https://console.firebase.google.com/project/workmate-gh/firestore/indexes" -ForegroundColor Cyan
    } else {
        Write-Host "Error: Failed to deploy Firestore indexes" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Error during index deployment: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Deployment Complete ===" -ForegroundColor Green