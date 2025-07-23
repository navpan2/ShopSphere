.PHONY: build up down logs clean restart health dev prod migrate migration backend-shell frontend-shell db-shell backup monitor test kafka-status kafka-topics

# Build all services
build:
	docker-compose build

# Start all services
up:
	docker-compose up -d

# Stop all services
down:
	docker-compose down

# View logs
logs:
	docker-compose logs -f

# Clean up everything
clean:
	docker-compose down -v
	docker system prune -f

# Restart services
restart:
	docker-compose restart

# Health check
health:
	@echo "🔍 Checking service health..."
	@curl -f http://localhost:8001/health || echo "❌ Backend: DOWN"
	@curl -f http://localhost:3000 || echo "❌ Frontend: DOWN"
	@curl -f http://localhost:9090/-/healthy || echo "❌ Prometheus: DOWN"
	@curl -f http://localhost:3001/api/health || echo "❌ Grafana: DOWN"

# Development mode
dev:
	docker-compose up --build

# Production mode
prod:
	docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Database migration
migrate:
	docker-compose exec backend alembic upgrade head

# Create new migration
migration:
	docker-compose exec backend alembic revision --autogenerate -m "$(msg)"

# Access backend shell
backend-shell:
	docker-compose exec backend bash

# Access frontend shell
frontend-shell:
	docker-compose exec frontend sh

# View database
db-shell:
	docker-compose exec postgres psql -U user -d shopdb

# Backup database
backup:
	docker-compose exec postgres pg_dump -U user shopdb > backup_$(shell date +%Y%m%d_%H%M%S).sql

# Monitor resources
monitor:
	docker stats

# Run tests
test:
	docker-compose exec backend pytest tests/ -v
	docker-compose exec frontend npm test

# Kafka specific commands
kafka-status:
	@echo "📊 Checking Kafka status..."
	@docker-compose exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092 || echo "❌ Kafka: DOWN"

kafka-topics:
	@echo "📋 Listing Kafka topics..."
	@docker-compose exec kafka kafka-topics --bootstrap-server localhost:9092 --list

kafka-create-topic:
	@echo "➕ Creating Kafka topic: $(topic)"
	@docker-compose exec kafka kafka-topics --bootstrap-server localhost:9092 --create --topic $(topic) --partitions 3 --replication-factor 1

kafka-consume:
	@echo "👂 Consuming messages from topic: $(topic)"
	@docker-compose exec kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic $(topic) --from-beginning

kafka-produce:
	@echo "📤 Producer for topic: $(topic) (Type messages, Ctrl+C to exit)"
	@docker-compose exec kafka kafka-console-producer --bootstrap-server localhost:9092 --topic $(topic)

# Complete setup with Kafka verification
setup:
	@echo "🚀 Setting up ShopSphere with full DevOps stack..."
	make down
	make build
	make up
	@echo "⏳ Waiting for services to start..."
	sleep 60
	make migrate
	make kafka-status
	make health
	make urls

# URLs for easy access
urls:
	@echo "🌐 ShopSphere Services:"
	@echo "Frontend: http://localhost:3000"
	@echo "Backend API: http://localhost:8001"
	@echo "Swagger Docs: http://localhost:8001/docs"
	@echo "Prometheus: http://localhost:9090"
	@echo "Grafana: http://localhost:3001 (admin/admin)"
	@echo "Kafka UI: http://localhost:8080"

# Load testing
load-test:
	@echo "🔥 Running load test..."
	@if command -v k6 >/dev/null 2>&1; then \
		k6 run --vus 10 --duration 30s --http-debug loadtest/simple-test.js; \
	else \
		echo "❌ k6 not installed. Install with: brew install k6"; \
	fi