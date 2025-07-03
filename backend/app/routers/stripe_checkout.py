# app/routers/stripe_checkout.py

from fastapi import APIRouter, Request
from pydantic import BaseModel
from starlette.responses import JSONResponse
import stripe
import os
from dotenv import load_dotenv

load_dotenv()

router = APIRouter()
stripe.api_key = os.getenv("STRIPE_SECRET_KEY")

FRONTEND_URL = os.getenv("FRONTEND_URL", "http://localhost:3001")


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
        line_items = [
            {
                "price_data": {
                    "currency": "inr",
                    "product_data": {
                        "name": item.name,
                    },
                    "unit_amount": int(item.price * 100),  # Stripe uses paise
                },
                "quantity": item.quantity,
            }
            for item in data.items
        ]

        
        session = stripe.checkout.Session.create(
            payment_method_types=["card"],
            line_items=line_items,
            mode="payment",
            customer_email=data.email,  # ✅ from frontend
            billing_address_collection="required",
            success_url=f"{FRONTEND_URL}/success",
            cancel_url=f"{FRONTEND_URL}/cart",
        )

        return {"url": session.url}

    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})
