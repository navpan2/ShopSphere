# microservices/analytics-service/main.py - JSON PARSING FIX
import asyncio
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, Union
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import redis
from kafka import KafkaConsumer
import threading
import os
from contextlib import asynccontextmanager

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Configuration
REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379")
KAFKA_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092").split(",")
CONSUMER_GROUP = "analytics-service"

# Topics to consume
KAFKA_TOPICS = ["orders", "users", "products", "payments"]

# Global variables
redis_client: Optional[redis.Redis] = None
kafka_consumer: Optional[KafkaConsumer] = None
consumer_thread: Optional[threading.Thread] = None


def safe_json_deserializer(data):
    """Safe JSON deserializer that handles various formats"""
    try:
        if data is None:
            return None

        # If it's already a dict, return it
        if isinstance(data, dict):
            return data

        # Convert bytes to string
        if isinstance(data, bytes):
            data = data.decode("utf-8")

        # Handle empty or whitespace strings
        if not data or not data.strip():
            logger.warning("⚠️ Received empty message")
            return None

        # Try to parse as JSON
        try:
            return json.loads(data)
        except json.JSONDecodeError as e:
            logger.error(f"❌ JSON decode error: {e}")
            logger.error(f"❌ Raw data: {repr(data)}")

            # Try to fix common JSON issues
            data = data.strip()

            # Remove any leading/trailing non-JSON characters
            if data.startswith("'") and data.endswith("'"):
                data = data[1:-1]

            # Try parsing again
            try:
                return json.loads(data)
            except json.JSONDecodeError:
                logger.error(f"❌ Failed to parse after cleanup: {repr(data)}")
                return None

    except Exception as e:
        logger.error(f"❌ Unexpected error in JSON deserializer: {e}")
        return None


def safe_int(value: Any, default: int = 0) -> int:
    """Safely convert value to int"""
    try:
        if isinstance(value, bool):
            return int(value)
        if isinstance(value, str):
            if value.lower() in ("true", "false"):
                return int(value.lower() == "true")
            return int(float(value))
        return int(value)
    except (ValueError, TypeError):
        logger.warning(f"Could not convert {value} to int, using default {default}")
        return default


def safe_float(value: Any, default: float = 0.0) -> float:
    """Safely convert value to float"""
    try:
        if isinstance(value, bool):
            return float(value)
        if isinstance(value, str):
            if value.lower() in ("true", "false"):
                return float(value.lower() == "true")
            return float(value)
        return float(value)
    except (ValueError, TypeError):
        logger.warning(f"Could not convert {value} to float, using default {default}")
        return default


