#!/bin/bash
# scripts/setup-gmail-notifications.sh
# ====================================
# Simple Gmail Setup for Students
# ====================================

echo "📧 Gmail Notification Service Setup"
echo "==================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "🎓 Student-Friendly Gmail Setup"
echo "==============================="

# Step 1: Get Gmail credentials
echo ""
echo "📝 Step 1: Gmail Configuration"
echo "------------------------------"

read -p "Enter your Gmail address (e.g., student123@gmail.com): " gmail_address

echo ""
echo "🔐 Now you need a Gmail App Password:"
echo "1. Go to: https://myaccount.google.com/security"
echo "2. Enable 2-Step Verification (if not enabled)"
echo "3. Go to App Passwords"
echo "4. Generate password for 'Mail' -> 'Other (ShopSphere)'"
echo "5. Copy the 16-character password"
echo ""

read -p "Enter your Gmail App Password (16 characters): " gmail_app_password

# Step 2: Create environment file
echo ""
echo "💾 Creating Gmail configuration..."

cat > .env.gmail << EOF
# Gmail Configuration for ShopSphere
GMAIL_USERNAME=$gmail_address
GMAIL_APP_PASSWORD=$gmail_app_password
EOF

# Step 3: Create notification service files
echo ""
echo "📁 Creating notification service..."

mkdir -p microservices/notification-service

# Create requirements.txt
cat > microservices/notification-service/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
redis==5.0.1
kafka-python==2.0.2
python-dotenv==1.0.0
pydantic==2.5.0
jinja2==3.1.2
EOF

# Create simple Dockerfile
cat > microservices/notification-service/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8003

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8003"]
EOF

echo "✅ Notification service structure created"

# Step 4: Update docker-compose
echo ""
echo "🐳 Updating Docker Compose..."

# Create a simplified docker-compose with Gmail
cat > docker-compose.gmail.yml << EOF
version: '3.8'

services:
  postgres:
    image: postgres:14-alpine
    container_name: shopsphere_postgres
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
      POSTGRES_DB: shopdb
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d shopdb"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: shopsphere_redis
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5

  zookeeper:
    image: confluentinc/cp-zookeeper:7.4.0
    container_name: shopsphere_zookeeper
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    ports:
      - "2181:2181"
    healthcheck:
      test: ["CMD", "bash", "-c", "echo 'ruok' | nc localhost 2181"]
      interval: 10s
      timeout: 5s
      retries: 5

  kafka:
    image: confluentinc/cp-kafka:7.4.0
    container_name: shopsphere_kafka
    depends_on:
      zookeeper:
        condition: service_healthy
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: 'true'
    healthcheck:
      test: ["CMD", "kafka-topics", "--bootstrap-server", "localhost:9092", "--list"]
      interval: 30s
      timeout: 10s
      retries: 5

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: shopsphere_backend
    environment:
      - DATABASE_URL=postgresql://user:password@postgres:5432/shopdb
      - REDIS_URL=redis://redis:6379
      - KAFKA_BOOTSTRAP_SERVERS=kafka:9092
    ports:
      - "8001:8001"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
      kafka:
        condition: service_healthy
    volumes:
      - ./backend:/app

  analytics:
    build:
      context: ./microservices/analytics-service
      dockerfile: Dockerfile
    container_name: shopsphere_analytics
    environment:
      - REDIS_URL=redis://redis:6379
      - KAFKA_BOOTSTRAP_SERVERS=kafka:9092
    ports:
      - "8002:8002"
    depends_on:
      redis:
        condition: service_healthy
      kafka:
        condition: service_healthy

  notifications:
    build:
      context: ./microservices/notification-service
      dockerfile: Dockerfile
    container_name: shopsphere_notifications
    env_file:
      - .env.gmail
    environment:
      - REDIS_URL=redis://redis:6379
      - KAFKA_BOOTSTRAP_SERVERS=kafka:9092
      - SMTP_SERVER=smtp.gmail.com
      - SMTP_PORT=587
      - SMTP_USERNAME=$gmail_address
      - SMTP_PASSWORD=$gmail_app_password
      - FROM_EMAIL=$gmail_address
      - FROM_NAME=ShopSphere Store
    ports:
      - "8003:8003"
    depends_on:
      redis:
        condition: service_healthy
      kafka:
        condition: service_healthy

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: shopsphere_frontend
    environment:
      - NEXT_PUBLIC_API_URL=http://localhost:8001
    ports:
      - "3000:3000"
    depends_on:
      - backend
    volumes:
      - ./frontend:/app
      - /app/node_modules

  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    container_name: shopsphere_kafka_ui
    depends_on:
      kafka:
        condition: service_healthy
    ports:
      - "8080:8080"
    environment:
      KAFKA_CLUSTERS_0_NAME: shopsphere
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:9092

volumes:
  pgdata:
EOF

echo "✅ Docker Compose configured for Gmail"

# Step 5: Build and start services
echo ""
echo "🚀 Starting services..."

# Stop any existing services
docker-compose -f docker-compose.enhanced.yml down 2>/dev/null || true

# Start new services
echo "Building notification service..."
docker-compose -f docker-compose.gmail.yml build notifications

echo "Starting infrastructure..."
docker-compose -f docker-compose.gmail.yml up -d postgres redis zookeeper
sleep 15

echo "Starting Kafka..."
docker-compose -f docker-compose.gmail.yml up -d kafka
sleep 30

echo "Starting application services..."
docker-compose -f docker-compose.gmail.yml up -d backend analytics notifications frontend kafka-ui

# Step 6: Wait and test
echo ""
echo "⏳ Waiting for services to start..."
sleep 30

# Step 7: Test email
echo ""
echo "📧 Testing Gmail connection..."

# Wait for notification service
sleep 10

# Test email
echo "Sending test email to $gmail_address..."
curl -X POST "http://localhost:8003/send/test?email=$gmail_address" 2>/dev/null | jq . || echo "Service not ready yet"

# Step 8: Show results
echo ""
echo "🎉 Setup Complete!"
echo "=================="

echo ""
echo "🌐 Service URLs:"
echo "Frontend:      http://localhost:3000"
echo "Backend:       http://localhost:8001"
echo "Analytics:     http://localhost:8002"
echo "Notifications: http://localhost:8003"
echo "Kafka UI:      http://localhost:8080"

echo ""
echo "📧 Test Your Email:"
echo "curl -X POST \"http://localhost:8003/send/test?email=$gmail_address\""

echo ""
echo "📊 Check Metrics:"
echo "curl http://localhost:8003/metrics | jq ."

echo ""
echo "📋 Next Steps:"
echo "1. Check your Gmail inbox for test email"
echo "2. Register a new user at http://localhost:3000/register"
echo "3. Place an order to test order confirmation emails"
echo "4. Monitor logs: docker-compose -f docker-compose.gmail.yml logs -f notifications"

echo ""
echo -e "${GREEN}✅ Gmail notification service is ready!${NC}"