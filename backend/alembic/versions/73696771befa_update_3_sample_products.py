"""update 3 sample products

Revision ID: 73696771befa
Revises: be4867265692
Create Date: 2025-06-25 18:40:10.258680

"""
from typing import Sequence, Union
from sqlalchemy.sql import text
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '73696771befa'
down_revision: Union[str, Sequence[str], None] = 'be4867265692'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        text(
            """
    DELETE FROM products;
    INSERT INTO products (name, description, price, image_url, stock)
    VALUES
    (
        'iPhone 15 Pro',
        'Apple A17 Pro Chip, 128GB, Titanium Body',
        134999,
        'https://images.unsplash.com/photo-1591337676887-a217a6970a8a?q=80&w=880&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        10
    ),
    (
        'Sony WH-1000XM5',
        'Wireless Noise Cancelling Headphones, 30hr Battery',
        29999,
        'https://plus.unsplash.com/premium_photo-1678099940967-73fe30680949?q=80&w=880&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        15
    ),
    (
        'Dell XPS 15',
        'Intel Core i7, 16GB RAM, 512GB SSD, Windows 11',
        185000,
        'https://images.unsplash.com/photo-1593642632823-8f785ba67e45?q=80&w=1332&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        5
    );
"""
        )
    )

    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
