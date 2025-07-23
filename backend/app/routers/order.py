# backend/app/routers/order.py - UPDATED VERSION
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app import schemas, crud, database
from jose import JWTError, jwt
from fastapi.security import OAuth2PasswordBearer
from app.events import event_producer
from datetime import datetime
from typing import List

router = APIRouter(prefix="/orders", tags=["Orders"])

# Token verification
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")
SECRET_KEY = "supersecretkey"
ALGORITHM = "HS256"


def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: int = payload.get("user_id")
        if user_id is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        return user_id
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")


# ✅ Create Order - FIXED VERSION
@router.post("/", response_model=schemas.OrderOut)
def place_order(
    order: schemas.OrderCreate,
    user_id: int = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Create the order
    new_order = crud.create_order(db, user_id, order)

    # 🔥 Send FIXED Kafka event for order creation
    event_producer.send_order_event(
        {
            "event": "order_created",
            "order_id": str(new_order.id),
            "user_id": str(user_id),
            "total": float(new_order.total),
            "items_count": len(order.items),  # ✅ FIXED: Use actual items count
            "status": new_order.status,  # ✅ FIXED: Use actual status
            "items": [  # ✅ NEW: Include actual items data
                {
                    "product_id": item.product_id,
                    "product_name": item.product_name,
                    "quantity": item.quantity,
                    "price": float(item.price),
                }
                for item in order.items
            ],
            "timestamp": datetime.now().isoformat(),
        }
    )

    return new_order


# ✅ Get All Orders for Logged-in User
@router.get("/", response_model=List[schemas.OrderOut])
def get_my_orders(
    user_id: int = Depends(get_current_user), db: Session = Depends(get_db)
):
    orders = crud.get_user_orders(db, user_id)

    # 🔥 Send Kafka event for orders view
    event_producer.send_user_event(
        {
            "event": "orders_viewed",
            "user_id": str(user_id),
            "orders_count": len(orders),
            "timestamp": datetime.now().isoformat(),
        }
    )

    return orders
