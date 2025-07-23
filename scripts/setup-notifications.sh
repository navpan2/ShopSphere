#!/bin/bash
# scripts/setup-notifications.sh
# ===================
# Setup Notification Service
# ===================

set -e

echo "📧 ShopSphere Notification Service Setup"
echo "========================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Create notification service directory
print_status "Creating notification service directory..."
mkdir -p microservices/notification-service
print_success "Directory created"

# Step 2: Check if files exist
print_status "Checking notification service files..."
if [ ! -f "microservices/notification-service/main.py" ]; then
    print_error "main.py not found in microservices/notification-service/"
    echo "Please create the main.py file with the notification service code"
    exit 1
fi

if [ ! -f "microservices/notification-service/requirements.txt" ]; then
    print_error "requirements.txt not found in microservices/notification-service/"
    echo "Please create the requirements.txt file"
    exit 1
fi

if [ ! -f "microservices/notification-service/Dockerfile" ]; then
    print_error "Dockerfile not found in microservices/notification-service/"
    echo "Please create the Dockerfile"
    exit 1
fi

print_success "All required files found"

# Step 3: Environment setup
print_status "Setting up environment variables..."

# Create notification environment file
cat > .env.notifications << 'EOF'
# Notification Service Environment Variables
# ==========================================

# Email Configuration
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
FROM_EMAIL=noreply@shopsphere.com
FROM_NAME=ShopSphere

# Note: For Gmail, you need to:
# 1. Enable 2-Factor Authentication
# 2. Generate an "App Password" (not your regular password)
# 3. Use the app password as SMTP_PASSWORD
EOF

print_warning "Email configuration needed!"
echo ""
echo "📧 Email Setup Instructions:"
echo "============================="
echo "1. Edit .env.notifications file with your email settings"
echo "2. For Gmail:"
echo "   - Enable 2-Factor Authentication"
echo "   - Generate App Password: https://myaccount.google.com/apppasswords"
echo "   - Use app password (not regular password)"
echo "3. For other providers, update SMTP_SERVER and SMTP_PORT"
echo ""

# Step 4: Stop existing services
print_status "Stopping existing services..."
docker-compose -f docker-compose.enhanced.yml down 2>/dev/null || true
docker-compose -f docker-compose.microservices.yml down 2>/dev/null || true

# Step 5: Build notification service
print_status "Building notification service..."
docker-compose -f docker-compose.microservices.yml build notifications

# Step 6: Start all services
print_status "Starting all microservices..."
print_warning "This includes: Backend, Analytics, Notifications, and supporting services"

# Start core infrastructure first
print_status "Starting infrastructure (Postgres, Redis, Kafka)..."
docker-compose -f docker-compose.microservices.yml up -d postgres redis zookeeper
sleep 15

print_status "Starting Kafka..."
docker-compose -f docker-compose.microservices.yml up -d kafka
sleep 30

print_status "Starting application services..."
docker-compose -f docker-compose.microservices.yml up -d backend analytics notifications
sleep 20

print_status "Starting frontend and monitoring..."
docker-compose -f docker-compose.microservices.yml up -d frontend kafka-ui prometheus grafana

# Step 7: Wait for services
print_status "Waiting for services to be ready..."
sleep 30

# Step 8: Health checks
print_status "Running health checks..."

# Function to check service health
check_service() {
    local service_name="$1"
    local url="$2"
    local max_attempts=6
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$url" > /dev/null 2>&1; then
            print_success "$service_name is ready"
            return 0
        fi
        print_status "Waiting for $service_name... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    print_error "$service_name failed to start"
    return 1
}

# Check all services
check_service "Backend" "http://localhost:8001/health"
check_service "Analytics" "http://localhost:8002/health"
check_service "Notifications" "http://localhost:8003/health"
check_service "Frontend" "http://localhost:3000"

# Step 9: Run database migrations
print_status "Running database migrations..."
docker-compose -f docker-compose.microservices.yml exec -T backend alembic upgrade head || print_warning "Migration failed or already up to date"

# Step 10: Test notification service
print_status "Testing notification service..."

# Test basic connectivity
if curl -f -s http://localhost:8003/health > /dev/null; then
    print_success "Notification service is responding"
    
    # Get service status
    echo ""
    echo "📧 Notification Service Status:"
    echo "==============================="
    curl -s http://localhost:8003/ | jq . 2>/dev/null || echo "Service responding but JSON parse failed"
    
    echo ""
    echo "📊 Current Metrics:"
    echo "=================="
    curl -s http://localhost:8003/metrics | jq . 2>/dev/null || echo "Metrics not available yet"
    
else
    print_error "Notification service is not responding"
fi

# Step 11: Display service URLs
echo ""
echo "🌐 Service URLs"
echo "==============="
echo "Frontend:         http://localhost:3000"
echo "Backend API:      http://localhost:8001"
echo "Analytics API:    http://localhost:8002"
echo "Notifications:    http://localhost:8003"
echo "Kafka UI:         http://localhost:8080"
echo "Prometheus:       http://localhost:9090"
echo "Grafana:          http://localhost:3001 (admin/admin)"

# Step 12: Display container status
echo ""
echo "📦 Container Status"
echo "=================="
docker-compose -f docker-compose.microservices.yml ps

# Step 13: Instructions for testing
echo ""
echo "🧪 Testing Instructions"
echo "======================"
echo "1. Configure email settings in .env.notifications"
echo ""
echo "2. Test email functionality:"
echo "   curl -X POST \"http://localhost:8003/send/test?email=your-email@example.com\""
echo ""
echo "3. Register a new user to trigger welcome email:"
echo "   - Go to: http://localhost:3000/register"
echo "   - Create account with real email"
echo ""
echo "4. Place an order to trigger order confirmation:"
echo "   - Shop and checkout at: http://localhost:3000"
echo ""
echo "5. Monitor notification logs:"
echo "   docker-compose -f docker-compose.microservices.yml logs -f notifications"
echo ""
echo "6. Check notification metrics:"
echo "   curl http://localhost:8003/metrics"

# Step 14: Final status
echo ""
echo "🎯 Setup Summary"
echo "================"

# Count running containers
running_containers=$(docker-compose -f docker-compose.microservices.yml ps --services --filter "status=running" | wc -l)
total_containers=$(docker-compose -f docker-compose.microservices.yml ps --services | wc -l)

if [ "$running_containers" -eq "$total_containers" ]; then
    print_success "🎉 All services are running! ($running_containers/$total_containers)"
    echo ""
    echo "✅ Backend API ready"
    echo "✅ Analytics service processing events"  
    echo "✅ Notification service ready for emails"
    echo "✅ Frontend accessible"
    echo "✅ Monitoring dashboards available"
    echo ""
    print_success "Phase 2.2 (Notifications) Complete!"
    echo ""
    echo "🚀 Ready for Phase 3: Kubernetes or more microservices"
else
    print_warning "⚠️  Some services may not be running ($running_containers/$total_containers)"
    echo "Check logs: docker-compose -f docker-compose.microservices.yml logs"
fi

echo ""
echo "📧 Don't forget to configure email settings in .env.notifications!"
echo "=================================================================="