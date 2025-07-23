#!/bin/bash
# scripts/test-analytics.sh
# ===================
# Test Analytics Service Functionality
# ===================

echo "🧪 Testing ShopSphere Analytics Service"
echo "======================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

ANALYTICS_URL="http://localhost:8002"
BACKEND_URL="http://localhost:8001"

# Function to test endpoint
test_endpoint() {
    local name="$1"
    local url="$2"
    local expected_field="$3"
    
    echo -n "Testing $name... "
    response=$(curl -s "$url" 2>/dev/null)
    
    if [ $? -eq 0 ] && echo "$response" | jq . > /dev/null 2>&1; then
        if [ -n "$expected_field" ]; then
            if echo "$response" | jq -e ".$expected_field" > /dev/null 2>&1; then
                echo -e "${GREEN}✅ PASS${NC}"
                return 0
            else
                echo -e "${YELLOW}⚠️  PARTIAL (missing $expected_field)${NC}"
                return 1
            fi
        else
            echo -e "${GREEN}✅ PASS${NC}"
            return 0
        fi
    else
        echo -e "${RED}❌ FAIL${NC}"
        return 1
    fi
}

# Function to send test event
send_test_event() {
    local topic="$1"
    local event="$2"
    
    echo "📤 Sending test event to $topic..."
    echo "$event" | docker exec -i shopsphere_kafka kafka-console-producer \
        --bootstrap-server localhost:9092 \
        --topic "$topic" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "   ${GREEN}✅ Event sent successfully${NC}"
        return 0
    else
        echo -e "   ${RED}❌ Failed to send event${NC}"
        return 1
    fi
}

echo ""
echo "🔍 Step 1: Basic Health Checks"
echo "------------------------------"

test_endpoint "Analytics Health" "$ANALYTICS_URL/health" "status"
test_endpoint "Analytics Root" "$ANALYTICS_URL/" "service"

echo ""
echo "🔄 Step 2: Initial Metrics Check"
echo "--------------------------------"

test_endpoint "All Metrics" "$ANALYTICS_URL/metrics" "timestamp"
test_endpoint "Order Metrics" "$ANALYTICS_URL/metrics/orders" "orders_total"
test_endpoint "Revenue Metrics" "$ANALYTICS_URL/metrics/revenue" "revenue_total"
test_endpoint "User Metrics" "$ANALYTICS_URL/metrics/users" "users_total"
test_endpoint "Popular Products" "$ANALYTICS_URL/metrics/products/popular" "popular_products"
test_endpoint "Real-time Metrics" "$ANALYTICS_URL/metrics/real-time" "current_time"

echo ""
echo "📨 Step 3: Test Event Processing"
echo "--------------------------------"

# Test Order Event
echo "Testing order event processing..."
order_event='{
    "event": "order_created",
    "order_id": "test_001",
    "user_id": "user_123",
    "total": 99.99,
    "items_count": 2,
    "status": "paid",
    "items": [
        {"product_id": 1, "product_name": "Test Product", "quantity": 1, "price": 49.99},
        {"product_id": 2, "product_name": "Another Product", "quantity": 1, "price": 50.00}
    ],
    "timestamp": "'$(date -Iseconds)'"
}'

send_test_event "orders" "$order_event"

# Test User Event
echo "Testing user event processing..."
user_event='{
    "event": "user_registered",
    "user_id": "user_456",
    "email": "test@example.com",
    "timestamp": "'$(date -Iseconds)'"
}'

send_test_event "users" "$user_event"

# Test Cart Event
echo "Testing cart event processing..."
cart_event='{
    "event": "item_added_to_cart",
    "user_id": "user_123",
    "product_id": "1",
    "product_name": "Test Product",
    "quantity": 1,
    "timestamp": "'$(date -Iseconds)'"
}'

send_test_event "users" "$cart_event"

echo ""
echo "⏳ Step 4: Wait for Event Processing"
echo "-----------------------------------"
echo "Waiting 10 seconds for events to be processed..."
sleep 10

echo ""
echo "📊 Step 5: Verify Updated Metrics"
echo "---------------------------------"

echo "Checking if metrics were updated..."

# Get metrics and check for updates
echo ""
echo "📈 Current Metrics:"
echo "==================="

# Order metrics
order_response=$(curl -s "$ANALYTICS_URL/metrics/orders")
if [ $? -eq 0 ]; then
    orders_total=$(echo "$order_response" | jq -r '.orders_total // 0')
    orders_today=$(echo "$order_response" | jq -r '.orders_today // 0')
    echo "Orders Total: $orders_total"
    echo "Orders Today: $orders_today"
else
    echo -e "${RED}Failed to get order metrics${NC}"
fi

# Revenue metrics
revenue_response=$(curl -s "$ANALYTICS_URL/metrics/revenue")
if [ $? -eq 0 ]; then
    revenue_total=$(echo "$revenue_response" | jq -r '.revenue_total // 0')
    revenue_today=$(echo "$revenue_response" | jq -r '.revenue_today // 0')
    avg_order=$(echo "$revenue_response" | jq -r '.average_order_value // 0')
    echo "Revenue Total: \$revenue_total"
    echo "Revenue Today: \$revenue_today"
    echo "Avg Order Value: \$avg_order"
