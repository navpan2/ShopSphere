# microservices/analytics-service/config.py
import os
from typing import List


class Settings:
    # Application
    APP_NAME: str = "ShopSphere Analytics Service"
    VERSION: str = "1.0.0"
    DEBUG: bool = os.getenv("DEBUG", "false").lower() == "true"

    # Redis Configuration
    REDIS_URL: str = os.getenv("REDIS_URL", "redis://redis:6379")
    REDIS_DB: int = int(os.getenv("REDIS_DB", "1"))  # Use DB 1 for analytics
    REDIS_PASSWORD: str = os.getenv("REDIS_PASSWORD", "")

    # Kafka Configuration
    KAFKA_BOOTSTRAP_SERVERS: List[str] = os.getenv(
        "KAFKA_BOOTSTRAP_SERVERS", "kafka:9092"
    ).split(",")
    KAFKA_CONSUMER_GROUP: str = os.getenv("KAFKA_CONSUMER_GROUP", "analytics-service")
    KAFKA_AUTO_OFFSET_RESET: str = os.getenv("KAFKA_AUTO_OFFSET_RESET", "earliest")

    # Topics to consume
    KAFKA_TOPICS: List[str] = [
        "orders",
        "users",
        "products",
        "payments",
        "cart.events",
        "user.events",
        "order.events",
        "product.events",
        "payment.events",
    ]

    # Metrics Configuration
    METRICS_RETENTION_DAYS: int = int(os.getenv("METRICS_RETENTION_DAYS", "30"))
    REAL_TIME_WINDOW_MINUTES: int = int(os.getenv("REAL_TIME_WINDOW_MINUTES", "5"))

    # Service Configuration
    SERVICE_HOST: str = os.getenv("SERVICE_HOST", "0.0.0.0")
    SERVICE_PORT: int = int(os.getenv("SERVICE_PORT", "8002"))

    # Logging
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO")

    # Health Check
    HEALTH_CHECK_INTERVAL: int = int(os.getenv("HEALTH_CHECK_INTERVAL", "30"))

    # Performance
    MAX_WORKERS: int = int(os.getenv("MAX_WORKERS", "1"))
    CONSUMER_TIMEOUT_MS: int = int(os.getenv("CONSUMER_TIMEOUT_MS", "1000"))


# Global settings instance
settings = Settings()
