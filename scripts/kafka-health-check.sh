#!/bin/bash
echo "Checking Kafka connectivity..."

# Check if Kafka is responding
docker exec shopsphere_kafka kafka-broker-api-versions \
  --bootstrap-server localhost:9092 > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Kafka is healthy"
    exit 0
else
    echo "❌ Kafka is unhealthy"
    exit 1
fi
