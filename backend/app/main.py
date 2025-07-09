from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.utils import get_openapi
from fastapi.responses import Response
from app.routers import auth, product, order, payment, cart, stripe_checkout
from dotenv import load_dotenv
from datetime import datetime
from prometheus_client import Counter, Histogram, generate_latest
import time
import atexit

# Import Kafka cleanup
from app.events import cleanup_kafka

load_dotenv()

app = FastAPI()

# Register cleanup function
atexit.register(cleanup_kafka)

# Prometheus metrics
REQUEST_COUNT = Counter(
    "http_requests_total", "Total HTTP requests", ["method", "endpoint"]
)
REQUEST_LATENCY = Histogram("http_request_duration_seconds", "HTTP request latency")

# CORS (for frontend dev)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Change in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Prometheus middleware
@app.middleware("http")
async def add_prometheus_metrics(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    REQUEST_COUNT.labels(method=request.method, endpoint=request.url.path).inc()
    REQUEST_LATENCY.observe(time.time() - start_time)
    return response


# Routers
app.include_router(stripe_checkout.router)
app.include_router(auth.router)
app.include_router(product.router)
app.include_router(order.router)
app.include_router(payment.router)
app.include_router(cart.router)


@app.get("/")
def root():
    return {"message": "ShopSphere API is live!"}


@app.get("/health")
async def health_check():
    # Check Kafka connectivity
    from app.events import event_producer

    kafka_status = "connected" if event_producer.producer else "disconnected"

    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "version": "1.0.0",
        "services": {
            "database": "connected",
            "redis": "connected",
            "kafka": kafka_status,
        },
    }


# Metrics endpoint for Prometheus
@app.get("/metrics")
async def get_metrics():
    return Response(generate_latest(), media_type="text/plain")


# Swagger Bearer Token Setup
def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema
    openapi_schema = get_openapi(
        title="ShopSphere API",
        version="1.0.0",
        description="E-commerce Backend with JWT auth",
        routes=app.routes,
    )
    openapi_schema["components"]["securitySchemes"] = {
        "BearerAuth": {
            "type": "http",
            "scheme": "bearer",
            "bearerFormat": "JWT",
        }
    }
    for path in openapi_schema["paths"].values():
        for method in path.values():
            method.setdefault("security", [{"BearerAuth": []}])
    app.openapi_schema = openapi_schema
    return app.openapi_schema


app.openapi = custom_openapi
