#!/bin/bash
# scripts/monitor-resources.sh
# ===================
# Enhanced Resource Monitoring for ShopSphere
# ===================

echo "🔍 ShopSphere Resource Monitoring Dashboard"
echo "==========================================="
echo "Timestamp: $(date)"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to get container status
get_container_status() {
    local container=$1
    if docker ps --format "table {{.Names}}" | grep -q "$container"; then
        echo -e "${GREEN}Running${NC}"
    else
        echo -e "${RED}Stopped${NC}"
    fi
}

echo "📦 Container Status"
echo "------------------"
printf "%-20s %-10s\n" "Service" "Status"
printf "%-20s %-10s\n" "-------" "------"
printf "%-20s " "PostgreSQL"; get_container_status "shopsphere_postgres"
printf "%-20s " "Redis"; get_container_status "shopsphere_redis"
printf "%-20s " "Kafka"; get_container_status "shopsphere_kafka"
printf "%-20s " "Zookeeper"; get_container_status "shopsphere_zookeeper"
printf "%-20s " "Backend"; get_container_status "shopsphere_backend"
printf "%-20s " "Frontend"; get_container_status "shopsphere_frontend"

echo ""
echo "📊 Resource Usage (Real-time)"
echo "----------------------------"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" | head -7

echo ""
echo "💾 Disk Usage"
echo "------------"
echo "Docker volumes:"
docker system df

echo ""
echo "Host disk usage:"
df -h | grep -E "(Filesystem|/var/lib/docker|/$)"

echo ""
echo "🌐 Network & Ports"
echo "-----------------"
echo "Active ShopSphere ports:"
netstat -tlnp 2>/dev/null | grep -E "(3000|8001|5432|6379|9092|2181|9090|3001)" | while read line; do
    port=$(echo $line | awk '{print $4}' | cut -d: -f2)
    case $port in
        3000) echo "Frontend:    $line" ;;
        8001) echo "Backend:     $line" ;;
        5432) echo "PostgreSQL:  $line" ;;
        6379) echo "Redis:       $line" ;;
        9092) echo "Kafka:       $line" ;;
        2181) echo "Zookeeper:   $line" ;;
        9090) echo "Prometheus:  $line" ;;
        3001) echo "Grafana:     $line" ;;
        *) echo "Unknown:     $line" ;;
    esac
done

echo ""
echo "🏥 Health Check Dashboard"
echo "------------------------"

# Function to health check with timeout
health_check() {
    local service=$1
    local url=$2
    local expected=$3
    
    printf "%-15s " "$service:"
    response=$(timeout 5 curl -s "$url" 2>/dev/null)
    if echo "$response" | grep -q "$expected"; then
        echo -e "${GREEN}Healthy${NC}"
    else
        echo -e "${RED}Unhealthy${NC}"
    fi
}

health_check "Backend" "http://localhost:8001/health" "healthy"
health_check "Frontend" "http://localhost:3000" "html"

# Database check
printf "%-15s " "Database:"
if docker exec shopsphere_postgres pg_isready -U user -d shopdb > /dev/null 2>&1; then
    echo -e "${GREEN}Healthy${NC}"
else
    echo -e "${RED}Unhealthy${NC}"
fi

# Redis check
printf "%-15s " "Redis:"
if docker exec shopsphere_redis redis-cli ping | grep -q PONG; then
    echo -e "${GREEN}Healthy${NC}"
else
    echo -e "${RED}Unhealthy${NC}"
fi

# Kafka check
printf "%-15s " "Kafka:"
if docker exec shopsphere_kafka kafka-broker-api-versions --bootstrap-server localhost:9092 > /dev/null 2>&1; then
    echo -e "${GREEN}Healthy${NC}"
else
    echo -e "${RED}Unhealthy${NC}"
fi

echo ""
echo "🔄 Kafka Topic Information"
echo "-------------------------"
if docker exec shopsphere_kafka kafka-broker-api-versions --bootstrap-server localhost:9092 > /dev/null 2>&1; then
    echo "Available topics:"
    docker exec shopsphere_kafka kafka-topics --bootstrap-server localhost:9092 --list | while read topic; do
        if [ ! -z "$topic" ]; then
            echo "  📨 $topic"
        fi
    done
    
    echo ""
    echo "Consumer groups:"
    docker exec shopsphere_kafka kafka-consumer-groups --bootstrap-server localhost:9092 --list 2>/dev/null | while read group; do
        if [ ! -z "$group" ]; then
            echo "  👥 $group"
        fi
    done
else
    echo -e "${RED}Kafka not available${NC}"
fi

echo ""
echo "📈 Performance Metrics"
echo "---------------------"

# API response time
echo -n "API response time: "
api_time=$(curl -w "%{time_total}" -o /dev/null -s http://localhost:8001/health 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "${api_time}s"
else
    echo -e "${RED}Failed${NC}"
fi

# Database connection time
echo -n "DB connection time: "
db_time=$(time (docker exec shopsphere_postgres psql -U user -d shopdb -c "SELECT 1;" > /dev/null 2>&1) 2>&1 | grep real | awk '{print $2}')
if [ ! -z "$db_time" ]; then
    echo "$db_time"
else
    echo -e "${RED}Failed${NC}"
fi

echo ""
echo "🎯 Quick Actions"
echo "---------------"
echo "View logs:           docker-compose logs -f [service]"
echo "Restart service:     docker-compose restart [service]"
echo "Scale service:       docker-compose up --scale backend=2"
echo "Monitor live:        docker stats"
echo "Kafka console:       docker exec -it shopsphere_kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic orders"

echo ""
echo "📊 System Recommendations"
echo "------------------------"

# Check for potential issues
total_mem=$(docker stats --no-stream --format "{{.MemUsage}}" | grep -o '[0-9.]*GiB' | head -1 | cut -d'G' -f1)
if [ ! -z "$total_mem" ] && (( $(echo "$total_mem > 4" | bc -l) )); then
    echo -e "${YELLOW}⚠️  High memory usage detected${NC}"
fi

# Check disk space
disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$disk_usage" -gt 80 ]; then
    echo -e "${YELLOW}⚠️  Disk space usage is high (${disk_usage}%)${NC}"
fi

echo ""
echo -e "${BLUE}📡 Monitoring complete!${NC}"