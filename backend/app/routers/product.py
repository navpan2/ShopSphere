from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app import schemas, crud, database, models
from app.auth_utils import get_current_user

router = APIRouter(prefix="/products", tags=["Products"])


def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.get("/", response_model=list[schemas.ProductOut])
def get_products(db: Session = Depends(get_db)):
    return crud.get_all_products(db)


@router.post("/", response_model=schemas.ProductOut)
def add_product(
    product: schemas.ProductCreate,
    db: Session = Depends(get_db),
    user_id: int = Depends(get_current_user),
):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user or not user.is_admin:
        raise HTTPException(status_code=403, detail="Only admin can add products")
    return crud.create_product(db, product)
