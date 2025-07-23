#!/bin/bash
# scripts/debug-kafka-analytics.sh
# ===================================
# Debug Kafka Topics and Analytics Consumer
# ===================================

echo "🔍 Debugging Kafka Topics and Analytics Consumer"
echo "================================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "📋 Step 1: List All Kafka Topics"
echo "--------------------------------"
echo "Available topics:"
docker exec shopsphere_kafka kafka-topics --bootstrap-server localhost:9092 --list

echo ""
echo "📊 Step 2: Check What Analytics is Listening To"
echo "----------------------------------------------"
echo "Analytics consumer is configured to listen to: orders, users, products, payments"

echo ""
echo "🔍 Step 3: Check Consumer Groups"
echo "-------------------------------"
echo "Consumer groups:"
docker exec shopsphere_kafka kafka-consumer-groups --bootstrap-server localhost:9092 --list

echo ""
echo "📈 Step 4: Check Analytics Consumer Group Status"
echo "-----------------------------------------------"
docker exec shopsphere_kafka kafka-consumer-groups \
    --bootstrap-server localhost:9092 \
    --describe \
    --group analytics-service 2>/dev/null || echo "No analytics-service consumer group found"

echo ""
echo "📨 Step 5: Check Recent Messages in Each Topic"
echo "---------------------------------------------"

# Check orders topic (most important)
echo -e "\n${BLUE}Messages in 'orders' topic:${NC}"
timeout 5 docker exec shopsphere_kafka kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic orders \
    --from-beginning \
    --timeout-ms 3000 2>/dev/null || echo "No messages or topic doesn't exist"

echo -e "\n${BLUE}Messages in 'users' topic:${NC}"
timeout 5 docker exec shopsphere_kafka kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic users \
    --from-beginning \
    --timeout-ms 3000 2>/dev/null || echo "No messages or topic doesn't exist"

echo -e "\n${BLUE}Messages in 'products' topic:${NC}"
timeout 5 docker exec shopsphere_kafka kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic products \
    --from-beginning \
    --timeout-ms 3000 2>/dev/null || echo "No messages or topic doesn't exist"

echo -e "\n${BLUE}Messages in 'payments' topic:${NC}"
timeout 5 docker exec shopsphere_kafka kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic payments \
    --from-beginning \
    --timeout-ms 3000 2>/dev/null || echo "No messages or topic doesn't exist"

echo ""
echo "🔍 Step 6: Check Analytics Service Logs"
echo "--------------------------------------"
echo "Last 20 lines of analytics logs:"
docker-compose -f docker-compose.enhanced.yml logs --tail=20 analytics

echo ""
echo "🧪 Step 7: Test Manual Event Publishing"
echo "--------------------------------------"
echo "Sending test order event to 'orders' topic..."

test_order='{
    "event": "order_created",
    "order_id": "debug_test_001",
    "user_id": "debug_user_123",
    "total": 99.99,
    "items_count": 1,
    "status": "paid",
    "items": [
        {"product_id": 1, "product_name": "Debug Product", "quantity": 1, "price": 99.99}
    ],
    "timestamp": "'$(date -Iseconds)'"
}'

echo "$test_order" | docker exec -i shopsphere_kafka kafka-console-producer \
    --bootstrap-server localhost:9092 \
    --topic orders

echo "✅ Test event sent"

echo ""
echo "⏳ Waiting 5 seconds for processing..."
sleep 5

echo ""
echo "📊 Step 8: Check Analytics Metrics After Test"
echo "---------------------------------------------"
echo "Current analytics metrics:"
curl -s http://localhost:8002/metrics 2>/dev/null | jq . || echo "Analytics service not responding"

echo ""
echo "🔍 Step 9: Check Analytics Logs After Test"
echo "-----------------------------------------"
echo "Recent analytics logs (looking for event processing):"
docker-compose -f docker-compose.enhanced.yml logs --tail=10 analytics | grep -E "(Received event|Processed order|Error|event)"

echo ""
echo "🔧 Step 10: Diagnosis"
echo "-------------------"

# Check if analytics container is running
if docker ps | grep shopsphere_analytics > /dev/null; then
    echo -e "${GREEN}✅ Analytics container is running${NC}"
else
    echo -e "${RED}❌ Analytics container is not running${NC}"
fi

# Check if analytics service is responding
if curl -f -s http://localhost:8002/health > /dev/null; then
    echo -e "${GREEN}✅ Analytics service is responding${NC}"
else
    echo -e "${RED}❌ Analytics service is not responding${NC}"
fi

# Check Redis connection
if docker exec shopsphere_redis redis-cli ping | grep PONG > /dev/null; then
    echo -e "${GREEN}✅ Redis is working${NC}"
else
    echo -e "${RED}❌ Redis is not working${NC}"
fi

echo ""
echo "💡 Potential Issues and Solutions:"
echo "================================="
echo "1. Topic Name Mismatch:"
echo "   - Your backend might be sending to different topic names"
echo "   - Check your backend event_producer.send_order_event() calls"
echo ""
echo "2. Consumer Group Issues:"
echo "   - Analytics consumer might not be connecting to Kafka"
echo "   - Check analytics logs for Kafka connection errors"
echo ""
echo "3. Event Format Issues:"
echo "   - Events might not be in expected JSON format"
echo "   - Check if events are being processed correctly"
echo ""
echo "4. Timing Issues:"
echo "   - Analytics might have started before Kafka was ready"
echo "   - Try restarting analytics service"

echo ""
echo "🔧 Quick Fixes to Try:"
echo "====================="
echo "1. Restart analytics service:"
echo "   docker-compose -f docker-compose.enhanced.yml restart analytics"
echo ""
echo "2. Check analytics logs in real-time:"
echo "   docker-compose -f docker-compose.enhanced.yml logs -f analytics"
echo ""
echo "3. Manually test analytics:"
echo "   curl http://localhost:8002/metrics"
echo ""
echo "4. Reset analytics metrics:"
echo "   curl -X POST http://localhost:8002/metrics/reset"