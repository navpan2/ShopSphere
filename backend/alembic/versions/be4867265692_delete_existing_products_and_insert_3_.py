"""delete existing products and insert 3 sample products

Revision ID: be4867265692
Revises: daeb97aacc78
Create Date: 2025-06-25 18:31:57.520396

"""
from typing import Sequence, Union
from sqlalchemy.sql import text
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'be4867265692'
down_revision: Union[str, Sequence[str], None] = 'daeb97aacc78'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    # 1. Delete existing records
    op.execute(text("DELETE FROM products"))

    # 2. Insert 3 sample products
    op.execute(
        text(
            """
        INSERT INTO products (name, description, price, image_url, stock)
        VALUES
        (
            'iPhone 15 Pro',
            'Apple A17 Pro Chip, 128GB',
            134999,
            'https://images.unsplash.com/photo-1606813908996-fdb26b7e39aa',
            10
        ),
        (
            'Sony WH-1000XM5',
            'Wireless Noise Cancelling Headphones',
            29999,
            'https://images.unsplash.com/photo-1621231481126-7cfc6831ba59',
            15
        ),
        (
            'Dell XPS 15',
            'Core i7, 16GB RAM, 512GB SSD',
            185000,
            'https://images.unsplash.com/photo-1587825140708-7c54ae8c1f4d',
            5
        );
    """
        )
    )


def downgrade() -> None:
    """Downgrade schema."""
    pass
