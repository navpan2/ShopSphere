#!/bin/bash
# Complete Notification Testing Commands
# ======================================

echo "📧 ShopSphere Notification Testing Guide"
echo "========================================"

# Test your email first
YOUR_EMAIL="navusa314@gmail.com"  # Replace with your actual email

echo ""
echo "🔍 Step 1: Check Notification Service Status"
echo "--------------------------------------------"

# Check if notification service is running
curl -s http://localhost:8003/health | jq .

echo ""
echo "📊 Step 2: Check Current Metrics"
echo "--------------------------------"

# Check current notification metrics
curl -s http://localhost:8003/metrics | jq .

echo ""
echo "🧪 Step 3: Send Test Email (Direct API)"
echo "---------------------------------------"

# Send test email using the API
echo "Sending test email to $YOUR_EMAIL..."
curl -X POST "http://localhost:8003/send/test?email=$YOUR_EMAIL" | jq .

echo ""
echo "⏳ Wait 10 seconds and check your email inbox!"
sleep 10

echo ""
echo "📨 Step 4: Test Welcome Email (Kafka Event)"
echo "-------------------------------------------"

# Simulate user registration event
echo "Simulating user registration..."
USER_EVENT='{
    "event": "user_registered",
    "user_id": "test_user_' $(date +%s) '",
    "email": "' $YOUR_EMAIL '",
    "timestamp": "' $(date -Iseconds) '"
}'

echo "$USER_EVENT" | docker exec -i shopsphere_kafka kafka-console-producer \
    --bootstrap-server localhost:9092 \
    --topic users

echo "✅ Welcome email event sent! Check your email in 30 seconds."

echo ""
echo "🛍️ Step 5: Test Order Confirmation (Kafka Event)"
echo "------------------------------------------------"

# Simulate order creation event
echo "Simulating order placement..."
ORDER_EVENT='{
    "event": "order_created",
    "order_id": "TEST_' $(date +%s) '",
    "user_id": "test_user_123",
    "customer_email": "' $YOUR_EMAIL '",
    "total": 159.99,
    "items_count": 2,
    "status": "paid",
    "items": [
        {
            "product_id": 1,
            "product_name": "Test iPhone 15 Pro",
            "quantity": 1,
            "price": 134.99
        },
        {
            "product_id": 2,
            "product_name": "Test Wireless Headphones",
            "quantity": 1,
            "price": 25.00
        }
    ],
    "timestamp": "' $(date -Iseconds) '"
}'

echo "$ORDER_EVENT" | docker exec -i shopsphere_kafka kafka-console-producer \
    --bootstrap-server localhost:9092 \
    --topic orders

echo "✅ Order confirmation event sent! Check your email in 30 seconds."

echo ""
echo "⚠️ Step 6: Test Low Stock Alert"
echo "------------------------------"

# Simulate low stock product update
echo "Simulating low stock alert..."
PRODUCT_EVENT='{
    "event": "product_updated",
    "product_id": "test_product_001",
    "name": "iPhone 15 Pro Max",
    "stock": 2,
    "old_stock": 10,
    "timestamp": "' $(date -Iseconds) '"
}'

echo "$PRODUCT_EVENT" | docker exec -i shopsphere_kafka kafka-console-producer \
    --bootstrap-server localhost:9092 \
    --topic products

echo "✅ Low stock alert sent to admin! (Check admin@shopsphere.com or configure admin email)"

echo ""
echo "⏳ Step 7: Wait and Check Results"
echo "--------------------------------"

echo "Waiting 30 seconds for all events to process..."
sleep 30

echo ""
echo "📊 Updated Metrics After Testing:"
curl -s http://localhost:8003/metrics | jq .

echo ""
echo "📋 Step 8: Check Notification Logs"
echo "----------------------------------"

echo "Recent notification service logs:"
docker logs shopsphere_notifications --tail=20 | grep -E "(Email|sent|Event|Processing|✅|❌)"

echo ""
echo "🎯 Step 9: Verification Checklist"
echo "================================="

echo "Check your email inbox for:"
echo "□ Test email (immediate)"
echo "□ Welcome email (from Step 4)"  
echo "□ Order confirmation (from Step 5)"
echo "□ Low stock alert (if admin email configured)"

echo ""
echo "📧 Email Template Examples You Should Receive:"
echo "=============================================="

echo ""
echo "1. 🧪 TEST EMAIL:"
echo "   Subject: [TEST] Order Confirmation #TEST001 - ShopSphere"
echo "   Content: Test order with sample products"

echo ""
echo "2. 🎊 WELCOME EMAIL:"
echo "   Subject: Welcome to ShopSphere! 🎊"
echo "   Content: Account created, features overview, CTA button"

echo ""
echo "3. 🎉 ORDER CONFIRMATION:"
echo "   Subject: Order Confirmation #TEST_[timestamp] - ShopSphere"
echo "   Content: Order summary, itemized list, total amount"

echo ""
echo "4. ⚠️ LOW STOCK ALERT:"
echo "   Subject: ⚠️ Low Stock Alert: iPhone 15 Pro Max"
echo "   Content: Product details, current stock (2 units)"

echo ""
echo "🔍 Step 10: Advanced Testing"
echo "==========================="

echo "Monitor live events:"
echo "docker exec -it shopsphere_kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic orders --from-beginning"

echo ""
echo "Check Redis storage:"
echo "docker exec -it shopsphere_redis redis-cli"
echo "# In Redis: KEYS notifications:*"

echo ""
echo "Real-time log monitoring:"
echo "docker logs -f shopsphere_notifications"

echo ""
echo "✅ Testing Complete! Check your email inbox for all notifications."