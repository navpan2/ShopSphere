from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from jose import JWTError, jwt
from datetime import datetime, timedelta
from app import schemas, crud, models, database
from app.events import event_producer  # Add this import
import os
from dotenv import load_dotenv
from fastapi.security import OAuth2PasswordBearer
from typing import List

load_dotenv()

router = APIRouter(prefix="/auth", tags=["Auth"])

# Secret key & algorithm
SECRET_KEY = "supersecretkey"  # In production, load from .env
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 30))


def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()


oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

SECRET_KEY = "supersecretkey"
ALGORITHM = "HS256"


def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: int = payload.get("user_id")
        if user_id is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        return user_id
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")


def create_access_token(data: dict, expires_delta: timedelta = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (
        expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


@router.post("/register", response_model=schemas.UserOut)
def register(user: schemas.UserCreate, db: Session = Depends(get_db)):
    # Check if email is already registered
    db_user = db.query(models.User).filter(models.User.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")

    # ✅ Admin code validation
    if user.is_admin:
        correct_code = os.getenv("ADMIN_SECRET")
        if not user.admin_code or user.admin_code != correct_code:
            raise HTTPException(status_code=403, detail="Invalid admin code")

    # Proceed to create the user
    new_user = crud.create_user(db, user)

    # 🔥 Send Kafka event for user registration
    event_producer.send_user_event(
        {
            "event": "user_registered",
            "user_id": str(new_user.id),
            "email": new_user.email,
            "is_admin": new_user.is_admin,
            "timestamp": datetime.now().isoformat(),
        }
    )

    return new_user


@router.post("/login")
def login(user: schemas.UserLogin, db: Session = Depends(get_db)):
    db_user = crud.authenticate_user(db, user.email, user.password)
    if not db_user:
        raise HTTPException(status_code=400, detail="Invalid credentials")

    access_token = create_access_token(
        data={"sub": db_user.email, "user_id": db_user.id}
    )

    # 🔥 Send Kafka event for user login
    event_producer.send_user_event(
        {
            "event": "user_logged_in",
            "user_id": str(db_user.id),
            "email": db_user.email,
            "timestamp": datetime.now().isoformat(),
        }
    )

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": {
            "id": db_user.id,
            "email": db_user.email,
            "is_admin": db_user.is_admin,
        },
    }
