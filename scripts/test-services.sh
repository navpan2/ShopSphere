#!/bin/bash
# ShopSphere CI Testing Script
# =============================
# Resume-worthy: Multi-service testing, Test automation, Quality gates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_TYPE="${1:-unit}"
SERVICES=("backend" "frontend" "analytics" "notifications")
FAILED_SERVICES=()
PASSED_SERVICES=()

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Test summary
print_summary() {
    echo ""
    echo "======================================"
    echo "🧪 TEST SUMMARY"
    echo "======================================"
    echo "Test Type: $TEST_TYPE"
    echo "Total Services: ${#SERVICES[@]}"
    echo "Passed: ${#PASSED_SERVICES[@]}"
    echo "Failed: ${#FAILED_SERVICES[@]}"
    
    if [ ${#PASSED_SERVICES[@]} -gt 0 ]; then
        success "Passed Services: ${PASSED_SERVICES[*]}"
    fi
    
    if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
        error "Failed Services: ${FAILED_SERVICES[*]}"
        exit 1
    else
        success "🎉 All tests passed!"
    fi
}

# Backend testing function
test_backend() {
    log "🐍 Testing Backend Service..."
    
    cd backend
    
    # Install dependencies if not already installed
    if [ ! -d "venv" ]; then
        python -m venv venv
        source venv/bin/activate
        pip install -r requirements.txt
        pip install pytest pytest-cov pytest-mock
    else
        source venv/bin/activate
    fi
    
    case $TEST_TYPE in
        "unit")
            log "Running backend unit tests..."
            if pytest tests/ -v --cov=app --cov-report=xml --cov-report=html; then
                success "Backend unit tests passed"
                PASSED_SERVICES+=("backend")
            else
                error "Backend unit tests failed"
                FAILED_SERVICES+=("backend")
            fi
            ;;
        "integration")
            log "Running backend integration tests..."
            # Start test database
            docker run -d --name test-postgres \
                -e POSTGRES_USER=test \
                -e POSTGRES_PASSWORD=test \
                -e POSTGRES_DB=testdb \
                -p 5433:5432 \
                postgres:14-alpine
            
            # Wait for database
            sleep 10
            
            # Run integration tests
            if DATABASE_URL="postgresql://test:test@localhost:5433/testdb" \
               pytest tests/integration/ -v; then
                success "Backend integration tests passed"
                PASSED_SERVICES+=("backend")
            else
                error "Backend integration tests failed"
                FAILED_SERVICES+=("backend")
            fi
            
            # Cleanup
            docker stop test-postgres && docker rm test-postgres
            ;;
        "api")
            log "Running API tests..."
            if python -m pytest tests/api/ -v; then
                success "Backend API tests passed"
                PASSED_SERVICES+=("backend")
            else
                error "Backend API tests failed"
                FAILED_SERVICES+=("backend")
            fi
            ;;
    esac
    
    deactivate
    cd ..
}

# Frontend testing function
test_frontend() {
    log "🟢 Testing Frontend Service..."
    
    cd frontend
    
    # Install dependencies if not already installed
    if [ ! -d "node_modules" ]; then
        npm ci
    fi
    
    case $TEST_TYPE in
        "unit")
            log "Running frontend unit tests..."
            if npm test -- --coverage --watchAll=false; then
                success "Frontend unit tests passed"
                PASSED_SERVICES+=("frontend")
            else
                error "Frontend unit tests failed"
                FAILED_SERVICES+=("frontend")
            fi
            ;;
        "e2e")
            log "Running frontend E2E tests..."
            # Start the app in background
            npm run build
            npm start &
            FRONTEND_PID=$!
            
            # Wait for app to start
            sleep 30
            
            # Run E2E tests (using curl for simplicity)
            if curl -f http://localhost:3000 > /dev/null 2>&1; then
                success "Frontend E2E tests passed"
                PASSED_SERVICES+=("frontend")
            else
                error "Frontend E2E tests failed"
                FAILED_SERVICES+=("frontend")
            fi
            
            # Cleanup
            kill $FRONTEND_PID 2>/dev/null || true
            ;;
        "lint")
            log "Running frontend linting..."
            if npm run lint; then
                success "Frontend linting passed"
                PASSED_SERVICES+=("frontend")
            else
                error "Frontend linting failed"
                FAILED_SERVICES+=("frontend")
            fi
            ;;
    esac
    
    cd ..
}

