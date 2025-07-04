"""create orders and order_items tables

Revision ID: 5522d13c539c
Revises: 3f1f33d3ddc0
Create Date: 2025-07-04 14:46:46.356182

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '5522d13c539c'
down_revision: Union[str, Sequence[str], None] = '3f1f33d3ddc0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ✅ Add created_at to existing orders table
    op.add_column(
        "orders",
        sa.Column("created_at", sa.DateTime(), server_default=sa.text("now()")),
    )

    # ✅ Create new order_items table
    op.create_table(
        "order_items",
        sa.Column("id", sa.Integer, primary_key=True, index=True),
        sa.Column("order_id", sa.Integer, sa.ForeignKey("orders.id")),
        sa.Column("product_id", sa.Integer),
        sa.Column("product_name", sa.String),
        sa.Column("quantity", sa.Integer),
        sa.Column("price", sa.Float),
    )


def downgrade() -> None:
    """Downgrade schema."""
    pass
