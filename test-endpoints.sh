#!/bin/bash
BASE_URL="http://localhost:8001"

echo "Testing API endpoints..."
echo "1. Health check:"
curl -s "$BASE_URL/health" | jq '.'

echo -e "\n2. Products:"
curl -s "$BASE_URL/products" | jq '.'

echo -e "\n3. CORS check:"
curl -I -X OPTIONS "$BASE_URL/products" \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: GET"
