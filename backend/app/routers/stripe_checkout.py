# app/routers/stripe_checkout.py
from fastapi import APIRouter, Request
from pydantic import BaseModel
from starlette.responses import JSONResponse
import os
from dotenv import load_dotenv
import traceback
from app.events import event_producer  # Add this import
from datetime import datetime  # Add this import

# Import stripe properly
try:
    import stripe

    print("Stripe imported successfully")
except ImportError as e:
    print(f"Stripe import failed: {e}")
    stripe = None

load_dotenv()

router = APIRouter()

# Check if stripe is available
if stripe:
    stripe_key = os.getenv("STRIPE_SECRET_KEY")
    stripe.api_key = stripe_key
    print(
        f"Stripe API key set: {stripe_key[:10]}..."
        if stripe_key
        else "No Stripe key found"
    )
else:
    print("Stripe not available")

FRONTEND_URL = os.getenv("FRONTEND_URL", "http://localhost:3000")


class Item(BaseModel):
    id: int
    name: str
    price: float
    quantity: int


class CheckoutRequest(BaseModel):
    email: str
    items: list[Item]


@router.post("/create-checkout-session")
def create_checkout_session(data: CheckoutRequest):
    try:
        if not stripe:
            return JSONResponse(
                status_code=500, content={"error": "Stripe not available"}
            )

        print(f"Received data: {data}")
        print(f"Stripe available: {stripe is not None}")
        print(f"Stripe checkout available: {hasattr(stripe, 'checkout')}")

        line_items = [
            {
                "price_data": {
                    "currency": "inr",
                    "product_data": {
                        "name": item.name,
                    },
                    "unit_amount": int(item.price * 100),
                },
                "quantity": item.quantity,
            }
            for item in data.items
        ]

        session = stripe.checkout.Session.create(
            payment_method_types=["card"],
            line_items=line_items,
            mode="payment",
            customer_email=data.email,
            billing_address_collection="required",
            success_url=f"{FRONTEND_URL}/success",
            cancel_url=f"{FRONTEND_URL}/cart",
        )

        # Calculate total amount
        total_amount = sum(item.price * item.quantity for item in data.items)

        # 🔥 Send Kafka event for checkout session creation
        event_producer.send_order_event(
            {
                "event": "checkout_session_created",
                "session_id": session.id,
                "customer_email": data.email,
                "total_amount": total_amount,
                "currency": "inr",
                "items_count": len(data.items),
                "items": [
                    {
                        "id": item.id,
                        "name": item.name,
                        "price": item.price,
                        "quantity": item.quantity,
                    }
                    for item in data.items
                ],
                "timestamp": datetime.now().isoformat(),
            }
        )

        return {"url": session.url}

    except Exception as e:
        print(f"Error occurred: {str(e)}")
        traceback.print_exc()

        # 🔥 Send Kafka event for checkout failure
        event_producer.send_order_event(
            {
                "event": "checkout_session_failed",
                "customer_email": data.email,
                "error": str(e),
                "timestamp": datetime.now().isoformat(),
            }
        )

        return JSONResponse(status_code=500, content={"error": str(e)})
