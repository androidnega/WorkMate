#!/bin/bash

# Firebase Security Rules Test Script for WorkMate GH
echo "🔐 Firebase Security Rules Testing Suite"
echo "========================================"

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Please install it first:"
    echo "   npm install -g firebase-tools"
    exit 1
fi

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please ensure Flutter is installed and in PATH."
    exit 1
fi

echo "✅ Prerequisites check passed"
echo ""

# Start Firebase Emulators
echo "🚀 Starting Firebase Emulators..."
firebase emulators:start --only auth,firestore &
EMULATOR_PID=$!

# Wait for emulators to start
echo "⏳ Waiting for emulators to initialize..."
sleep 10

# Check if emulators are running
if ! curl -s http://127.0.0.1:4000 > /dev/null; then
    echo "❌ Firebase Emulator UI not accessible. Please check emulator status."
    kill $EMULATOR_PID 2>/dev/null
    exit 1
fi

echo "✅ Firebase Emulators are running"
echo "   - Firestore: http://127.0.0.1:8080"
echo "   - Auth: http://127.0.0.1:9099"
echo "   - UI: http://127.0.0.1:4000"
echo ""

# Run security tests
echo "🔐 Running Security Rules Tests..."
echo "=================================="

# Create a temporary test file
cat > test_security_rules.dart << 'EOF'
import 'dart:io';
import 'package:flutter/services.dart';
import 'lib/test/emulator_test_runner.dart';

void main() async {
  try {
    await EmulatorTestRunner.runSecurityTests();
    exit(0);
  } catch (e) {
    print('Test execution failed: $e');
    exit(1);
  }
}
EOF

# Run the security tests
flutter test test_security_rules.dart

# Capture test result
TEST_RESULT=$?

# Cleanup
rm -f test_security_rules.dart

# Stop emulators
echo ""
echo "🛑 Stopping Firebase Emulators..."
kill $EMULATOR_PID 2>/dev/null
wait $EMULATOR_PID 2>/dev/null

# Print final result
echo ""
if [ $TEST_RESULT -eq 0 ]; then
    echo "✅ All Security Rules Tests Passed!"
else
    echo "❌ Some Security Rules Tests Failed!"
fi

echo "========================================"
echo "Security Rules Testing Complete"

exit $TEST_RESULT
