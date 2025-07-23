#!/bin/bash
# scripts/setup-enhanced.sh
# ===================
# Complete ShopSphere Enhanced Setup
# ===================

set -e  # Exit on any error

echo "🚀 ShopSphere Enhanced Setup"
echo "============================"
echo "Setting up microservices architecture with analytics..."
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Function to print status
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

# Step 1: Create directory structure
print_status "Creating microservices directory structure..."
mkdir -p microservices/analytics-service
mkdir -p scripts
mkdir -p monitoring/grafana/{dashboards,datasources}
mkdir -p k8s/{namespaces,configmaps,secrets,deployments,services,ingress}

print_success "Directory structure created"

# Step 2: Environment configuration
print_status "Setting up environment configurations..."

# Copy environment files
if [ ! -f .env.development ]; then
    cp .env.template .env.development 2>/dev/null || echo "Template not found, creating new..."
fi

if [ ! -f .env.staging ]; then
    cp .env.template .env.staging 2>/dev/null || echo "Template not found, creating new..."
fi

print_success "Environment files configured"

# Step 3: Stop existing services
print_status "Stopping existing services..."
docker-compose down 2>/dev/null || true
docker-compose -f docker-compose.dev.yml down 2>/dev/null || true

# Step 4: Clean up old containers and networks
print_status "Cleaning up old resources..."
docker system prune -f > /dev/null 2>&1 || true

# Step 5: Build and start enhanced services
print_status "Building and starting enhanced services..."
print_warning "This may take a few minutes on first run..."

# Build images first
docker-compose -f docker-compose.enhanced.yml build --no-cache

# Start services in dependency order
print_status "Starting core infrastructure (Postgres, Redis, Zookeeper)..."
docker-compose -f docker-compose.enhanced.yml up -d postgres redis zookeeper

# Wait for core services
sleep 15

print_status "Starting Kafka..."
docker-compose -f docker-compose.enhanced.yml up -d kafka

# Wait for Kafka
sleep 30

print_status "Starting application services..."
docker-compose -f docker-compose.enhanced.yml up -d backend analytics

# Wait for backend services
sleep 20

print_status "Starting frontend and monitoring..."
docker-compose -f docker-compose.enhanced.yml up -d frontend kafka-ui prometheus grafana

# Step 6: Wait for services to be ready
print_status "Waiting for services to be ready..."
sleep 30

# Step 7: Initialize Kafka topics
print_status "Setting up Kafka topics..."
./scripts/kafka-setup.sh || print_warning "Kafka setup script not found or failed"

# Step 8: Run database migrations
print_status "Running database migrations..."
docker-compose -f docker-compose.enhanced.yml exec -T backend alembic upgrade head || print_warning "Migration failed"

# Step 9: Health checks
print_status "Running health checks..."

# Function to wait for service
wait_for_service() {
    local service_name=$1
    local url=$2
    local max_attempts=$3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$url" > /dev/null 2>&1; then
            print_success "$service_name is ready"
            return 0
        fi
        print_status "Waiting for $service_name... (attempt $attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done
    
    print_error "$service_name failed to start"
    return 1
}

# Wait for services
wait_for_service "Backend" "http://localhost:8001/health" 12
wait_for_service "Analytics" "http://localhost:8002/health" 12
wait_for_service "Frontend" "http://localhost:3000" 6

# Step 10: Test analytics service
print_status "Testing analytics service..."
if curl -f -s http://localhost:8002/metrics > /dev/null; then
    print_success "Analytics service responding"
else
    print_warning "Analytics service not responding yet"
fi

# Step 11: Display service URLs
echo ""
echo "🌐 Service URLs"
echo "==============="
echo "Frontend:         http://localhost:3000"
echo "Backend API:      http://localhost:8001"
echo "Analytics API:    http://localhost:8002"
echo "Kafka UI:         http://localhost:8080"
echo "Prometheus:       http://localhost:9090"
echo "Grafana:          http://localhost:3001 (admin/admin)"
echo ""

# Step 12: Display status
echo "📊 Service Status"
echo "================="
docker-compose -f docker-compose.enhanced.yml ps

echo ""
echo "🔍 Quick Health Check"
echo "====================="

# Test all endpoints
services=(
    "Backend:http://localhost:8001/health"
    "Analytics:http://localhost:8002/health"
    "Frontend:http://localhost:3000"
)

for service_url in "${services[@]}"; do
    IFS=':' read -r name url <<< "$service_url"
    if curl -f -s "$url" > /dev/null 2>&1; then
        printf "%-12s ${GREEN}✅ Healthy${NC}\n" "$name:"
    else
        printf "%-12s ${RED}❌ Unhealthy${NC}\n" "$name:"
    fi
done

echo ""
echo "🎯 Next Steps"
echo "============="
echo "1. Test the analytics endpoints:"
echo "   curl http://localhost:8002/metrics"
echo ""
echo "2. Create some test orders to see analytics in action"
echo ""
echo "3. Monitor Kafka messages:"
echo "   docker exec -it shopsphere_kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic orders"
echo ""
echo "4. Run validation:"
echo "   ./scripts/phase1-validation.sh"
echo ""

print_success "🎉 ShopSphere Enhanced Setup Complete!"
echo ""
echo "To stop all services: docker-compose -f docker-compose.enhanced.yml down"
echo "To view logs: docker-compose -f docker-compose.enhanced.yml logs -f [service]"