from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app import models, schemas
from app.database import get_db
from app.routers.auth import get_current_user
from typing import List

router = APIRouter(prefix="/cart", tags=["Cart"])


@router.get("/", response_model=List[schemas.CartItemOut])
def get_cart(db: Session = Depends(get_db), user_id: int = Depends(get_current_user)):
    return db.query(models.CartItem).filter(models.CartItem.user_id == user_id).all()


@router.delete("/clear")
def clear_cart(user_id: int = Depends(get_current_user), db: Session = Depends(get_db)):
    db.query(models.CartItem).filter(models.CartItem.user_id == user_id).delete()
    db.commit()
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

    if db_item:
        db_item.quantity += item.quantity
    else:
        db_item = models.CartItem(
            user_id=user_id, product_id=item.product_id, quantity=item.quantity
        )
        db.add(db_item)

    db.commit()
    db.refresh(db_item)
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
    db.delete(item)
    db.commit()
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
    item.quantity = quantity
    db.commit()
    db.refresh(item)
    return item
