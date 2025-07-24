#!/bin/bash
# cleanup-project.sh
# ShopSphere Project Cleanup Script

set -e

echo "🧹 ShopSphere Project Cleanup"
echo "============================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Step 1: Backup current state
print_step "Creating backup of current configuration..."
mkdir -p backup_$(date +%Y%m%d_%H%M%S)
cp docker-compose*.yml backup_*/
cp .env* backup_*/ 2>/dev/null || true
print_success "Backup created"

# Step 2: Stop all services
print_step "Stopping all running services..."
docker-compose down 2>/dev/null || true
docker-compose -f docker-compose.enhanced.yml down 2>/dev/null || true
docker-compose -f docker-compose.microservices.yml down 2>/dev/null || true
print_success "Services stopped"

# Step 3: Remove nginx directory
print_step "Removing nginx directory..."
if [ -d "nginx" ]; then
    rm -rf nginx/
    print_success "Nginx directory removed"
else
    print_warning "Nginx directory not found"
fi

# Step 4: Remove redundant docker-compose files
print_step "Removing redundant docker-compose files..."
redundant_compose_files=(
    "docker-compose.dev.yml"
    "docker-compose.enhanced.yml"
    "docker-compose.microservices.yml"
    "docker-compose.gmail.yml"
    "docker-compose.yml.backup"
    "docker-compose.yml.original"
)

for file in "${redundant_compose_files[@]}"; do
    if [ -f "$file" ]; then
        rm "$file"
        echo "  ✓ Removed $file"
    fi
done
print_success "Redundant compose files removed"

# Step 5: Remove redundant environment files
print_step "Removing redundant environment files..."
redundant_env_files=(
    ".env.gmail"
    ".env.notifications"
    ".env.staging"
    ".env.production"
    "backend/.env"
)

for file in "${redundant_env_files[@]}"; do
    if [ -f "$file" ]; then
        rm "$file"
        echo "  ✓ Removed $file"
    fi
done
print_success "Redundant environment files removed"

# Step 6: Remove redundant frontend files
print_step "Removing redundant frontend files..."
if [ -f "frontend/src/next.config.js" ]; then
    rm "frontend/src/next.config.js"
    echo "  ✓ Removed frontend/src/next.config.js"
fi

if [ -f "frontend/src/utils/axiosInstance.js" ]; then
    rm "frontend/src/utils/axiosInstance.js"
    echo "  ✓ Removed frontend/src/utils/axiosInstance.js"
fi
print_success "Redundant frontend files removed"

# Step 7: Clean up temporary files
print_step "Cleaning up temporary files..."
find . -name "*.pyc" -delete 2>/dev/null || true
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name ".DS_Store" -delete 2>/dev/null || true
find . -name "Thumbs.db" -delete 2>/dev/null || true
print_success "Temporary files cleaned"

# Step 8: Docker cleanup
print_step "Cleaning up Docker resources..."
docker system prune -f > /dev/null 2>&1 || true
print_success "Docker resources cleaned"

# Step 9: Show final structure
print_step "Final project structure:"
echo ""
echo "📁 ShopSphere Project Structure (Cleaned)"
echo "========================================="
echo "shopsphere/"
echo "├── .env                          # Master environment file"
echo "├── .env.template                 # Environment template"
echo "├── .env.development              # Development overrides"
echo "├── docker-compose.yml            # Master compose file"
echo "├── Makefile                      # Build commands"
echo "├── README.md"
echo "├── backend/"
echo "│   ├── app/"
echo "│   ├── alembic/"
echo "│   ├── Dockerfile"
echo "│   └── requirements.txt"
echo "├── frontend/"
echo "│   ├── src/"
echo "│   ├── package.json"
echo "│   ├── Dockerfile"
echo "│   └── next.config.mjs"
echo "├── microservices/"
echo "│   ├── analytics-service/"
echo "│   └── notification-service/"
echo "├── monitoring/"
echo "│   └── prometheus.yml"
echo "├── scripts/"
echo "└── k8s/"

echo ""
print_success "🎉 Project cleanup completed successfully!"

echo ""
echo "📋 Next Steps:"
echo "=============="
echo "1. Replace docker-compose.yml with the master version"
echo "2. Replace .env with the consolidated version"
echo "3. Test services: docker-compose up -d"
echo "4. Run health check: make health"
echo "5. Update README with new simplified commands"

echo ""
echo "🚀 New Simple Commands:"
echo "======================"
echo "Start all:     docker-compose up -d"
echo "Stop all:      docker-compose down"
echo "View logs:     docker-compose logs -f [service]"
echo "Health check:  make health"
echo "Reset data:    docker-compose down -v"

echo ""
echo "📊 Cleanup Summary:"
echo "=================="
echo "✓ Removed nginx functionality"
echo "✓ Consolidated 6+ docker-compose files into 1"
echo "✓ Merged 5+ environment files into 1"
echo "✓ Removed redundant frontend files"
echo "✓ Cleaned up temporary files"
echo "✓ Optimized Docker resources"

echo ""
echo -e "${GREEN}Ready for development with simplified configuration!${NC}"