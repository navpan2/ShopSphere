#!/bin/bash
# ShopSphere Deployment Script
# =============================
# Resume-worthy: Automated deployment, Environment management, Health monitoring

set -e

# Configuration
ENVIRONMENT="${1:-staging}"
SERVICES="${2:-all}"
VERSION="${3:-latest}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
}

# Validate environment
validate_environment() {
    log "Validating deployment environment..."
    
    case $ENVIRONMENT in
        "development"|"staging"|"production")
            success "Environment '$ENVIRONMENT' is valid"
            ;;
        *)
            error "Invalid environment '$ENVIRONMENT'. Use: development, staging, or production"
            exit 1
            ;;
    esac
}

# Pre-deployment checks
pre_deployment_checks() {
    log "Running pre-deployment checks..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    # Check if required files exist
    required_files=(
        "docker-compose.yml"
        ".env"
        "backend/Dockerfile"
        "frontend/Dockerfile"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            error "Required file '$file' not found"
            exit 1
        fi
    done
    
    success "Pre-deployment checks passed"
}

# Setup environment variables
setup_environment() {
    log "Setting up environment variables for '$ENVIRONMENT'..."
    
    # Copy environment-specific configuration
    if [[ -f ".env.$ENVIRONMENT" ]]; then
        cp ".env.$ENVIRONMENT" ".env.deploy"
        success "Environment file '.env.$ENVIRONMENT' loaded"
    else
        warning "Environment file '.env.$ENVIRONMENT' not found, using default .env"
        cp ".env" ".env.deploy"
    fi
    
    # Set deployment-specific variables
    echo "" >> ".env.deploy"
    echo "# Deployment metadata" >> ".env.deploy"
    echo "DEPLOYMENT_ENV=$ENVIRONMENT" >> ".env.deploy"
    echo "DEPLOYMENT_VERSION=$VERSION" >> ".env.deploy"
    echo "DEPLOYMENT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> ".env.deploy"
    echo "DEPLOYMENT_USER=$(whoami)" >> ".env.deploy"
}

# Build and deploy services
deploy_services() {
    log "Deploying services: $SERVICES"
    
    # Create deployment directory
    mkdir -p "deployments/$ENVIRONMENT"
    
    # Generate docker-compose override for this environment
    cat > "deployments/$ENVIRONMENT/docker-compose.override.yml" << EOF
version: '3.8'

services:
  backend:
    image: ghcr.io/\${GITHUB_REPOSITORY:-yourusername/shopsphere}/backend:$VERSION
    environment:
      - NODE_ENV=$ENVIRONMENT
      - DEPLOYMENT_ENV=$ENVIRONMENT
    restart: unless-stopped
    
  frontend:
    image: ghcr.io/\${GITHUB_REPOSITORY:-yourusername/shopsphere}/frontend:$VERSION
    environment:
      - NODE_ENV=$ENVIRONMENT
      - NEXT_PUBLIC_ENVIRONMENT=$ENVIRONMENT
    restart: unless-stopped
    
  analytics:
    image: ghcr.io/\${GITHUB_REPOSITORY:-yourusername/shopsphere}/analytics:$VERSION
    environment:
      - NODE_ENV=$ENVIRONMENT
    restart: unless-stopped
    
  notifications:
    image: ghcr.io/\${GITHUB_REPOSITORY:-yourusername/shopsphere}/notifications:$VERSION
    environment:
      - NODE_ENV=$ENVIRONMENT
    restart: unless-stopped
EOF
    
    # Set resource limits based on environment
    if [[ "$ENVIRONMENT" == "production" ]]; then
        cat >> "deployments/$ENVIRONMENT/docker-compose.override.yml" << EOF
    
    # Production resource limits
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
EOF
    fi
    
    # Deploy services
    log "Starting deployment to $ENVIRONMENT environment..."
    
    # Export environment variables
    export $(cat .env.deploy | grep -v '^#' | xargs)
    
    # Stop existing services
    docker-compose \
        -f docker-compose.yml \
        -f "deployments/$ENVIRONMENT/docker-compose.override.yml" \
        down --remove-orphans
    
    # Pull latest images
    log "Pulling latest images..."
    docker-compose \
        -f docker-compose.yml \
        -f "deployments/$ENVIRONMENT/docker-compose.override.yml" \
        pull
    
    # Start services
    if [[ "$SERVICES" == "all" ]]; then
        log "Starting all services..."
        docker-compose \
            -f docker-compose.yml \
            -f "deployments/$ENVIRONMENT/docker-compose.override.yml" \
            up -d
    else
        log "Starting specific services: $SERVICES"
        docker-compose \
            -f docker-compose.yml \
            -f "deployments/$ENVIRONMENT/docker-compose.override.yml" \
            up -d $SERVICES
    fi
    
    success "Services started successfully"
}

# Health checks
perform_health_checks() {
    log "Performing health checks..."
    
    # Wait for services to start
    sleep 30
    
    # Define health check endpoints
    declare -A health_endpoints
    health_endpoints["backend"]="http://localhost:8001/health"
    health_endpoints["frontend"]="http://localhost:3000"
    health_endpoints["analytics"]="http://localhost:8002/health"
    health_endpoints["notifications"]="http://localhost:8003/health"
    
    failed_checks=()
    
    # Check each service
    for service in "${!health_endpoints[@]}"; do
        endpoint="${health_endpoints[$service]}"
        log "Checking $service at $endpoint..."
        
        # Retry health check up to 10 times
        for i in {1..10}; do
            if curl -f -s "$endpoint" > /dev/null 2>&1; then
                success "$service is healthy"
                break
            elif [[ $i -eq 10 ]]; then
                error "$service health check failed after 10 attempts"
                failed_checks+=("$service")
                break
            else
                log "Health check attempt $i/10 for $service failed, retrying..."
                sleep 10
            fi
        done
    done
    
    # Report results
    if [[ ${#failed_checks[@]} -eq 0 ]]; then
        success "All health checks passed!"
    else
        error "Health checks failed for: ${failed_checks[*]}"
        return 1
    fi
}

# Generate deployment report
generate_deployment_report() {
    log "Generating deployment report..."
    
    report_file="deployments/$ENVIRONMENT/deployment-report-$(date +%Y%m%d-%H%M%S).json"
    
    cat > "$report_file" << EOF
{
  "deployment": {
    "environment": "$ENVIRONMENT",
    "services": "$SERVICES",
    "version": "$VERSION",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "user": "$(whoami)",
    "status": "success"
  },
  "services": {
EOF
    
    # Get service information
    services_info=$(docker-compose ps --format json 2>/dev/null || echo '[]')
    echo "    \"running_services\": $services_info" >> "$report_file"
    
    cat >> "$report_file" << EOF
  },
  "environment_variables": {
    "NODE_ENV": "$ENVIRONMENT",
    "DEPLOYMENT_VERSION": "$VERSION"
  },
  "health_checks": {
    "backend": "$(curl -f -s http://localhost:8001/health > /dev/null 2>&1 && echo 'healthy' || echo 'unhealthy')",
    "frontend": "$(curl -f -s http://localhost:3000 > /dev/null 2>&1 && echo 'healthy' || echo 'unhealthy')",
    "analytics": "$(curl -f -s http://localhost:8002/health > /dev/null 2>&1 && echo 'healthy' || echo 'unhealthy')",
    "notifications": "$(curl -f -s http://localhost:8003/health > /dev/null 2>&1 && echo 'healthy' || echo 'unhealthy')"
  }
}
EOF
    
    success "Deployment report saved to: $report_file"
}

# Rollback function
rollback() {
    log "Initiating rollback..."
    
    # Find previous successful deployment
    previous_report=$(ls -t deployments/$ENVIRONMENT/deployment-report-*.json 2>/dev/null | sed -n '2p')
    
    if [[ -n "$previous_report" ]]; then
        previous_version=$(jq -r '.deployment.version' "$previous_report")
        warning "Rolling back to version: $previous_version"
        
        # Deploy previous version
        VERSION="$previous_version" deploy_services
        
        success "Rollback completed to version: $previous_version"
    else
        error "No previous deployment found for rollback"
        exit 1
    fi
}

# Cleanup function
cleanup() {
    log "Cleaning up temporary files..."
    rm -f .env.deploy
    success "Cleanup completed"
}

# Main deployment process
main() {
    log "🚀 Starting ShopSphere deployment"
    log "Environment: $ENVIRONMENT"
    log "Services: $SERVICES"
    log "Version: $VERSION"
    
    # Trap errors for cleanup
    trap 'error "Deployment failed"; cleanup; exit 1' ERR
    trap cleanup EXIT
    
    # Run deployment steps
    validate_environment
    pre_deployment_checks
    setup_environment
    deploy_services
    
    # Perform health checks with retry on failure
    if ! perform_health_checks; then
        if [[ "$ENVIRONMENT" == "production" ]]; then
            warning "Health checks failed in production, initiating rollback..."
            rollback
        else
            error "Health checks failed, deployment aborted"
            exit 1
        fi
    fi
    
    generate_deployment_report
    
    success "🎉 Deployment completed successfully!"
    
    # Display useful information
    echo ""
    echo "📊 Deployment Summary"
    echo "====================="
    echo "Environment: $ENVIRONMENT"
    echo "Services: $SERVICES"
    echo "Version: $VERSION"
    echo "Status: ✅ Success"
    echo ""
    echo "🌐 Service URLs:"
    echo "Frontend: http://localhost:3000"
    echo "Backend API: http://localhost:8001"
    echo "Analytics: http://localhost:8002"
    echo "Notifications: http://localhost:8003"
    echo ""
    echo "📋 Useful Commands:"
    echo "View logs: docker-compose logs -f [service]"
    echo "Check status: docker-compose ps"
    echo "Stop services: docker-compose down"
}

# Handle command line arguments
case "${1:-}" in
    "rollback")
        rollback
        ;;
    "health")
        perform_health_checks
        ;;
    "cleanup")
        cleanup
        ;;
    *)
        main "$@"
        ;;
esac