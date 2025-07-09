from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app import schemas, crud, database, models
from app.auth_utils import get_current_user
from app.auth_utils import admin_only
from app.events import event_producer  # Add this import
from datetime import datetime  # Add this import

router = APIRouter(prefix="/products", tags=["Products"])


def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.get("/", response_model=list[schemas.ProductOut])
def get_products(db: Session = Depends(get_db)):
    products = crud.get_all_products(db)

    # 🔥 Send Kafka event for products view
    event_producer.send_product_event(
        {
            "event": "products_viewed",
            "products_count": len(products),
            "timestamp": datetime.now().isoformat(),
        }
    )

    return products


@router.post("/", response_model=schemas.ProductOut)
def add_product(
    product: schemas.ProductCreate,
    db: Session = Depends(get_db),
    user_id: int = Depends(admin_only),
):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user or not user.is_admin:
        raise HTTPException(status_code=403, detail="Only admin can add products")

    new_product = crud.create_product(db, product)

    # 🔥 Send Kafka event for product creation
    event_producer.send_product_event(
        {
            "event": "product_created",
            "product_id": str(new_product.id),
            "name": new_product.name,
            "price": float(new_product.price),
            "stock": new_product.stock,
            "created_by": str(user_id),
            "timestamp": datetime.now().isoformat(),
        }
    )

    return new_product


@router.put("/{product_id}", response_model=schemas.ProductOut)
def update_product(
    product_id: int,
    product: schemas.ProductCreate,
    db: Session = Depends(get_db),
    user_id: int = Depends(admin_only),
):
    db_product = (
        db.query(models.Product).filter(models.Product.id == product_id).first()
    )
    if not db_product:
        raise HTTPException(status_code=404, detail="Product not found")

    # Store old values for event
    old_name = db_product.name
    old_price = db_product.price
    old_stock = db_product.stock

    db_product.name = product.name
    db_product.description = product.description
    db_product.price = product.price
    db_product.image_url = product.image_url
    db_product.stock = product.stock

    db.commit()
    db.refresh(db_product)

    # 🔥 Send Kafka event for product update
    event_producer.send_product_event(
        {
            "event": "product_updated",
            "product_id": str(product_id),
            "name": product.name,
            "old_name": old_name,
            "price": float(product.price),
            "old_price": float(old_price),
            "stock": product.stock,
            "old_stock": old_stock,
            "updated_by": str(user_id),
            "timestamp": datetime.now().isoformat(),
        }
    )

    return db_product


@router.delete("/{product_id}")
def delete_product(
    product_id: int,
    db: Session = Depends(get_db),
    user_id: int = Depends(admin_only),
):
    db_product = (
        db.query(models.Product).filter(models.Product.id == product_id).first()
    )
    if not db_product:
        raise HTTPException(status_code=404, detail="Product not found")

    # Store product info for event
    product_name = db_product.name
    product_price = db_product.price

    db.delete(db_product)
    db.commit()

    # 🔥 Send Kafka event for product deletion
    event_producer.send_product_event(
        {
            "event": "product_deleted",
            "product_id": str(product_id),
            "name": product_name,
            "price": float(product_price),
            "deleted_by": str(user_id),
            "timestamp": datetime.now().isoformat(),
        }
    )

    return {"message": "Product deleted successfully"}
