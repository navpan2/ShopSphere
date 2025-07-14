from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy import and_
from app import models, schemas
from passlib.context import CryptContext
from fastapi import HTTPException
import logging

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
logger = logging.getLogger(__name__)


# ---------- AUTH ----------
def create_user(db: Session, user: schemas.UserCreate):
    hashed_pw = pwd_context.hash(user.password)
    db_user = models.User(email=user.email, password=hashed_pw, is_admin=user.is_admin)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


def authenticate_user(db: Session, email: str, password: str):
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user or not pwd_context.verify(password, user.password):
        return None
    return user


# ---------- PRODUCTS ----------
def create_product(db: Session, product: schemas.ProductCreate):
    db_product = models.Product(
        name=product.name,
        description=product.description,
        price=product.price,
        image_url=product.image_url,
        stock=product.stock,
    )
    db.add(db_product)
    db.commit()
    db.refresh(db_product)
    return db_product


def get_all_products(db: Session):
    return db.query(models.Product).all()


def get_product(db: Session, product_id: int):
    return db.query(models.Product).filter(models.Product.id == product_id).first()


# ✅ NEW: Update product with optimistic locking
def update_product_stock(db: Session, product_id: int, quantity_change: int):
    """
    Update product stock with optimistic locking to prevent race conditions
    """
    max_retries = 3
    retry_count = 0

    while retry_count < max_retries:
        try:
            # Get product with current version
            product = (
                db.query(models.Product).filter(models.Product.id == product_id).first()
            )

            if not product:
                raise HTTPException(status_code=404, detail="Product not found")

            # Check if stock is sufficient
            new_stock = product.stock + quantity_change
            if new_stock < 0:
                raise HTTPException(status_code=400, detail="Insufficient stock")

            # Update with version check
            result = (
                db.query(models.Product)
                .filter(
                    and_(
                        models.Product.id == product_id,
                        models.Product.version == product.version,
                    )
                )
                .update({"stock": new_stock, "version": product.version + 1})
            )

            if result == 0:
                # Version mismatch, retry
                db.rollback()
                retry_count += 1
                logger.warning(
                    f"Version mismatch for product {product_id}, retry {retry_count}"
                )
                continue

            db.commit()
            db.refresh(product)
            return product

        except SQLAlchemyError as e:
            db.rollback()
            retry_count += 1
            logger.error(f"Database error updating product {product_id}: {e}")

    raise HTTPException(
        status_code=409,
        detail="Could not update product due to concurrent modifications",
    )


# ---------- CART ----------
def add_to_cart_safe(db: Session, user_id: int, product_id: int, quantity: int):
    """
    Add to cart with stock validation
    """
    # Start transaction
    try:
        # Check product availability
        product = get_product(db, product_id)
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")

        if product.stock < quantity:
            raise HTTPException(status_code=400, detail="Insufficient stock")

        # Check existing cart item
        cart_item = (
            db.query(models.CartItem)
            .filter(
                models.CartItem.user_id == user_id,
                models.CartItem.product_id == product_id,
            )
            .first()
        )

        if cart_item:
            # Validate total quantity
            total_quantity = cart_item.quantity + quantity
            if total_quantity > product.stock:
                raise HTTPException(
                    status_code=400, detail="Cannot add more than available stock"
                )
            cart_item.quantity = total_quantity
        else:
            cart_item = models.CartItem(
                user_id=user_id, product_id=product_id, quantity=quantity
            )
            db.add(cart_item)

        db.commit()
        db.refresh(cart_item)
        return cart_item

    except SQLAlchemyError as e:
        db.rollback()
        logger.error(f"Error adding to cart: {e}")
        raise HTTPException(status_code=500, detail="Failed to add to cart")


# ---------- ORDERS ----------
def create_order(db: Session, user_id: int, order: schemas.OrderCreate):
    """
    Create order with atomic stock updates
    """
    try:
        # Create the order
        db_order = models.Order(user_id=user_id, total=order.total, status="paid")
        db.add(db_order)
        db.flush()  # Get order ID without committing

        # Process each item with stock validation
        for item in order.items:
            # Update stock atomically
            product = update_product_stock(db, item.product_id, -item.quantity)

            # Create order item
            db_item = models.OrderItem(
                order_id=db_order.id,
                product_id=item.product_id,
                product_name=item.product_name,
                quantity=item.quantity,
                price=item.price,
            )
            db.add(db_item)

        # Clear user's cart
        db.query(models.CartItem).filter(models.CartItem.user_id == user_id).delete()

        # Commit all changes
        db.commit()
        db.refresh(db_order)
        return db_order

    except Exception as e:
        db.rollback()
        logger.error(f"Error creating order: {e}")
        raise


def get_user_orders(db: Session, user_id: int):
    return db.query(models.Order).filter(models.Order.user_id == user_id).all()
