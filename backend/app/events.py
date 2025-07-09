from kafka import KafkaProducer, KafkaConsumer
import json
import logging
import time

logger = logging.getLogger(__name__)


class EventProducer:
    def __init__(self):
        self.producer = None
        self.max_retries = 5
        self.retry_delay = 10
        self._initialize_producer()

    def _initialize_producer(self):
        """Initialize Kafka producer with retry logic"""
        for attempt in range(self.max_retries):
            try:
                self.producer = KafkaProducer(
                    bootstrap_servers=["kafka:9092"],
                    value_serializer=lambda v: json.dumps(v).encode("utf-8"),
                    request_timeout_ms=30000,
                    metadata_max_age_ms=30000,
                    api_version=(0, 10, 1),
                    retries=3,
                    retry_backoff_ms=1000,
                    max_in_flight_requests_per_connection=1,
                )
                logger.info("✅ Kafka producer initialized successfully!")
                return
            except Exception as e:
                logger.warning(
                    f"⚠️ Kafka connection attempt {attempt + 1}/{self.max_retries} failed: {e}"
                )
                if attempt < self.max_retries - 1:
                    time.sleep(self.retry_delay)
                else:
                    logger.error(
                        "❌ Failed to initialize Kafka producer after all retries"
                    )
                    self.producer = None

    def _send_event(self, topic, event_data):
        """Generic method to send events to any topic"""
        if not self.producer:
            logger.warning(f"⚠️ Kafka producer not available, skipping {topic} event")
            return False

        try:
            future = self.producer.send(topic, event_data)
            # Get the result with shorter timeout
            record_metadata = future.get(timeout=30)
            logger.info(f"✅ Event sent to {topic}: {event_data}")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to send {topic} event: {e}")
            return False

    def send_order_event(self, order_data):
        """Send order-related events"""
        return self._send_event("orders", order_data)

    def send_user_event(self, user_data):
        """Send user-related events"""
        return self._send_event("users", user_data)

    def send_product_event(self, product_data):
        """Send product-related events"""
        return self._send_event("products", product_data)

    def send_payment_event(self, payment_data):
        """Send payment-related events"""
        return self._send_event("payments", payment_data)

    def close(self):
        """Close the producer connection"""
        if self.producer:
            self.producer.close()
            logger.info("🔒 Kafka producer closed")


# Global event producer instance
event_producer = EventProducer()


# Cleanup function for graceful shutdown
def cleanup_kafka():
    event_producer.close()
