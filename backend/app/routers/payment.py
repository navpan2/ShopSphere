from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse
import stripe
import os
from dotenv import load_dotenv

load_dotenv()
router = APIRouter(prefix="/payment", tags=["Payment"])

# Stripe secret key from dashboard (Test Mode)
stripe.api_key = os.getenv("STRIPE_SECRET_KEY")  # replace with your test key


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
        return {"id": session.id}
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})
