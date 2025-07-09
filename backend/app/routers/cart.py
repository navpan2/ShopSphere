from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app import models, schemas
from app.database import get_db
from app.routers.auth import get_current_user
from app.events import event_producer  # Add this import
from datetime import datetime  # Add this import
from typing import List

router = APIRouter(prefix="/cart", tags=["Cart"])


@router.get("/", response_model=List[schemas.CartItemOut])
def get_cart(db: Session = Depends(get_db), user_id: int = Depends(get_current_user)):
    # 🔥 Send Kafka event for cart view
    event_producer.send_user_event(
        {
            "event": "cart_viewed",
            "user_id": str(user_id),
            "timestamp": datetime.now().isoformat(),
        }
    )

    return db.query(models.CartItem).filter(models.CartItem.user_id == user_id).all()


@router.delete("/clear")
def clear_cart(user_id: int = Depends(get_current_user), db: Session = Depends(get_db)):
    # Get cart items count before clearing
    cart_items = (
        db.query(models.CartItem).filter(models.CartItem.user_id == user_id).all()
    )
    items_count = len(cart_items)

    db.query(models.CartItem).filter(models.CartItem.user_id == user_id).delete()
    db.commit()

    # 🔥 Send Kafka event for cart clearing
    event_producer.send_user_event(
        {
            "event": "cart_cleared",
            "user_id": str(user_id),
            "items_removed": items_count,
            "timestamp": datetime.now().isoformat(),
        }
    )

    return {"message": "Cart cleared"}


@router.post("/add", response_model=schemas.CartItemOut)
def add_to_cart(
    item: schemas.CartItemCreate,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user),
):
    db_item = (
        db.query(models.CartItem)
        .filter(
            models.CartItem.user_id == user_id,
            models.CartItem.product_id == item.product_id,
        )
        .first()
    )

    # Get product info for event
    product = (
        db.query(models.Product).filter(models.Product.id == item.product_id).first()
    )

    if db_item:
        old_quantity = db_item.quantity
        db_item.quantity += item.quantity
        event_type = "cart_item_updated"
    else:
        old_quantity = 0
        db_item = models.CartItem(
            user_id=user_id, product_id=item.product_id, quantity=item.quantity
        )
        db.add(db_item)
        event_type = "item_added_to_cart"

    db.commit()
    db.refresh(db_item)

    # 🔥 Send Kafka event for cart addition/update
    event_producer.send_user_event(
        {
            "event": event_type,
            "user_id": str(user_id),
            "product_id": str(item.product_id),
            "product_name": product.name if product else "Unknown",
            "quantity_added": item.quantity,
            "old_quantity": old_quantity,
            "new_quantity": db_item.quantity,
            "timestamp": datetime.now().isoformat(),
        }
    )

    return db_item


@router.delete("/remove/{product_id}")
def remove_from_cart(
    product_id: int,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user),
):
    item = (
        db.query(models.CartItem)
        .filter_by(user_id=user_id, product_id=product_id)
        .first()
    )
    if not item:
        raise HTTPException(status_code=404, detail="Item not found in cart")

    # Get product info for event
    product = db.query(models.Product).filter(models.Product.id == product_id).first()
    removed_quantity = item.quantity

    db.delete(item)
    db.commit()

    # 🔥 Send Kafka event for cart item removal
    event_producer.send_user_event(
        {
            "event": "item_removed_from_cart",
            "user_id": str(user_id),
            "product_id": str(product_id),
            "product_name": product.name if product else "Unknown",
            "quantity_removed": removed_quantity,
            "timestamp": datetime.now().isoformat(),
        }
    )

    return {"detail": "Item removed"}


@router.patch("/update/{product_id}", response_model=schemas.CartItemOut)
def update_quantity(
    product_id: int,
    quantity: int,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user),
):
    item = (
        db.query(models.CartItem)
        .filter_by(user_id=user_id, product_id=product_id)
        .first()
    )
    if not item:
        raise HTTPException(status_code=404, detail="Item not found in cart")

    # Get product info for event
    product = db.query(models.Product).filter(models.Product.id == product_id).first()
    old_quantity = item.quantity

    item.quantity = quantity
    db.commit()
    db.refresh(item)

    # 🔥 Send Kafka event for quantity update
    event_producer.send_user_event(
        {
            "event": "cart_quantity_updated",
            "user_id": str(user_id),
            "product_id": str(product_id),
            "product_name": product.name if product else "Unknown",
            "old_quantity": old_quantity,
            "new_quantity": quantity,
            "timestamp": datetime.now().isoformat(),
        }
    )

    return item