# Analytics service testing function
test_analytics() {
    log "📊 Testing Analytics Service..."
    
    cd microservices/analytics-service
    
    # Setup Python environment
    if [ ! -d "venv" ]; then
        python -m venv venv
        source venv/bin/activate
        pip install -r requirements.txt
        pip install pytest pytest-cov
    else
        source venv/bin/activate
    fi
    
    case $TEST_TYPE in
        "unit")
            log "Running analytics unit tests..."
            if pytest tests/ -v --cov=main --cov-report=xml; then
                success "Analytics unit tests passed"
                PASSED_SERVICES+=("analytics")
            else
                error "Analytics unit tests failed"
                FAILED_SERVICES+=("analytics")
            fi
            ;;
        "integration")
            log "Running analytics integration tests..."
            # Start Redis for testing
            docker run -d --name test-redis -p 6380:6379 redis:7-alpine
            sleep 5
            
            if REDIS_URL="redis://localhost:6380" \
               pytest tests/integration/ -v; then
                success "Analytics integration tests passed"
                PASSED_SERVICES+=("analytics")
            else
                error "Analytics integration tests failed"
                FAILED_SERVICES+=("analytics")
            fi
            
            # Cleanup
            docker stop test-redis && docker rm test-redis
            ;;
    esac
    
    deactivate
    cd ../..
}

# Notifications service testing function
test_notifications() {
    log "📧 Testing Notification Service..."
    
    cd microservices/notification-service
    
    # Setup Python environment
    if [ ! -d "venv" ]; then
        python -m venv venv
        source venv/bin/activate
        pip install -r requirements.txt
        pip install pytest pytest-cov
    else
        source venv/bin/activate
    fi
    
    case $TEST_TYPE in
        "unit")
            log "Running notification unit tests..."
            if pytest tests/ -v --cov=main --cov-report=xml; then
                success "Notification unit tests passed"
                PASSED_SERVICES+=("notifications")
            else
                error "Notification unit tests failed"
                FAILED_SERVICES+=("notifications")
            fi
            ;;
        "integration")
            log "Running notification integration tests..."
            # Mock SMTP server for testing
            python -m smtpd -n -c DebuggingServer localhost:1025 &
            SMTP_PID=$!
            
            if SMTP_SERVER="localhost" SMTP_PORT="1025" \
               pytest tests/integration/ -v; then
                success "Notification integration tests passed"
                PASSED_SERVICES+=("notifications")
            else
                error "Notification integration tests failed"
                FAILED_SERVICES+=("notifications")
            fi
            
            # Cleanup
            kill $SMTP_PID 2>/dev/null || true
            ;;
    esac
    
    deactivate
    cd ../..
}

# Performance testing function
run_performance_tests() {
    log "🚀 Running Performance Tests..."
    
    if command -v k6 >/dev/null 2>&1; then
        # Create simple performance test
        cat > performance-test.js << 'EOF'
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '30s', target: 20 },
    { duration: '1m', target: 20 },
    { duration: '30s', target: 0 },
  ],
};

export default function() {
  let response = http.get('http://localhost:8001/health');
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  sleep(1);
}
EOF
        
        if k6 run performance-test.js; then
            success "Performance tests passed"
            rm performance-test.js
        else
            error "Performance tests failed"
            rm performance-test.js
            FAILED_SERVICES+=("performance")
        fi
    else
        warning "k6 not installed, skipping performance tests"
    fi
}

# Security testing function
run_security_tests() {
    log "🔒 Running Security Tests..."
    
    # Basic security checks
    log "Checking for common security issues..."
    
    # Check for hardcoded secrets
    if grep -r "password\|secret\|key" --include="*.py" --include="*.js" . | grep -v test | grep -v node_modules; then
        warning "Potential hardcoded secrets found (review manually)"
    else
        success "No obvious hardcoded secrets found"
    fi
    
    # Check for SQL injection patterns
    if grep -r "query.*+.*request\|execute.*+.*request" --include="*.py" .; then
        error "Potential SQL injection vulnerabilities found"
        FAILED_SERVICES+=("security")
    else
        success "No SQL injection patterns detected"
    fi
    
    success "Basic security checks completed"
}

# Main execution
main() {
    log "🧪 Starting ShopSphere Test Suite"
    log "Test Type: $TEST_TYPE"
    log "Services: ${SERVICES[*]}"
    
    case $TEST_TYPE in
        "unit"|"integration"|"api"|"e2e"|"lint")
            # Test each service
            for service in "${SERVICES[@]}"; do
                case $service in
                    "backend")
                        test_backend
                        ;;
                    "frontend")
                        test_frontend
                        ;;
                    "analytics")
                        test_analytics
                        ;;
                    "notifications")
                        test_notifications
                        ;;
                esac
            done
            ;;
        "performance")
            run_performance_tests
            ;;
        "security")
            run_security_tests
            ;;
        "all")
            # Run all types of tests
            log "Running comprehensive test suite..."
            
            # Unit tests
            TEST_TYPE="unit" $0
            
            # Integration tests
            TEST_TYPE="integration" $0
            
            # Security tests
            run_security_tests
            
            success "All test suites completed"
            ;;
        *)
            error "Unknown test type: $TEST_TYPE"
            echo "Available test types: unit, integration, api, e2e, lint, performance, security, all"
            exit 1
            ;;
    esac
    
    print_summary
}

# Trap errors
trap 'error "Test script failed at line $LINENO"' ERR

# Run main function
main "$@"