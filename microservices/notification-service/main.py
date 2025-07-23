# microservices/notification-service/main.py - PRODUCTION READY VERSION
import asyncio
import json
import logging
import smtplib
import threading
from datetime import datetime
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Dict, Any, Optional
import uvicorn
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
import redis
from kafka import KafkaConsumer
import os
from contextlib import asynccontextmanager
from jinja2 import Template
import ssl

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Configuration
REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379")
KAFKA_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092").split(",")
CONSUMER_GROUP = "notification-service"

# Email Configuration
SMTP_SERVER = os.getenv("SMTP_SERVER", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USERNAME = os.getenv("SMTP_USERNAME", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
FROM_EMAIL = os.getenv("FROM_EMAIL", SMTP_USERNAME)
FROM_NAME = os.getenv("FROM_NAME", "E-Commerce Store")

# Admin Configuration
ADMIN_EMAIL = os.getenv("ADMIN_EMAIL", "npanchayan.gate@gmail.com")  # Fixed admin email

# Topics to consume
KAFKA_TOPICS = ["orders", "users", "products", "payments"]

# Global variables
redis_client: Optional[redis.Redis] = None
kafka_consumer: Optional[KafkaConsumer] = None
consumer_thread: Optional[threading.Thread] = None


def safe_json_deserializer(data):
    """Safe JSON deserializer"""
    try:
        if data is None:
            return None
        if isinstance(data, dict):
            return data
        if isinstance(data, bytes):
            data = data.decode("utf-8")
        if not data or not data.strip():
            return None
        return json.loads(data.strip())
    except Exception as e:
        logger.error(f"❌ JSON decode error: {e}")
        return None


class EmailService:
    def __init__(self):
        self.smtp_server = SMTP_SERVER
        self.smtp_port = SMTP_PORT
        self.username = SMTP_USERNAME
        self.password = SMTP_PASSWORD
        self.from_email = FROM_EMAIL
        self.from_name = FROM_NAME
        self.enabled = bool(self.username and self.password)

        if not self.enabled:
            logger.warning("⚠️ Email service disabled - missing SMTP credentials")
        else:
            logger.info(f"✅ Email service configured - {self.from_email}")

    def send_email(
        self, to_email: str, subject: str, html_body: str, text_body: str = None
    ) -> bool:
        """Send email using SMTP"""
        if not self.enabled:
            logger.warning(f"📧 Email disabled - would send to {to_email}: {subject}")
            return False

        try:
            # Create message
            msg = MIMEMultipart("alternative")
            msg["Subject"] = subject
            msg["From"] = f"{self.from_name} <{self.from_email}>"
            msg["To"] = to_email

            # Add text and HTML parts
            if text_body:
                text_part = MIMEText(text_body, "plain")
                msg.attach(text_part)

            html_part = MIMEText(html_body, "html")
            msg.attach(html_part)

            # Send email
            context = ssl.create_default_context()
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls(context=context)
                server.login(self.username, self.password)
                server.send_message(msg)

            logger.info(f"✅ Email sent to {to_email}: {subject}")
            return True

        except Exception as e:
            logger.error(f"❌ Failed to send email to {to_email}: {e}")
            return False


class NotificationTemplates:
    """Email templates for different notification types"""

    @staticmethod
    def order_confirmation(order_data: Dict[str, Any]) -> Dict[str, str]:
        """Order confirmation email template"""
        order_id = order_data.get("order_id", "N/A")
        total = order_data.get("total", 0)
        items = order_data.get("items", [])
        user_email = order_data.get("user_email", "customer")

        html_template = Template(
            """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                .header { background: #4f46e5; color: white; padding: 20px; text-align: center; }
                .content { padding: 20px; background: #f9f9f9; }
                .order-summary { background: white; padding: 15px; margin: 15px 0; border-radius: 5px; }
                .item { padding: 10px; border-bottom: 1px solid #eee; }
                .total { font-weight: bold; font-size: 18px; color: #4f46e5; }
                .footer { text-align: center; padding: 20px; font-size: 12px; color: #666; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🎉 Order Confirmed!</h1>
                    <p>Thank you for your order, {{ user_email }}!</p>
                </div>
                <div class="content">
                    <h2>Order #{{ order_id }}</h2>
                    <p>Your order has been successfully placed and is being processed.</p>
                    
                    <div class="order-summary">
                        <h3>Order Summary:</h3>
                        {% for item in items %}
                        <div class="item">
                            <strong>{{ item.product_name }}</strong><br>
                            Quantity: {{ item.quantity }} × ${{ "%.2f"|format(item.price) }} = ${{ "%.2f"|format(item.quantity * item.price) }}
                        </div>
                        {% endfor %}
                        <div class="total">
                            Total: ${{ "%.2f"|format(total) }}
                        </div>
                    </div>
                    
                    <p>We'll send you another email when your order ships!</p>
                </div>
                <div class="footer">
                    <p>Your Online Store - Thank you for shopping with us!</p>
                    <p>If you have any questions, reply to this email or contact our support team.</p>
                </div>
            </div>
        </body>
        </html>
        """
        )

        text_template = Template(
            """
        🎉 ORDER CONFIRMED!
        
        Thank you for your order, {{ user_email }}!
        
        Order #{{ order_id }}
        
        Order Summary:
        {% for item in items %}
        - {{ item.product_name }} ({{ item.quantity }}x) - ${{ "%.2f"|format(item.quantity * item.price) }}
        {% endfor %}
        
        Total: ${{ "%.2f"|format(total) }}
        
        We'll notify you when your order ships!
        
        Your Online Store Team
        """
        )

        return {
            "subject": f"Order Confirmation #{order_id} - Your Online Store",
            "html": html_template.render(**order_data),
            "text": text_template.render(**order_data),
        }

    @staticmethod
    def welcome_user(user_data: Dict[str, Any]) -> Dict[str, str]:
        """Welcome email template"""
        email = user_data.get("email", "")

        html_template = Template(
            """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                .header { background: #10b981; color: white; padding: 20px; text-align: center; }
                .content { padding: 20px; background: #f9f9f9; }
                .cta { background: #10b981; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 15px 0; }
                .footer { text-align: center; padding: 20px; font-size: 12px; color: #666; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🎊 Welcome to Our Store!</h1>
                    <p>Your account has been created successfully</p>
                </div>
                <div class="content">
                    <h2>Hello {{ email }}!</h2>
                    <p>Welcome to our online store - your new favorite shopping destination!</p>
                    
                    <p>Here's what you can do now:</p>
                    <ul>
                        <li>🛍️ Browse our amazing product collection</li>
                        <li>💰 Enjoy exclusive member discounts</li>
                        <li>📦 Track your orders in real-time</li>
                        <li>❤️ Save your favorite items</li>
                    </ul>
                    
                    <a href="http://localhost:3000/products" class="cta">Start Shopping Now!</a>
                    
                    <p>Happy shopping!</p>
                </div>
                <div class="footer">
                    <p>Your Online Store Team</p>
                </div>
            </div>
        </body>
        </html>
        """
        )

        text_template = Template(
            """
        🎊 WELCOME TO OUR STORE!
        
        Hello {{ email }}!
        
        Your account has been created successfully. Welcome to our online store!
        
        What you can do now:
        - Browse our amazing products
        - Enjoy exclusive member discounts  
        - Track your orders in real-time
        - Save your favorite items
        
        Start shopping: http://localhost:3000/products
        
        Happy shopping!
        Your Online Store Team
        """
        )

        return {
            "subject": "Welcome to Our Store! 🎊",
            "html": html_template.render(**user_data),
            "text": text_template.render(**user_data),
        }

    @staticmethod
    def low_stock_alert(product_data: Dict[str, Any]) -> Dict[str, str]:
        """Enhanced low stock alert template"""
        product_name = product_data.get("name", "Unknown Product")
        stock = product_data.get("stock", 0)
        product_id = product_data.get("product_id", "N/A")
        threshold = product_data.get("threshold", 5)
        event_type = product_data.get("event_type", "unknown")
        price = product_data.get("price", 0)
        
        # Determine trigger message
        trigger_msg = "automatically detected after an order" if event_type == "low_stock_detected" else "detected during manual update"
        
        html_template = Template("""
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                .header { background: #f59e0b; color: white; padding: 20px; text-align: center; }
                .content { padding: 20px; background: #fef3c7; }
                .alert { background: #dc2626; color: white; padding: 15px; text-align: center; border-radius: 5px; margin: 15px 0; }
                .details { background: white; padding: 15px; border-radius: 5px; margin: 10px 0; }
                .footer { text-align: center; padding: 20px; font-size: 12px; color: #666; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>⚠️ Low Stock Alert</h1>
                    <p>Automatic Inventory Monitoring</p>
                </div>
                <div class="content">
                    <div class="alert">
                        <h2>URGENT: Stock Running Low!</h2>
                        <p>{{ trigger_msg }}</p>
                    </div>
                    
                    <div class="details">
                        <h3>📦 Product Details:</h3>
                        <p><strong>Name:</strong> {{ product_name }}</p>
                        <p><strong>Product ID:</strong> {{ product_id }}</p>
                        <p><strong>Current Stock:</strong> {{ stock }} units</p>
                        <p><strong>Alert Threshold:</strong> {{ threshold }} units</p>
                        <p><strong>Price:</strong> ${{ "%.2f"|format(price) }}</p>
                        <p><strong>Status:</strong> {% if stock == 0 %}OUT OF STOCK{% else %}LOW STOCK{% endif %}</p>
                    </div>
                    
                    <p><strong>Action Required:</strong> Restock this product soon to avoid lost sales.</p>
                    
                    <p><strong>Recommendations:</strong></p>
                    <ul>
                        <li>Order new inventory immediately</li>
                        <li>Consider increasing stock threshold for popular items</li>
                        <li>Review sales velocity for better forecasting</li>
                    </ul>
                </div>
                <div class="footer">
                    <p>Store Inventory Management System</p>
                    <p>Alert triggered: {{ timestamp }}</p>
                </div>
            </div>
        </body>
        </html>
        """)
        
        return {
            "subject": f"⚠️ Low Stock Alert: {product_name} ({stock} units left)",
            "html": html_template.render(
                product_name=product_name, 
                product_id=product_id, 
                stock=stock,
                threshold=threshold,
                price=price,
                trigger_msg=trigger_msg,
                timestamp=product_data.get("timestamp", "")
            ),
            "text": f"LOW STOCK ALERT\n\nProduct: {product_name}\nID: {product_id}\nStock: {stock} units (threshold: {threshold})\nPrice: ${price:.2f}\n\nRestock immediately!\n\nTriggered: {trigger_msg}"
        }


class NotificationService:
    def __init__(self):
        try:
            self.redis_client = redis.from_url(REDIS_URL, decode_responses=True)
            self.redis_client.ping()
            logger.info("✅ Redis connection established")
        except Exception as e:
            logger.error(f"❌ Redis connection failed: {e}")
            raise

        self.email_service = EmailService()
        self.templates = NotificationTemplates()

        # Metrics
        self.metrics_keys = {
            "notifications_sent": "notifications:sent",
            "notifications_failed": "notifications:failed",
            "events_processed": "notifications:events:processed",
        }
        self.initialize_metrics()

    def initialize_metrics(self):
        """Initialize notification metrics"""
        try:
            for key in self.metrics_keys.values():
                if not self.redis_client.exists(key):
                    self.redis_client.hset(key, "initialized", "0")
            logger.info("✅ Notification metrics initialized")
        except Exception as e:
            logger.error(f"❌ Failed to initialize metrics: {e}")

    def log_notification(
        self, notification_type: str, success: bool, recipient: str = ""
    ):
        """Log notification attempt"""
        try:
            key = (
                self.metrics_keys["notifications_sent"]
                if success
                else self.metrics_keys["notifications_failed"]
            )
            self.redis_client.hincrby(key, notification_type, 1)

            # Store recent notifications
            notification_data = {
                "type": notification_type,
                "success": success,
                "recipient": recipient,
                "timestamp": datetime.now().isoformat(),
            }
            self.redis_client.lpush(
                "notifications:recent", json.dumps(notification_data)
            )
            self.redis_client.ltrim("notifications:recent", 0, 99)  # Keep last 100

        except Exception as e:
            logger.error(f"❌ Error logging notification: {e}")

    def get_user_email_from_backend(self, user_id: str) -> str:
        """Get user email from backend API or database"""
        try:
            # In a real implementation, you would:
            # 1. Query your database directly, or
            # 2. Make an API call to your backend to get user details

            # For now, we'll use a simple Redis cache approach
            # In production, replace this with actual database query
            user_email = self.redis_client.get(f"user:email:{user_id}")

            if user_email:
                return user_email

            # Fallback: Try to get from recent registration events
            recent_users = self.redis_client.lrange("users:recent_registrations", 0, 50)
            for user_data_str in recent_users:
                try:
                    user_data = json.loads(user_data_str)
                    if user_data.get("user_id") == user_id:
                        email = user_data.get("email")
                        if email:
                            # Cache for future use
                            self.redis_client.setex(
                                f"user:email:{user_id}", 3600, email
                            )
                            return email
                except:
                    continue

            # If we can't find the user email, return None
            logger.warning(f"⚠️ Could not find email for user_id: {user_id}")
            return None

        except Exception as e:
            logger.error(f"❌ Error getting user email for user_id {user_id}: {e}")
            return None

    def process_order_event(self, event: Dict[str, Any]):
        """Process order-related events"""
        try:
            event_type = event.get("event", "")

            if event_type == "order_created":
                # Get user ID and find their email
                user_id = event.get("user_id")
                user_email = None

                # Try to get email from the event first (if included)
                user_email = event.get("customer_email") or event.get("user_email")

                # If not in event, try to get from our user lookup
                if not user_email and user_id:
                    user_email = self.get_user_email_from_backend(str(user_id))

                if user_email:
                    # Add user email to order data for template
                    order_data = dict(event)
                    order_data["user_email"] = user_email

                    template_data = self.templates.order_confirmation(order_data)
                    success = self.email_service.send_email(
                        to_email=user_email,
                        subject=template_data["subject"],
                        html_body=template_data["html"],
                        text_body=template_data["text"],
                    )

                    self.log_notification("order_confirmation", success, user_email)

                    if success:
                        logger.info(
                            f"✅ Order confirmation sent to {user_email} for order {event.get('order_id')}"
                        )
                    else:
                        logger.error(
                            f"❌ Failed to send order confirmation to {user_email}"
                        )
                else:
                    logger.warning(
                        f"⚠️ No email found for user_id {user_id} - cannot send order confirmation"
                    )

        except Exception as e:
            logger.error(f"❌ Error processing order event: {e}")

    def process_user_event(self, event: Dict[str, Any]):
        """Process user-related events"""
        try:
            event_type = event.get("event", "")

            if event_type == "user_registered":
                email = event.get("email")
                user_id = event.get("user_id")

                if email:
                    # Cache user email for future order notifications
                    if user_id:
                        self.redis_client.setex(
                            f"user:email:{user_id}", 86400, email
                        )  # Cache for 24 hours

                    # Store in recent registrations for lookup
                    user_data = {
                        "user_id": user_id,
                        "email": email,
                        "timestamp": datetime.now().isoformat(),
                    }
                    self.redis_client.lpush(
                        "users:recent_registrations", json.dumps(user_data)
                    )
                    self.redis_client.ltrim(
                        "users:recent_registrations", 0, 100
                    )  # Keep last 100

                    # Send welcome email
                    template_data = self.templates.welcome_user(event)
                    success = self.email_service.send_email(
                        to_email=email,
                        subject=template_data["subject"],
                        html_body=template_data["html"],
                        text_body=template_data["text"],
                    )

                    self.log_notification("welcome_email", success, email)

                    if success:
                        logger.info(f"✅ Welcome email sent to {email}")

        except Exception as e:
            logger.error(f"❌ Error processing user event: {e}")


    def process_product_event(self, event: Dict[str, Any]):
        """Process product-related events with enhanced low stock detection"""
        try:
            event_type = event.get("event", "")

            # Handle both manual product updates and automatic low stock detection
            if event_type in ["product_updated", "low_stock_detected"]:
                stock = event.get("stock", 0)
                threshold = event.get("threshold", 5)

                # Send alert if stock is at or below threshold
                if stock <= threshold:
                    product_name = event.get("name", "Unknown Product")

                    # Enhanced alert data
                    alert_data = {
                        "product_id": event.get("product_id", "N/A"),
                        "name": product_name,
                        "stock": stock,
                        "threshold": threshold,
                        "event_type": event_type,
                        "description": event.get("description", ""),
                        "price": event.get("price", 0),
                        "timestamp": event.get("timestamp", datetime.now().isoformat()),
                    }

                    template_data = self.templates.low_stock_alert(alert_data)
                    success = self.email_service.send_email(
                        to_email=ADMIN_EMAIL,
                        subject=template_data["subject"],
                        html_body=template_data["html"],
                        text_body=template_data["text"],
                    )

                    alert_type = (
                        "auto_low_stock_alert"
                        if event_type == "low_stock_detected"
                        else "manual_low_stock_alert"
                    )
                    self.log_notification(alert_type, success, ADMIN_EMAIL)

                    if success:
                        trigger = (
                            "after order"
                            if event_type == "low_stock_detected"
                            else "manual update"
                        )
                        logger.info(
                            f"✅ Low stock alert sent to {ADMIN_EMAIL} for {product_name} ({trigger})"
                        )
                    else:
                        logger.error(
                            f"❌ Failed to send low stock alert for {product_name}"
                        )

            elif event_type == "products_viewed":
                products_count = event.get("products_count", 0)
                self.redis_client.hincrby(
                    "analytics:products:views", "total", products_count
                )
                logger.info(f"👀 Products viewed: {products_count}")

        except Exception as e:
            logger.error(f"❌ Error processing product event: {e}")

    def get_metrics_summary(self) -> Dict[str, Any]:
        """Get notification metrics"""
        try:
            sent = (
                self.redis_client.hgetall(self.metrics_keys["notifications_sent"]) or {}
            )
            failed = (
                self.redis_client.hgetall(self.metrics_keys["notifications_failed"])
                or {}
            )

            # Get recent notifications
            recent_raw = self.redis_client.lrange("notifications:recent", 0, 9)
            recent = []
            for item in recent_raw:
                try:
                    recent.append(json.loads(item))
                except:
                    continue

            return {
                "timestamp": datetime.now().isoformat(),
                "notifications_sent": dict(sent),
                "notifications_failed": dict(failed),
                "recent_notifications": recent,
                "email_service_enabled": self.email_service.enabled,
                "admin_email": ADMIN_EMAIL,
                "from_email": FROM_EMAIL,
            }

        except Exception as e:
            logger.error(f"❌ Error getting metrics: {e}")
            return {"error": str(e)}


# Global notification service instance
notification_service = NotificationService()


def kafka_consumer_worker():
    """Background worker to consume Kafka messages"""
    global kafka_consumer

    retry_count = 0
    max_retries = 5

    while retry_count < max_retries:
        try:
            logger.info(
                f"🔄 Starting notification consumer (attempt {retry_count + 1})"
            )

            kafka_consumer = KafkaConsumer(
                *KAFKA_TOPICS,
                bootstrap_servers=KAFKA_SERVERS,
                group_id=CONSUMER_GROUP,
                value_deserializer=safe_json_deserializer,
                auto_offset_reset="earliest",
                enable_auto_commit=True,
                auto_commit_interval_ms=1000,
            )

            logger.info("✅ Notification consumer started!")
            retry_count = 0

            for message in kafka_consumer:
                try:
                    topic = message.topic
                    event = message.value

                    if not event or not isinstance(event, dict):
                        continue

                    event_type = event.get("event", "unknown")
                    logger.info(
                        f"📧 Processing notification for: {topic} -> {event_type}"
                    )

                    # Route events
                    if any(word in topic.lower() for word in ["order"]) or any(
                        word in event_type.lower() for word in ["order", "checkout"]
                    ):
                        notification_service.process_order_event(event)
                    elif any(word in topic.lower() for word in ["user"]) or any(
                        word in event_type.lower() for word in ["user", "register"]
                    ):
                        notification_service.process_user_event(event)
                    elif any(word in topic.lower() for word in ["product"]) or any(
                        word in event_type.lower() for word in ["product"]
                    ):
                        notification_service.process_product_event(event)

                    # Log event processed
                    notification_service.redis_client.hincrby(
                        notification_service.metrics_keys["events_processed"],
                        f"{topic}:{event_type}",
                        1,
                    )

                except Exception as e:
                    logger.error(f"❌ Error processing message: {e}")
                    continue

        except Exception as e:
            retry_count += 1
            logger.error(f"❌ Consumer error (attempt {retry_count}): {e}")

            if retry_count < max_retries:
                import time

                wait_time = min(2**retry_count, 30)
                logger.info(f"⏳ Retrying in {wait_time} seconds...")
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

    logger.info("🚀 Starting Notification Service...")
    logger.info(f"📧 Admin email: {ADMIN_EMAIL}")
    logger.info(f"📤 From email: {FROM_EMAIL}")

    try:
        consumer_thread = threading.Thread(target=kafka_consumer_worker, daemon=True)
        consumer_thread.start()
        logger.info("✅ Notification Service started")
    except Exception as e:
        logger.error(f"❌ Startup failed: {e}")
        raise

    yield

    logger.info("🛑 Shutting down Notification Service...")


# FastAPI application
app = FastAPI(
    title="E-Commerce Notification Service",
    description="Email notifications for e-commerce events",
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
        "service": "E-Commerce Notifications",
        "version": "1.0.0",
        "status": "running",
        "timestamp": datetime.now().isoformat(),
        "email_enabled": notification_service.email_service.enabled,
        "admin_email": ADMIN_EMAIL,
        "from_email": FROM_EMAIL,
    }


@app.get("/health")
def health_check():
    try:
        notification_service.redis_client.ping()
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
                "email_service": (
                    "enabled"
                    if notification_service.email_service.enabled
                    else "disabled"
                ),
            },
            "config": {"admin_email": ADMIN_EMAIL, "from_email": FROM_EMAIL},
        }
    except Exception as e:
        raise HTTPException(status_code=503, detail=str(e))


@app.get("/metrics")
def get_metrics():
    """Get notification metrics"""
    return notification_service.get_metrics_summary()


@app.post("/send/test")
async def send_test_notification(
    background_tasks: BackgroundTasks, email: str = "navusa314@gmail.com"
):
    """Send test notification"""
    try:
        test_data = {
            "order_id": "TEST001",
            "total": 99.99,
            "user_email": email,
            "items": [{"product_name": "Test Product", "quantity": 1, "price": 99.99}],
        }

        template_data = notification_service.templates.order_confirmation(test_data)
        success = notification_service.email_service.send_email(
            to_email=email,
            subject=f"[TEST] {template_data['subject']}",
            html_body=template_data["html"],
            text_body=template_data["text"],
        )

        notification_service.log_notification("test_email", success, email)

        return {
            "success": success,
            "message": f"Test email {'sent' if success else 'failed'} to {email}",
            "timestamp": datetime.now().isoformat(),
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8003, log_level="info")
