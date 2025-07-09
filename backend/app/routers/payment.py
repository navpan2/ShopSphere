from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse
import stripe
import os
from dotenv import load_dotenv
from app.events import event_producer  # Add this import
from datetime import datetime  # Add this import

load_dotenv()
router = APIRouter(prefix="/payment", tags=["Payment"])

# Stripe secret key from dashboard (Test Mode)
stripe.api_key = os.getenv("STRIPE_SECRET_KEY")


@router.post("/create-checkout-session")
def create_checkout_session():
    try:
        session = stripe.checkout.Session.create(
            payment_method_types=["card"],
            mode="payment",
            line_items=[
                {
                    "price_data": {
                        "currency": "usd",
                        "unit_amount": 2000,  # $20.00
                        "product_data": {"name": "ShopSphere Order"},
                    },
                    "quantity": 1,
                }
            ],
            success_url="http://localhost:3000/success",
            cancel_url="http://localhost:3000/cancel",
        )

        # 🔥 Send Kafka event for payment session creation
        event_producer.send_order_event(
            {
                "event": "payment_session_created",
                "session_id": session.id,
                "amount": 2000,
                "currency": "usd",
                "product": "ShopSphere Order",
                "timestamp": datetime.now().isoformat(),
            }
        )

        return {"id": session.id}
    except Exception as e:
        # 🔥 Send Kafka event for payment failure
        event_producer.send_order_event(
            {
                "event": "payment_session_failed",
                "error": str(e),
                "timestamp": datetime.now().isoformat(),
            }
        )

        return JSONResponse(status_code=500, content={"error": str(e)})
