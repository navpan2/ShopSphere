from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app import models, schemas, crud
from app.database import get_db
from app.routers.auth import get_current_user
from app.events import event_producer
from datetime import datetime
from typing import List

router = APIRouter(prefix="/cart", tags=["Cart"])


@router.get("/", response_model=List[schemas.CartItemOut])
def get_cart(db: Session = Depends(get_db), user_id: int = Depends(get_current_user)):
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
    cart_items = (
        db.query(models.CartItem).filter(models.CartItem.user_id == user_id).all()
    )
    items_count = len(cart_items)

    db.query(models.CartItem).filter(models.CartItem.user_id == user_id).delete()
    db.commit()

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
    """
    Add item to cart with stock validation
    """
    try:
        cart_item = crud.add_to_cart_safe(db, user_id, item.product_id, item.quantity)

        # Get product for event
        product = crud.get_product(db, item.product_id)

        event_producer.send_user_event(
            {
                "event": "item_added_to_cart",
                "user_id": str(user_id),
                "product_id": str(item.product_id),
                "product_name": product.name if product else "Unknown",
                "quantity": item.quantity,
                "timestamp": datetime.now().isoformat(),
            }
        )

        return cart_item

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


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

    product = db.query(models.Product).filter(models.Product.id == product_id).first()
    removed_quantity = item.quantity

    db.delete(item)
    db.commit()

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
    """
    Update cart item quantity with validation
    """
    if quantity <= 0:
        raise HTTPException(status_code=400, detail="Quantity must be positive")

    item = (
        db.query(models.CartItem)
        .filter_by(user_id=user_id, product_id=product_id)
        .first()
    )
    if not item:
        raise HTTPException(status_code=404, detail="Item not found in cart")

    # Validate stock
    product = crud.get_product(db, product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    if quantity > product.stock:
        raise HTTPException(
            status_code=400, detail=f"Only {product.stock} items available"
        )

    old_quantity = item.quantity
    item.quantity = quantity
    db.commit()
    db.refresh(item)

    event_producer.send_user_event(
        {
            "event": "cart_quantity_updated",
            "user_id": str(user_id),
            "product_id": str(product_id),
            "product_name": product.name,
            "old_quantity": old_quantity,
            "new_quantity": quantity,
            "timestamp": datetime.now().isoformat(),
        }
    )

    return item
