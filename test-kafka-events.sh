#!/bin/bash

echo "Testing Kafka event publishing..."

# Test event structure
echo '{"event": "test_event", "user_id": "123", "timestamp": "2025-07-14T10:00:00Z"}' | \
docker exec -i shopsphere_kafka kafka-console-producer \
  --bootstrap-server localhost:9092 \
  --topic user.events

echo "Event sent to user.events topic"

# Consume the event to verify
echo "Consuming test event:"
docker exec shopsphere_kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic user.events \
  --from-beginning \
  --timeout-ms 5000
