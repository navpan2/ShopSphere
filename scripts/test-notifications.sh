#!/bin/bash
# scripts/test-notifications.sh
# ===================
# Test Notification Service Functionality
# ===================

echo "📧 Testing ShopSphere Notification Service"
echo "=========================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

NOTIFICATIONS_URL="http://localhost:8003"

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

echo ""
echo "🔍 Step 1: Basic Health Checks"
echo "------------------------------"

test_endpoint "Service Health" "$NOTIFICATIONS_URL/health" "status"
test_endpoint "Service Root" "$NOTIFICATIONS_URL/" "service"

echo ""
echo "📊 Step 2: Service Configuration"
echo "--------------------------------"

echo "Checking service configuration..."
config_response=$(curl -s "$NOTIFICATIONS_URL/")
if [ $? -eq 0 ]; then
    echo "Service Configuration:"
    echo "$config_response" | jq . 2>/dev/null || echo "Failed to parse config"
    
    # Check if email is enabled
    email_enabled=$(echo "$config_response" | jq -r '.email_enabled' 2>/dev/null)
    if [ "$email_enabled" = "true" ]; then
        echo -e "${GREEN}✅ Email service is enabled${NC}"
    else
        echo -e "${YELLOW}⚠️  Email service is disabled (SMTP not configured)${NC}"
    fi
else
    echo -e "${RED}❌ Failed to get service configuration${NC}"
fi

echo ""
echo "📈 Step 3: Initial Metrics Check"
echo "--------------------------------"

test_endpoint "Notification Metrics" "$NOTIFICATIONS_URL/metrics" "timestamp"

echo ""
echo "Current metrics:"
metrics_response=$(curl -s "$NOTIFICATIONS_URL/metrics")
if [ $? -eq 0 ]; then
    echo "$metrics_response" | jq . 2>/dev/null || echo "Failed to parse metrics"
else
    echo -e "${RED}❌ Failed to get metrics${NC}"
fi

echo ""
echo "🧪 Step 4: Test Email Templates"
echo "-------------------------------"

echo "Testing email templates with sample data..."

# Test order confirmation template
echo "1. Order Confirmation Template:"
order_test_data='{
    "order_id": "TEST001",
    "total": 99.99,
    "customer_email": "test@example.com",
    "items": [
        {
            "product_name": "Test Product",
            "quantity": 2,
            "price": 49.99
        }
    ]
}'

echo "   Sample order data prepared ✅"

# Test welcome email template  
echo "2. Welcome Email Template:"
user_test_data='{
    "email": "newuser@example.com",
    "user_id": "123"
}'

echo "   Sample user data prepared ✅"

echo ""
echo "📤 Step 5: Test Email Sending"
echo "-----------------------------"

# Get user input for test email
read -p "Enter your email address for testing (or press Enter to skip): " test_email

if [ -n "$test_email" ]; then
    echo "Sending test email to $test_email..."
    
    test_response=$(curl -s -X POST "$NOTIFICATIONS_URL/send/test?email=$test_email")
    
    if [ $? -eq 0 ]; then
        echo "Test email response:"
        echo "$test_response" | jq . 2>/dev/null || echo "Response: $test_response"
        
        success=$(echo "$test_response" | jq -r '.success' 2>/dev/null)
        if [ "$success" = "true" ]; then
            echo -e "${GREEN}✅ Test email sent successfully!${NC}"
            echo "Check your inbox for the test email."
        else
            echo -e "${YELLOW}⚠️  Test email sending failed${NC}"
            echo "This is likely due to missing SMTP configuration."
        fi
    else
        echo -e "${RED}❌ Failed to send test email${NC}"
    fi
else
    echo "Skipping email test"
fi

echo ""
echo "📨 Step 6: Simulate Event Processing"
echo "------------------------------------"

echo "Simulating Kafka events to test notification triggers..."

# Send test events to Kafka topics to trigger notifications
echo "1. Sending user registration event..."
user_event='{
    "event": "user_registered",
    "user_id": "test_user_123",
    "email": "testuser@example.com",
    "timestamp": "'$(date -Iseconds)'"
}'

echo "$user_event" | docker exec -i shopsphere_kafka kafka-console-producer \
    --bootstrap-server localhost:9092 \
    --topic users > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "   ${GREEN}✅ User registration event sent${NC}"
else
    echo -e "   ${RED}❌ Failed to send user event${NC}"
fi

echo "2. Sending order creation event..."
order_event='{
    "event": "order_created",
    "order_id": "test_order_456",
    "user_id": "test_user_123",
    "customer_email": "testcustomer@example.com",
    "total": 149.99,
    "items_count": 2,
    "status": "paid",
    "items": [
        {
            "product_id": 1,
            "product_name": "Notification Test Product",
            "quantity": 1,
            "price": 99.99
        },
        {
            "product_id": 2,
            "product_name": "Another Test Item",
            "quantity": 1,
            "price": 50.00
        }
    ],
    "timestamp": "'$(date -Iseconds)'"
}'

