#!/bin/bash

KAFKA_CONTAINER="shopsphere_kafka"
BOOTSTRAP_SERVER="localhost:9092"

# Define topics with their configurations
declare -A TOPICS=(
    ["user.events"]="3:1"
    ["order.events"]="3:1" 
    ["product.events"]="3:1"
    ["cart.events"]="3:1"
    ["payment.events"]="3:1"
    ["inventory.events"]="3:1"
    ["notification.events"]="3:1"
    ["analytics.events"]="3:1"
)

echo "🚀 Setting up Kafka topics..."

for topic in "${!TOPICS[@]}"; do
    IFS=':' read -r partitions replication <<< "${TOPICS[$topic]}"
    
    echo "Creating topic: $topic (partitions: $partitions, replication: $replication)"
    
    docker exec $KAFKA_CONTAINER kafka-topics \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --create \
        --topic $topic \
        --partitions $partitions \
        --replication-factor $replication \
        --if-not-exists
done

echo "✅ Kafka topics setup complete!"

# List all topics
echo -e "\n📋 Current topics:"
docker exec $KAFKA_CONTAINER kafka-topics \
    --bootstrap-server $BOOTSTRAP_SERVER \
    --list
