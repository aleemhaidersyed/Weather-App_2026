#!/bin/bash

# DevOps Weather App Integration Test Script
# Ensures that database creation, API retrieval, and caching work as designed.

echo "=== Starting Integration Tests ==="

# 1. Ensure Backend is running. Let's send a ping to port 5000.
curl -s http://localhost:5000/api/weather?city=test > /dev/null
if [ $? -ne 0 ]; then
  echo "❌ Error: Flask Backend is not running on port 5000!"
  echo "Please start the backend (python app.py) before running tests."
  exit 1
fi

# 2. Reset the cache database to guarantee a clean starting state
echo "🧹 Cleaning previous cache database..."
rm -f backend/weather.db

# 3. Test 1: First request (Should bypass cache and query API)
echo "📥 Sending Test 1 (Cache Miss)..."
RESP1=$(curl -s "http://localhost:5000/api/weather?city=Rome")
echo "Response 1: $RESP1"

# Check if response came from an API call
if echo "$RESP1" | grep -q -E '"source":"api_mocked"|"source":"external_api"'; then
  echo "✅ Test 1 Passed: Request bypassed cache correctly."
else
  echo "❌ Test 1 Failed: Response did not bypass cache or fetch from API."
  exit 1
fi

# 4. Test 2: Second request (Should load instantly from SQLite cache)
echo "⚡ Sending Test 2 (Cache Hit)..."
RESP2=$(curl -s "http://localhost:5000/api/weather?city=Rome")
echo "Response 2: $RESP2"

# Check if response came from SQLite cache
if echo "$RESP2" | grep -q '"source":"cache"'; then
  echo "✅ Test 2 Passed: Request pulled from cache correctly."
else
  echo "❌ Test 2 Failed: Response did not hit cache."
  exit 1
fi

echo "=== 🎉 ALL INTEGRATION TESTS PASSED! ==="
exit 0