else
    echo -e "${RED}Failed to get revenue metrics${NC}"
fi

# User metrics
user_response=$(curl -s "$ANALYTICS_URL/metrics/users")
if [ $? -eq 0 ]; then
    users_total=$(echo "$user_response" | jq -r '.users_total // 0')
    echo "Users Total: $users_total"
    
    # Cart activity
    cart_activity=$(echo "$user_response" | jq -r '.cart_activity // {}')
    if [ "$cart_activity" != "{}" ]; then
        echo "Cart Activity:"
        echo "$cart_activity" | jq .
    fi
else
    echo -e "${RED}Failed to get user metrics${NC}"
fi

# Popular products
products_response=$(curl -s "$ANALYTICS_URL/metrics/products/popular")
if [ $? -eq 0 ]; then
    echo "Popular Products:"
    echo "$products_response" | jq -r '.popular_products[] | "  Product \(.product_id): \(.quantity_sold) sold"' 2>/dev/null || echo "  No products found"
else
    echo -e "${RED}Failed to get product metrics${NC}"
fi

echo ""
echo "🔄 Step 6: Real-time Dashboard Test"
echo "-----------------------------------"

real_time_response=$(curl -s "$ANALYTICS_URL/metrics/real-time")
if [ $? -eq 0 ]; then
    echo "Real-time Dashboard Data:"
    echo "$real_time_response" | jq .
else
    echo -e "${RED}Failed to get real-time metrics${NC}"
fi

echo ""
echo "🧹 Step 7: Performance Test"
echo "---------------------------"

echo "Testing response times..."

# Time multiple requests
for i in {1..5}; do
    start_time=$(date +%s.%3N)
    curl -s "$ANALYTICS_URL/metrics" > /dev/null
    end_time=$(date +%s.%3N)
    response_time=$(echo "$end_time - $start_time" | bc -l)
    echo "Request $i: ${response_time}s"
done

echo ""
echo "🔍 Step 8: Kafka Consumer Status"
echo "--------------------------------"

# Check Kafka consumer group
echo "Checking Kafka consumer group status..."
consumer_info=$(docker exec shopsphere_kafka kafka-consumer-groups \
    --bootstrap-server localhost:9092 \
    --describe \
    --group analytics-service 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$consumer_info" ]; then
    echo "Consumer Group: analytics-service"
    echo "$consumer_info"
else
    echo -e "${YELLOW}Consumer group not found or not active${NC}"
fi

echo ""
echo "🧪 Step 9: Integration Test"
echo "---------------------------"

echo "Running end-to-end integration test..."

# Create a realistic test scenario
echo "1. Creating multiple test events..."

# Multiple orders
for i in {1..3}; do
    order_event='{
        "event": "order_created",
        "order_id": "test_'$i'",
        "user_id": "user_'$i'",
        "total": '$((50 + i * 25))',
        "items_count": '$i',
        "status": "paid",
        "items": [{"product_id": '$i', "product_name": "Product '$i'", "quantity": '$i', "price": '$((50 + i * 25))'}],
        "timestamp": "'$(date -Iseconds)'"
    }'
    send_test_event "orders" "$order_event"
done

# Multiple users
for i in {1..2}; do
    user_event='{
        "event": "user_registered",
        "user_id": "integration_user_'$i'",
        "email": "user'$i'@test.com",
        "timestamp": "'$(date -Iseconds)'"
    }'
    send_test_event "users" "$user_event"
done

echo "2. Waiting for processing..."
sleep 5

echo "3. Verifying final state..."
final_metrics=$(curl -s "$ANALYTICS_URL/metrics")
if [ $? -eq 0 ]; then
    echo "Final Analytics Summary:"
    echo "$final_metrics" | jq '{
        orders: .orders,
        revenue: .revenue,
        users: .users,
        timestamp: .timestamp
    }'
else
    echo -e "${RED}Failed to get final metrics${NC}"
fi

echo ""
echo "🎯 Test Summary"
echo "==============="

# Check if analytics is working properly
total_orders=$(echo "$final_metrics" | jq -r '.orders.total // 0' 2>/dev/null)
total_revenue=$(echo "$final_metrics" | jq -r '.revenue.total // 0' 2>/dev/null)

if [ "$total_orders" -gt 0 ] && [ "$(echo "$total_revenue > 0" | bc -l)" -eq 1 ]; then
    echo -e "${GREEN}🎉 Analytics Service is working correctly!${NC}"
    echo "✅ Events are being consumed and processed"
    echo "✅ Metrics are being calculated and stored"
    echo "✅ API endpoints are responding correctly"
else
    echo -e "${YELLOW}⚠️  Analytics Service needs attention${NC}"
    echo "❓ Check if events are being processed correctly"
fi

echo ""
echo "📊 Live Monitoring Commands:"
echo "============================"
echo "Watch analytics logs:"
echo "  docker-compose -f docker-compose.enhanced.yml logs -f analytics"
echo ""
echo "Monitor Kafka messages:"
echo "  docker exec -it shopsphere_kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic orders"
echo ""
echo "Check analytics dashboard:"
echo "  curl http://localhost:8002/metrics | jq ."
echo ""

echo -e "${BLUE}🧪 Analytics testing complete!${NC}"