class AnalyticsService:
    def __init__(self):
        try:
            self.redis_client = redis.from_url(REDIS_URL, decode_responses=True)
            self.redis_client.ping()
            logger.info("✅ Redis connection established")
        except Exception as e:
            logger.error(f"❌ Redis connection failed: {e}")
            raise

        self.metrics_keys = {
            "orders_total": "analytics:orders:total",
            "orders_today": "analytics:orders:today",
            "revenue_total": "analytics:revenue:total",
            "revenue_today": "analytics:revenue:today",
            "users_total": "analytics:users:total",
            "products_popular": "analytics:products:popular",
            "cart_actions": "analytics:cart:actions",
            "events_processed": "analytics:events:processed",
            "events_failed": "analytics:events:failed",
        }

    def initialize_metrics(self):
        """Initialize metrics with default values"""
        try:
            for key in self.metrics_keys.values():
                if not self.redis_client.exists(key):
                    if any(
                        word in key
                        for word in ["popular", "actions", "processed", "failed"]
                    ):
                        self.redis_client.hset(key, "initialized", "true")
                    else:
                        self.redis_client.set(key, "0")
            logger.info("✅ Analytics metrics initialized")
        except Exception as e:
            logger.error(f"❌ Failed to initialize metrics: {e}")

    def log_event_received(self, topic: str, event_type: str, success: bool = True):
        """Log event processing"""
        try:
            key = (
                self.metrics_keys["events_processed"]
                if success
                else self.metrics_keys["events_failed"]
            )
            self.redis_client.hincrby(key, f"{topic}:{event_type}", 1)
        except Exception as e:
            logger.error(f"❌ Error logging event: {e}")

    def process_order_event(self, event: Dict[str, Any], topic: str):
        """Process order-related events"""
        try:
            event_type = event.get("event", "unknown")
            self.log_event_received(topic, event_type, True)

            logger.info(f"🔄 Processing order event: {event_type}")

            if event_type == "order_created":
                order_total = safe_float(event.get("total", 0))
                items_count = safe_int(event.get("items_count", 0))
                today = datetime.now().strftime("%Y-%m-%d")

                logger.info(f"📊 Order: ${order_total}, {items_count} items")

                # Update metrics
                self.redis_client.incr(self.metrics_keys["orders_total"])
                self.redis_client.incr(f"{self.metrics_keys['orders_today']}:{today}")
                self.redis_client.incrbyfloat(
                    self.metrics_keys["revenue_total"], order_total
                )
                self.redis_client.incrbyfloat(
                    f"{self.metrics_keys['revenue_today']}:{today}", order_total
                )

                # Process items
                items = event.get("items", [])
                if isinstance(items, list):
                    for item in items:
                        if isinstance(item, dict):
                            product_id = str(item.get("product_id", "unknown"))
                            quantity = safe_int(item.get("quantity", 1))
                            self.redis_client.hincrby(
                                self.metrics_keys["products_popular"],
                                product_id,
                                quantity,
                            )

                logger.info(f"✅ Order processed successfully: ${order_total:.2f}")
                return True

        except Exception as e:
            logger.error(f"❌ Error processing order event: {e}")
            self.log_event_received(topic, event.get("event", "unknown"), False)
            return False

    def process_user_event(self, event: Dict[str, Any], topic: str):
        """Process user-related events"""
        try:
            event_type = event.get("event", "unknown")
            self.log_event_received(topic, event_type, True)

            logger.info(f"🔄 Processing user event: {event_type}")

            if event_type == "user_registered":
                self.redis_client.incr(self.metrics_keys["users_total"])
                logger.info("✅ User registered")
                return True

            elif event_type in [
                "item_added_to_cart",
                "item_removed_from_cart",
                "cart_cleared",
            ]:
                self.redis_client.hincrby(
                    self.metrics_keys["cart_actions"], event_type, 1
                )
                logger.info(f"✅ Cart action: {event_type}")
                return True

        except Exception as e:
            logger.error(f"❌ Error processing user event: {e}")
            self.log_event_received(topic, event.get("event", "unknown"), False)
            return False

    def get_safe_redis_value(
        self, key: str, default_type: str = "int"
    ) -> Union[int, float]:
        """Safely get value from Redis"""
        try:
            value = self.redis_client.get(key)
            if value is None:
                return 0 if default_type == "int" else 0.0

            if default_type == "int":
                return safe_int(value)
            else:
                return safe_float(value)
        except Exception as e:
            logger.error(f"❌ Error getting Redis value for {key}: {e}")
            return 0 if default_type == "int" else 0.0

    def get_metrics_summary(self) -> Dict[str, Any]:
        """Get comprehensive analytics summary"""
        try:
            today = datetime.now().strftime("%Y-%m-%d")

            # Basic metrics
            orders_total = self.get_safe_redis_value(
                self.metrics_keys["orders_total"], "int"
            )
            orders_today = self.get_safe_redis_value(
                f"{self.metrics_keys['orders_today']}:{today}", "int"
            )
            revenue_total = self.get_safe_redis_value(
                self.metrics_keys["revenue_total"], "float"
            )
            revenue_today = self.get_safe_redis_value(
                f"{self.metrics_keys['revenue_today']}:{today}", "float"
            )
            users_total = self.get_safe_redis_value(
                self.metrics_keys["users_total"], "int"
            )

            # Events processed
            events_processed = (
                self.redis_client.hgetall(self.metrics_keys["events_processed"]) or {}
            )
            events_failed = (
                self.redis_client.hgetall(self.metrics_keys["events_failed"]) or {}
            )

            # Popular products
            try:
                popular_products = (
                    self.redis_client.hgetall(self.metrics_keys["products_popular"])
                    or {}
                )
                top_products = []
                for pid, qty in popular_products.items():
                    if pid != "initialized":
                        try:
                            quantity = safe_int(qty)
                            if quantity > 0:
                                top_products.append((pid, quantity))
                        except:
                            continue
                top_products = sorted(top_products, key=lambda x: x[1], reverse=True)[
                    :5
                ]
            except Exception as e:
                logger.error(f"❌ Error processing popular products: {e}")
                top_products = []

            return {
                "timestamp": datetime.now().isoformat(),
                "orders": {
                    "total": orders_total,
                    "today": orders_today,
                },
                "revenue": {
                    "total": round(revenue_total, 2),
                    "today": round(revenue_today, 2),
                    "average_order_value": (
                        round(revenue_total / orders_total, 2)
                        if orders_total > 0
                        else 0
                    ),
                },
                "users": {
                    "total": users_total,
                },
                "products": {
                    "top_selling": [
                        {"product_id": pid, "quantity_sold": qty}
                        for pid, qty in top_products
                    ]
                },
                "events": {
                    "processed": dict(events_processed),
                    "failed": dict(events_failed),
                },
                "debug_info": {
                    "kafka_topics": KAFKA_TOPICS,
                    "consumer_group": CONSUMER_GROUP,
                },
            }

        except Exception as e:
            logger.error(f"❌ Error getting metrics summary: {e}")
            return {"error": str(e), "timestamp": datetime.now().isoformat()}


# Global analytics service instance
analytics = AnalyticsService()


