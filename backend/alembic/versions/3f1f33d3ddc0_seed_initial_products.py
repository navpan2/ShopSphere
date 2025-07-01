"""Seed initial products

Revision ID: 3f1f33d3ddc0
Revises: 45e52c3379bc
Create Date: 2025-07-01 12:39:17.055986

"""
from typing import Sequence, Union
from sqlalchemy.sql import text
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '3f1f33d3ddc0'
down_revision: Union[str, Sequence[str], None] = '45e52c3379bc'
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


def downgrade() -> None:
    """Downgrade schema."""
    pass
