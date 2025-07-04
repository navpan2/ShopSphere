from pydantic import BaseModel
from typing import List, Optional
from pydantic import BaseModel, EmailStr
from typing import Optional, List
from pydantic import BaseModel
from typing import List, Optional


class UserCreate(BaseModel):
    email: EmailStr
    password: str
    is_admin: Optional[bool] = False
    admin_code: Optional[str] = None


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserOut(BaseModel):
    id: int
    email: EmailStr
    is_admin: bool

    class Config:
        orm_mode = True


class ProductCreate(BaseModel):
    name: str
    description: str
    price: float
    image_url: Optional[str] = None
    stock: int = 0  # ✅ NEW

class OrderItemCreate(BaseModel):
    product_id: int
    product_name: str
    quantity: int
    price: float


class OrderCreate(BaseModel):
    items: List[OrderItemCreate]
    total: float

class ProductOut(BaseModel):
    id: int
    name: str
    description: str
    price: float
    image_url: Optional[str]
    stock: int  # ✅ NEW

    class Config:
        orm_mode = True


class OrderItemOut(BaseModel):
    id: int
    product_id: int
    product_name: str
    quantity: int
    price: float

    class Config:
        orm_mode = True


class OrderOut(BaseModel):
    id: int
    user_id: int
    status: str
    total: float
    items: List[OrderItemOut]  # ✅ include items
    # optional: created_at: datetime

    class Config:
        orm_mode = True


class CartItemBase(BaseModel):
    product_id: int
    quantity: int

class CartItemCreate(CartItemBase):
    pass

class CartItemOut(BaseModel):
    id: int
    product_id: int
    quantity: int
    product: Optional[ProductOut]  # already defined earlier

    class Config:
        orm_mode = True
