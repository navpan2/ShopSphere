from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app import schemas, crud, database
from jose import JWTError, jwt
from fastapi.security import OAuth2PasswordBearer
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


# ✅ Create Order
@router.post("/", response_model=schemas.OrderOut)
def place_order(
    order: schemas.OrderCreate,
    user_id: int = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return crud.create_order(db, user_id, order)


# ✅ Get All Orders for Logged-in User
@router.get("/", response_model=List[schemas.OrderOut])
def get_my_orders(
    user_id: int = Depends(get_current_user), db: Session = Depends(get_db)
):
    return crud.get_user_orders(db, user_id)
