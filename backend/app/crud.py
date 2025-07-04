from sqlalchemy.orm import Session
from app import models, schemas
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ---------- AUTH ----------
def create_user(db: Session, user: schemas.UserCreate):
    hashed_pw = pwd_context.hash(user.password)
    db_user = models.User(
        email=user.email, password=hashed_pw, is_admin=user.is_admin  # 👈 assign value
    )
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
        stock=product.stock,  # ✅ include this
    )
    db.add(db_product)
    db.commit()
    db.refresh(db_product)
    return db_product


def get_all_products(db: Session):
    return db.query(models.Product).all()


# ---------- ORDERS ----------
def create_order(db: Session, user_id: int, order: schemas.OrderCreate):
    # Step 1: Create the order
    db_order = models.Order(user_id=user_id, total=order.total, status="paid")
    db.add(db_order)
    db.commit()
    db.refresh(db_order)

    # Step 2: Save items & reduce stock
    for item in order.items:
        db_item = models.OrderItem(
            order_id=db_order.id,
            product_id=item.product_id,
            product_name=item.product_name,
            quantity=item.quantity,
            price=item.price,
        )
        db.add(db_item)

        # Reduce stock
        product = (
            db.query(models.Product)
            .filter(models.Product.id == item.product_id)
            .first()
        )
        if product:
            product.stock = max(product.stock - item.quantity, 0)

    # Final commit
    db.commit()
    return db_order


def get_user_orders(db: Session, user_id: int):
    return db.query(models.Order).filter(models.Order.user_id == user_id).all()