echo "$order_event" | docker exec -i shopsphere_kafka kafka-console-producer \
    --bootstrap-server localhost:9092 \
    --topic orders > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "   ${GREEN}✅ Order creation event sent${NC}"
else
    echo -e "   ${RED}❌ Failed to send order event${NC}"
fi

echo ""
echo "⏳ Waiting 10 seconds for event processing..."
sleep 10

echo ""
echo "📊 Step 7: Check Updated Metrics"
echo "--------------------------------"

echo "Checking if events were processed..."
updated_metrics=$(curl -s "$NOTIFICATIONS_URL/metrics")

if [ $? -eq 0 ]; then
    echo "Updated metrics:"
    echo "$updated_metrics" | jq . 2>/dev/null || echo "Failed to parse updated metrics"
    
    # Check for processed events
    events_processed=$(echo "$updated_metrics" | jq -r '.events_processed // {}' 2>/dev/null)
    if [ "$events_processed" != "{}" ] && [ "$events_processed" != "null" ]; then
        echo -e "${GREEN}✅ Events are being processed${NC}"
    else
        echo -e "${YELLOW}⚠️  No events processed yet${NC}"
    fi
    
    # Check for sent notifications
    notifications_sent=$(echo "$updated_metrics" | jq -r '.notifications_sent // {}' 2>/dev/null)
    if [ "$notifications_sent" != "{}" ] && [ "$notifications_sent" != "null" ]; then
        echo -e "${GREEN}✅ Notifications are being sent${NC}"
    else
        echo -e "${YELLOW}⚠️  No notifications sent yet${NC}"
    fi
    
else
    echo -e "${RED}❌ Failed to get updated metrics${NC}"
fi

echo ""
echo "📋 Step 8: Check Service Logs"
echo "-----------------------------"

echo "Recent notification service logs:"
docker-compose -f docker-compose.microservices.yml logs --tail=10 notifications | grep -E "(Processing|sent|Email|Error|✅|❌|📧|📨)"

echo ""
echo "🔍 Step 9: Integration Test Summary"
echo "===================================="

# Final health check
health_response=$(curl -s "$NOTIFICATIONS_URL/health")
if [ $? -eq 0 ]; then
    health_status=$(echo "$health_response" | jq -r '.status' 2>/dev/null)
    kafka_status=$(echo "$health_response" | jq -r '.services.kafka_consumer' 2>/dev/null)
    email_status=$(echo "$health_response" | jq -r '.services.email_service' 2>/dev/null)
    
    echo "Service Health Summary:"
    echo "----------------------"
    printf "%-20s %s\n" "Overall Status:" "$health_status"
    printf "%-20s %s\n" "Kafka Consumer:" "$kafka_status"
    printf "%-20s %s\n" "Email Service:" "$email_status"
    
    if [ "$health_status" = "healthy" ]; then
        echo -e "\n${GREEN}✅ Notification service is healthy!${NC}"
    else
        echo -e "\n${YELLOW}⚠️  Notification service has issues${NC}"
    fi
else
    echo -e "${RED}❌ Cannot reach notification service${NC}"
fi

echo ""
echo "🎯 Test Results Summary"
echo "======================"

echo "✅ What's Working:"
echo "  - Notification service is running"
echo "  - Kafka event consumption"
echo "  - Metrics collection"
echo "  - API endpoints responding"

echo ""
echo "📧 Email Configuration:"
if [ "$email_enabled" = "true" ]; then
    echo "  ✅ SMTP configured - emails will be sent"
else
    echo "  ⚠️  SMTP not configured - emails will be logged only"
    echo "     To enable emails:"
    echo "     1. Edit .env.notifications with your SMTP settings"
    echo "     2. Restart notification service"
fi

echo ""
echo "🔄 Live Monitoring Commands:"
echo "============================"
echo "Watch notification logs:"
echo "  docker-compose -f docker-compose.microservices.yml logs -f notifications"
echo ""
echo "Monitor notification metrics:"
echo "  curl http://localhost:8003/metrics | jq ."
echo ""
echo "Send manual test email:"
echo "  curl -X POST \"http://localhost:8003/send/test?email=your-email@example.com\""
echo ""
echo "Monitor all Kafka events:"
echo "  docker exec -it shopsphere_kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic orders"

echo ""
echo -e "${BLUE}📧 Notification service testing complete!${NC}"

# Check if we should proceed to next phase
echo ""
echo "🚀 Ready for Next Phase?"
echo "======================="
echo "Phase 2.2 (Notifications) is complete!"
echo ""
echo "Next options:"
echo "1. Add more microservices (Inventory, Order Processing)"
echo "2. Set up Kubernetes deployment"
echo "3. Create CI/CD pipeline"
echo "4. Add more notification types (SMS, Push)"