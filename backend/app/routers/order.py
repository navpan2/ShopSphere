# backend/app/routers/order.py - FIXED WITH USER EMAIL
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app import schemas, crud, database, models
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


# ✅ Create Order - FIXED WITH USER EMAIL
@router.post("/", response_model=schemas.OrderOut)
def place_order(
    order: schemas.OrderCreate,
    user_id: int = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Create the order
    new_order = crud.create_order(db, user_id, order)

    # ✅ Get user email for notification
    user = db.query(models.User).filter(models.User.id == user_id).first()
    user_email = user.email if user else None

    # 🔥 Send FIXED Kafka event with user email
    try:
        event_producer.send_order_event(
            {
                "event": "order_created",
                "order_id": str(new_order.id),
                "user_id": str(user_id),
                "user_email": user_email,  # ✅ FIXED: Include actual user email
                "total": float(new_order.total),
                "items_count": len(order.items),
                "status": new_order.status,
                "items": [
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
        print(f"✅ Order event sent with user email: {user_email}")
    except Exception as e:
        print(f"❌ Failed to send order event: {e}")

    return new_order


# ✅ Get All Orders for Logged-in User
@router.get("/", response_model=List[schemas.OrderOut])
def get_my_orders(
    user_id: int = Depends(get_current_user), db: Session = Depends(get_db)
):
    orders = crud.get_user_orders(db, user_id)

    # 🔥 Send Kafka event for orders view
    try:
        event_producer.send_user_event(
            {
                "event": "orders_viewed",
                "user_id": str(user_id),
                "orders_count": len(orders),
                "timestamp": datetime.now().isoformat(),
            }
        )
    except Exception as e:
        print(f"❌ Failed to send orders viewed event: {e}")

    return orders