def kafka_consumer_worker():
    """Background worker to consume Kafka messages with robust error handling"""
    global kafka_consumer

    retry_count = 0
    max_retries = 5

    while retry_count < max_retries:
        try:
            logger.info(f"🔄 Starting Kafka consumer (attempt {retry_count + 1})")
            logger.info(f"📡 Servers: {KAFKA_SERVERS}")
            logger.info(f"📋 Topics: {KAFKA_TOPICS}")

            kafka_consumer = KafkaConsumer(
                *KAFKA_TOPICS,
                bootstrap_servers=KAFKA_SERVERS,
                group_id=CONSUMER_GROUP,
                value_deserializer=safe_json_deserializer,  # Use our safe deserializer
                auto_offset_reset="earliest",
                enable_auto_commit=True,
                auto_commit_interval_ms=1000,
                consumer_timeout_ms=10000,
                fetch_min_bytes=1,
                fetch_max_wait_ms=500,
            )

            logger.info("✅ Kafka consumer connected!")
            retry_count = 0  # Reset on successful connection

            for message in kafka_consumer:
                try:
                    topic = message.topic
                    event = message.value

                    # Skip invalid events
                    if event is None:
                        logger.warning(f"⚠️ Skipping null event from {topic}")
                        continue

                    if not isinstance(event, dict):
                        logger.warning(
                            f"⚠️ Skipping non-dict event from {topic}: {type(event)}"
                        )
                        continue

                    event_type = event.get("event", "unknown")
                    logger.info(f"📨 {topic} -> {event_type}")

                    # Route events
                    success = False
                    if any(word in topic.lower() for word in ["order"]) or any(
                        word in event_type.lower() for word in ["order", "checkout"]
                    ):
                        success = analytics.process_order_event(event, topic)
                    elif any(word in topic.lower() for word in ["user"]) or any(
                        word in event_type.lower()
                        for word in ["user", "cart", "login", "register"]
                    ):
                        success = analytics.process_user_event(event, topic)
                    else:
                        logger.warning(f"⚠️ Unknown event: {event_type}")
                        analytics.log_event_received(topic, event_type, False)

                    if success:
                        logger.info(f"✅ Event processed successfully")

                except Exception as e:
                    logger.error(f"❌ Error processing message: {e}")
                    try:
                        # Try to log the failed event
                        if hasattr(message, "topic") and hasattr(message, "value"):
                            analytics.log_event_received(
                                message.topic, "processing_error", False
                            )
                    except:
                        pass
                    continue

        except Exception as e:
            retry_count += 1
            logger.error(f"❌ Kafka consumer error (attempt {retry_count}): {e}")

            if retry_count < max_retries:
                wait_time = min(2**retry_count, 30)
                logger.info(f"⏳ Retrying in {wait_time} seconds...")
                import time

                time.sleep(wait_time)
            else:
                logger.error("❌ Max retries reached")
                break
        finally:
            if kafka_consumer:
                try:
                    kafka_consumer.close()
                except:
                    pass


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan management"""
    global consumer_thread

    logger.info("🚀 Starting Analytics Service...")

    try:
        analytics.initialize_metrics()
        consumer_thread = threading.Thread(target=kafka_consumer_worker, daemon=True)
        consumer_thread.start()
        logger.info("✅ Analytics Service started")
    except Exception as e:
        logger.error(f"❌ Startup failed: {e}")
        raise

    yield

    logger.info("🛑 Shutting down...")
    if kafka_consumer:
        kafka_consumer.close()


# FastAPI application
app = FastAPI(
    title="ShopSphere Analytics Service",
    description="Real-time analytics with robust JSON parsing",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root():
    return {
        "service": "ShopSphere Analytics",
        "version": "1.0.0",
        "status": "running",
        "timestamp": datetime.now().isoformat(),
    }


@app.get("/health")
def health_check():
    try:
        analytics.redis_client.ping()
        return {
            "status": "healthy",
            "timestamp": datetime.now().isoformat(),
            "services": {
                "redis": "connected",
                "kafka_consumer": (
                    "active"
                    if consumer_thread and consumer_thread.is_alive()
                    else "inactive"
                ),
            },
        }
    except Exception as e:
        raise HTTPException(status_code=503, detail=str(e))


@app.get("/metrics")
def get_all_metrics():
    return analytics.get_metrics_summary()


@app.get("/debug/events")
def get_events_debug():
    """Debug endpoint to see processed events"""
    try:
        processed = (
            analytics.redis_client.hgetall(analytics.metrics_keys["events_processed"])
            or {}
        )
        failed = (
            analytics.redis_client.hgetall(analytics.metrics_keys["events_failed"])
            or {}
        )

        return {
            "events_processed": dict(processed),
            "events_failed": dict(failed),
            "timestamp": datetime.now().isoformat(),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/metrics/reset")
def reset_metrics():
    try:
        for key in analytics.metrics_keys.values():
            analytics.redis_client.delete(key)
        analytics.initialize_metrics()
        return {"message": "Metrics reset", "timestamp": datetime.now().isoformat()}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8002, log_level="info")
